# ---------------------------------------------------------------------------------------------
# BDDReliabilityOracle — exact network-reachability reliability via a canonical ROBDD (CUDD.jl).
#
# Reusable, standalone exact oracle for the IPA validation/rewrite work and for paper baselines.
# Reliability model (matches IPA): a path works iff every NODE and every EDGE on it is up;
# belief(v) = P(v operational AND reachable from some source), returned for EVERY node.
#
# Requires the `bddenv` environment on the load path (CUDD.jl). Typical use:
#     const BDDENV = joinpath(@__DIR__, "bddenv"); push!(LOAD_PATH, BDDENV)
#     include("bdd_oracle.jl"); using .BDDReliabilityOracle
#     beliefs, stats = bdd_reliability(edgelist, node_priors, link_probs, sources)
#
# Correctness: validated against brute-force state enumeration and path-enumeration+IE to ~1e-16
# on many graphs (see validation/*). `sift=true` enables CUDD dynamic reordering (best-practice
# variable order); BDD node counts are the language-neutral complexity metric.
# ---------------------------------------------------------------------------------------------
module BDDReliabilityOracle

using CUDD
export bdd_reliability

# Kahn topological order over nodes 1..? given an edge list.
function _toposort(nodes::Vector{Int}, edgelist::Vector{Tuple{Int,Int}})
    indeg = Dict(v => 0 for v in nodes)
    outs  = Dict(v => Int[] for v in nodes)
    for (u,v) in edgelist; indeg[v] += 1; push!(outs[u], v); end
    q = sort([v for v in nodes if indeg[v] == 0]); order = Int[]
    while !isempty(q)
        u = popfirst!(q); push!(order, u)
        for w in outs[u]; indeg[w] -= 1; indeg[w] == 0 && push!(q, w); end
    end
    length(order) == length(nodes) || error("graph is not a DAG (cycle detected)")
    order
end

"""
    bdd_reliability(edgelist, node_priors, link_probs, sources; sift=false)
        -> (beliefs::Dict{Int,Float64}, stats::NamedTuple)

Exact reliability for every node via a CUDD ROBDD. `node_priors::Dict{Int,Float64}`,
`link_probs::Dict{Tuple{Int,Int},Float64}`, `sources` = iterable of source node ids.
`stats` = (bdd_total_nodes, n_vars, reorderings).
"""
function bdd_reliability(edgelist::Vector{Tuple{Int,Int}},
                         node_priors::Dict{Int,Float64},
                         link_probs::Dict{Tuple{Int,Int},Float64},
                         sources; sift::Bool=false)
    nodes = sort(collect(union(Set(keys(node_priors)),
                               Set(u for (u,_) in edgelist), Set(v for (_,v) in edgelist))))
    srcset = Set(sources)
    nid = Dict(n => i for (i,n) in enumerate(nodes))            # node var index (1-based)
    eid = Dict{Tuple{Int,Int},Int}()
    for (k,e) in enumerate(edgelist); eid[e] = length(nodes) + k; end
    nvar = length(nodes) + length(edgelist)

    # variable weights (probabilities) indexed by var id
    w = zeros(Float64, nvar)
    for n in nodes; w[nid[n]] = node_priors[n]; end
    for e in edgelist; w[eid[e]] = link_probs[e]; end

    incoming = Dict{Int,Vector{Int}}()
    for (u,v) in edgelist; push!(get!(incoming, v, Int[]), u); end

    mgr = Cudd_Init(0, 0, 256, 262144, 0)
    sift && Cudd_AutodynEnable(mgr, CUDD.CUDD_REORDER_SIFT)
    ith(id)  = Cudd_bddIthVar(mgr, id - 1)
    And(f,g) = (r = Cudd_bddAnd(mgr, f, g); Cudd_Ref(r); r)
    Or(f,g)  = (r = Cudd_bddOr(mgr,  f, g); Cudd_Ref(r); r)
    Zero     = Cudd_ReadLogicZero(mgr)

    # reach(v) = node_v ∧ (source ? ⊤ : ⋁_{(u,v)} reach(u) ∧ edge_(u,v))
    reach = Dict{Int,Ptr{Nothing}}()
    for v in _toposort(nodes, edgelist)
        base = ith(nid[v])
        if v in srcset
            r = base
        else
            acc = Zero
            for u in get(incoming, v, Int[]); acc = Or(acc, And(reach[u], ith(eid[(u,v)]))); end
            r = And(base, acc)
        end
        Cudd_Ref(r); reach[v] = r
    end
    sift && Cudd_ReduceHeap(mgr, CUDD.CUDD_REORDER_SIFT, 0)

    # complement-aware weighted probability sweep, memoized on regular-node pointer
    one_reg = Ptr{Nothing}(Cudd_Regular(Cudd_ReadOne(mgr)))
    memo = Dict{Ptr{Nothing},Float64}()
    function prob(f)
        reg = Ptr{Nothing}(Cudd_Regular(f)); b = get(memo, reg, -1.0)
        if b < 0.0
            b = reg == one_reg ? 1.0 :
                (p = w[Int(Cudd_NodeReadIndex(reg)) + 1]; p*prob(Cudd_T(reg)) + (1-p)*prob(Cudd_E(reg)))
            memo[reg] = b
        end
        (Cudd_IsComplement(f) != 0) ? 1.0 - b : b
    end

    beliefs = Dict(v => prob(reach[v]) for v in nodes)
    stats = (bdd_total_nodes = Int(Cudd_ReadNodeCount(mgr)),
             n_vars = nvar,
             reorderings = sift ? Int(Cudd_ReadReorderings(mgr)) : 0)
    Cudd_Quit(mgr)
    (beliefs, stats)
end

end # module
