# Reusable oracle functions (pure; no execution). Requires in caller scope:
#   using .InfoPropFramework ; using CUDD ; import BinaryDecisionDiagrams as BDDjl
#   include("graph_gen.jl")
# Reliability model: a path works iff every NODE and EDGE on it is up; belief(v) for ALL nodes.

function make_problem(g::Graph)
    edgelist, outgoing, incoming, sources = to_framework(g)
    all_nodes = sort(collect(union(Set(keys(outgoing)), Set(keys(incoming)),
                                   Set(v for vs in values(outgoing) for v in vs))))
    nid = Dict(n => i for (i,n) in enumerate(all_nodes))
    eid = Dict{Tuple{Int,Int},Int}(); for (k,e) in enumerate(g.edges); eid[e] = length(all_nodes)+k; end
    V = length(all_nodes) + length(g.edges)
    itersets, anc, desc = find_iteration_sets(edgelist, outgoing, incoming)
    topo = Int[]; for s in itersets, n in sort(collect(s)); push!(topo, n); end
    (; edgelist, outgoing, incoming, sources, all_nodes, nid, eid, V, itersets, anc, desc, topo)
end
function draw_probs(P, rng)
    node_priors = Dict(n => 0.30 + 0.69*rand(rng) for n in P.all_nodes)
    link_probs  = Dict(e => 0.30 + 0.69*rand(rng) for e in keys(P.eid))
    w = zeros(Float64, P.V)
    for n in P.all_nodes; w[P.nid[n]] = node_priors[n]; end
    for (e,i) in P.eid;   w[i] = link_probs[e]; end
    (; node_priors, link_probs, w)
end

# --- IPA (structure reuses P.itersets/anc/desc; identify+build is the reusable structure phase) ---
function ipa_structure(P, D)
    fork, join = identify_fork_and_join_nodes(P.outgoing, P.incoming)
    roots = identify_and_group_diamonds(join, P.incoming, P.anc, P.desc, P.sources, fork,
                                        P.edgelist, D.node_priors, P.itersets)
    uniq = build_unique_diamond_storage_depth_first_parallel(roots, D.node_priors, P.anc, P.desc, P.itersets)
    (; fork, join, roots, uniq)
end
ipa_propagate(P, S, D) = update_beliefs_iterative(
    P.edgelist, P.itersets, P.outgoing, P.incoming, P.sources, D.node_priors, D.link_probs,
    P.desc, P.anc, S.roots, S.join, S.fork, S.uniq)
function ipa_stats(S)
    ndia  = length(S.roots)
    nuniq = length(S.uniq)
    sum2C = sum(2^length(cd.diamond.conditioning_nodes) for (_,cd) in S.uniq; init=0)
    maxC  = isempty(S.uniq) ? 0 : maximum(length(cd.diamond.conditioning_nodes) for (_,cd) in S.uniq)
    (; ndia, nuniq, sum2C, maxC)
end

# --- CUDD ---
function cudd_build(P)
    mgr = Cudd_Init(0, 0, 256, 262144, 0)
    ith(id) = Cudd_bddIthVar(mgr, id-1)
    And(f,g) = (r = Cudd_bddAnd(mgr,f,g); Cudd_Ref(r); r)
    Or(f,g)  = (r = Cudd_bddOr(mgr,f,g);  Cudd_Ref(r); r)
    Zero = Cudd_ReadLogicZero(mgr)
    reach = Dict{Int,Ptr{Nothing}}()
    for n in P.topo
        base = ith(P.nid[n])
        if n in P.sources
            r = base
        else
            acc = Zero
            for u in get(P.incoming, n, Set{Int}())
                acc = Or(acc, And(reach[u], ith(P.eid[(u,n)])))
            end
            r = And(base, acc)
        end
        Cudd_Ref(r); reach[n] = r
    end
    sink_nodes = [n for n in P.all_nodes if !haskey(P.outgoing,n) || isempty(P.outgoing[n])]
    total_nodes = Int(Cudd_ReadNodeCount(mgr))
    max_sink_sz = isempty(sink_nodes) ? 0 : maximum(Int(Cudd_DagSize(reach[n])) for n in sink_nodes)
    (; mgr, reach, total_nodes, max_sink_sz)
end
function cudd_eval(B, P, w)
    one_reg = Ptr{Nothing}(Cudd_Regular(Cudd_ReadOne(B.mgr)))
    memo = Dict{Ptr{Nothing},Float64}()
    function prob(f)
        reg = Ptr{Nothing}(Cudd_Regular(f)); b = get(memo, reg, -1.0)
        if b < 0.0
            b = reg == one_reg ? 1.0 :
                (p = w[Int(Cudd_NodeReadIndex(reg))+1]; p*prob(Cudd_T(reg)) + (1-p)*prob(Cudd_E(reg)))
            memo[reg] = b
        end
        (Cudd_IsComplement(f) != 0) ? 1.0-b : b
    end
    Dict(n => prob(B.reach[n]) for n in P.all_nodes)
end
cudd_free(B) = Cudd_Quit(B.mgr)

# --- BinaryDecisionDiagrams.jl ---
function bddjl_build(P)
    F = BDDjl.terminal(false)
    reach = Dict{Int,Any}()
    for n in P.topo
        base = BDDjl.variable(P.nid[n])
        if n in P.sources
            r = base
        else
            acc = F
            for u in get(P.incoming, n, Set{Int}())
                acc = BDDjl.:∨(acc, BDDjl.:∧(reach[u], BDDjl.variable(P.eid[(u,n)])))
            end
            r = BDDjl.:∧(base, acc)
        end
        reach[n] = r
    end
    (; reach)
end
function bddjl_eval(B, P, w)
    memo = Dict{UInt64,Float64}()
    function prob(d)
        BDDjl.is_⊤(d) && return 1.0
        BDDjl.is_⊥(d) && return 0.0
        get!(memo, objectid(d)) do
            p = w[d.index]; p*prob(d.high) + (1-p)*prob(d.low)
        end
    end
    Dict(n => prob(B.reach[n]) for n in P.all_nodes)
end

# --- brute force (small graphs) ---
function brute(P, D)
    nid = P.nid; eid = P.eid
    up_node(s,n) = (s >> (nid[n]-1)) & 1 == 1
    up_edge(s,e) = (s >> (eid[e]-1)) & 1 == 1
    bel = Dict(n => 0.0 for n in P.all_nodes)
    for s in 0:(2^P.V - 1)
        wgt = 1.0
        for n in P.all_nodes; wgt *= up_node(s,n) ? D.node_priors[n] : (1-D.node_priors[n]); end
        for e in keys(eid);   wgt *= up_edge(s,e) ? D.link_probs[e]  : (1-D.link_probs[e]);  end
        wgt == 0.0 && continue
        reachable = Set{Int}(n for n in P.sources if up_node(s,n))
        changed = true
        while changed
            changed = false
            for (u,v) in P.edgelist
                if u in reachable && v ∉ reachable && up_node(s,v) && up_edge(s,(u,v))
                    push!(reachable, v); changed = true
                end
            end
        end
        for n in reachable; bel[n] += wgt; end
    end
    bel
end

function load_edges(name, path)
    edgelist, _, _, srcs = read_graph_to_dict(path)
    n = maximum(maximum(e) for e in edgelist)
    Graph(n, edgelist, collect(srcs), name)
end
