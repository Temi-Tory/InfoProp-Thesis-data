# Trace-check of the worked examples for the Probability Propagation chapter (per the writing
# protocol: every worked-example number is machine-verified against the implementation before it
# enters the text). Two examples:
#   Example S (simple diamond, 5 nodes): source 1, fork 2, parents 3/4, join 5.
#       Convention: source prior 1.0, non-source priors 0.9, edges 0.9 (hand-checkable arithmetic).
#   Example A (running example, 8 nodes = the Diamond chapter's nested network): outer fork 1,
#       inner fork 3, inner join 6, outer join 8. Convention: ALL node priors 0.9 (incl. source 1,
#       so fork 1 stays conditionable, matching the Diamond chapter's decomposition), edges 0.9.
# For each: framework propagation vs brute-force enumeration over all component states (exact
# oracle), the conditioning trace (w, psi(1), psi(0)) per diamond, cache-entry count, and an
# Interval corner-exactness check on Example A.
const REPO = raw"c:\Users\ohian\OneDrive - University of Strathclyde\Documents\Programmming Files\Julia Files\InformationPropagation\Info_Prop_Framework_Project"
using Pkg; Pkg.activate(REPO)
include(joinpath(REPO,"InfoPropFrmwrk","src","Algorithms","InfoPropFramework.jl")); using .InfoPropFramework

function build(edges, np::Dict{Int64,T}, lp::Dict{Tuple{Int64,Int64},T}) where T
    outgoing = Dict{Int64,Set{Int64}}(); incoming = Dict{Int64,Set{Int64}}()
    for (u,v) in edges; push!(get!(outgoing,u,Set{Int64}()), v); push!(get!(incoming,v,Set{Int64}()), u); end
    nodes = sort(collect(union(Set(u for (u,_) in edges), Set(v for (_,v) in edges))))
    sources = Set(n for n in nodes if !any(e->e[2]==n, edges))
    itersets, anc, desc = find_iteration_sets(edges, outgoing, incoming)
    fk, jn = identify_fork_and_join_nodes(outgoing, incoming)
    roots, uniq = new_identify(edges, np, lp, sources, fk, jn, anc, desc, itersets)
    return (; nodes, sources, outgoing, incoming, itersets, anc, desc, fk, jn, roots, uniq)
end

function propagate(edges, np::Dict{Int64,T}, lp::Dict{Tuple{Int64,Int64},T}; cache=nothing) where T
    g = build(edges, np, lp)
    c = cache === nothing ? Dict{CacheKey,DiamondCacheEntry{T}}() : cache
    bel = update_beliefs_iterative(edges, g.itersets, g.outgoing, g.incoming, g.sources,
        np, lp, g.desc, g.anc, g.roots, g.jn, g.fk, g.uniq, c)
    return bel, c, g
end

# Brute-force exact oracle: enumerate all node/edge indicator states, accumulate P(R_v = 1).
function brute_force(edges, np::Dict{Int64,Float64}, lp::Dict{Tuple{Int64,Int64},Float64})
    nodes = sort(collect(union(Set(u for (u,_) in edges), Set(v for (_,v) in edges))))
    sources = Set(n for n in nodes if !any(e->e[2]==n, edges))
    nn, ne = length(nodes), length(edges)
    nidx = Dict(n=>i for (i,n) in enumerate(nodes))
    bel = Dict(n=>0.0 for n in nodes)
    for mask in 0:(2^(nn+ne)-1)
        nodeup = [(mask >> (i-1)) & 1 == 1 for i in 1:nn]
        edgeup = [(mask >> (nn+j-1)) & 1 == 1 for j in 1:ne]
        p = 1.0
        for i in 1:nn; p *= nodeup[i] ? np[nodes[i]] : 1-np[nodes[i]]; end
        for j in 1:ne; p *= edgeup[j] ? lp[edges[j]] : 1-lp[edges[j]]; end
        p == 0.0 && continue
        # reachability under this state (topological by repeated relaxation; graphs are tiny)
        reach = Dict(n => (n in sources && nodeup[nidx[n]]) for n in nodes)
        for _ in 1:nn
            for (j,(u,v)) in enumerate(edges)
                if reach[u] && edgeup[j] && nodeup[nidx[v]]; reach[v] = true; end
            end
        end
        for n in nodes; reach[n] && (bel[n] += p); end
    end
    return bel
end

# Conditional signal map psi of a STORED diamond: rebuild the exact sub-problem updateDiamondJoin
# poses (diamond edge list; conditioning nodes forced to the state; other local sources at their
# contextual beliefs; join prior forced to 1; remaining nodes at their priors) and propagate it.
function psi_diamond(dan, join::Int, np::Dict{Int64,Float64}, lp, belief_dict, uniq, state::Dict{Int64,Float64})
    d = dan.diamond
    cd = uniq[create_diamond_hash_key(d)]
    sub_lp = Dict{Tuple{Int64,Int64},Float64}(e=>lp[e] for e in d.edgelist)
    subnp = Dict{Int64,Float64}()
    for n in d.relevant_nodes
        if n ∉ cd.sub_sources
            subnp[n] = (n == join) ? 1.0 : np[n]
        elseif haskey(state, n)
            subnp[n] = state[n]
        else
            subnp[n] = belief_dict[n]
        end
    end
    bel = update_beliefs_iterative(collect(d.edgelist), cd.sub_iteration_sets, cd.sub_outgoing_index,
        cd.sub_incoming_index, cd.sub_sources, subnp, sub_lp, cd.sub_descendants, cd.sub_ancestors,
        cd.sub_diamond_structures, cd.sub_join_nodes, cd.sub_fork_nodes, uniq,
        Dict{CacheKey,DiamondCacheEntry{Float64}}())
    return bel[join]
end

function trace_join(g, join::Int, np, lp, belief_dict, uniq; label="")
    for dan in g.roots[join]
        d = dan.diamond
        conds = sort(collect(d.conditioning_nodes))
        ws = [belief_dict[c] for c in conds]
        println("  $label join $join: C=$(conds), w=$(ws), nondi=$(sort(collect(dan.non_diamond_parents))), edges=$(sort(d.edgelist))")
        total = 0.0
        for mask in 0:(2^length(conds)-1)
            st = Dict{Int64,Float64}(c => ((mask>>(i-1))&1==1 ? 1.0 : 0.0) for (i,c) in enumerate(conds))
            p = psi_diamond(dan, join, np, lp, belief_dict, uniq, st)
            wgt = prod((mask>>(i-1))&1==1 ? ws[i] : 1-ws[i] for i in 1:length(conds))
            println("    state $(Tuple(st[c] for c in conds)): psi=$p  weight=$wgt")
            total += wgt*p
        end
        # recombine with the non-influencing parents' independent signals
        survival = 1.0 - total
        for p in dan.non_diamond_parents
            survival *= 1.0 - belief_dict[p]*lp[(p,join)]
            println("    non-influencing parent $p: signal=$(belief_dict[p]*lp[(p,join)])")
        end
        full = 1.0 - survival
        println("    group signal = $total ;  with non-influencing = $full ;  b($join) = prior*signal = $(np[join]*full)")
    end
end

println("="^100)
println("EXAMPLE S: simple diamond  edges (1,2),(2,3),(2,4),(3,5),(4,5); prior(1)=1.0, others 0.9, edges 0.9")
edgesS = [(1,2),(2,3),(2,4),(3,5),(4,5)]
npS = Dict{Int64,Float64}(1=>1.0, 2=>0.9, 3=>0.9, 4=>0.9, 5=>0.9)
lpS = Dict{Tuple{Int64,Int64},Float64}(e=>0.9 for e in edgesS)
belS, cS, gS = propagate(edgesS, npS, lpS)
bfS = brute_force(edgesS, npS, lpS)
for n in sort(collect(keys(belS)))
    println("  node $n: framework=$(belS[n])  brute=$(bfS[n])  diff=$(abs(belS[n]-bfS[n]))")
end
# the naive independent-update value at the join, for the text's failure demonstration
bf_ = belS[2]                       # b(fork)
Sp  = bf_*0.9*0.9*0.9               # signal through one parent: edge f->p, prior p, edge p->j
naive = 0.9 * (1 - (1 - Sp)^2)
println("  naive independent update at join 5: $naive  (overestimates exact $(belS[5]))")
# conditioning trace at the join (faithful sub-problem: diamond edge list, fork as cut source)
trace_join(gS, 5, npS, lpS, belS, gS.uniq; label="Example S")

println("="^100)
println("EXAMPLE A: running example  edges (1,2),(1,3),(2,8),(3,4),(3,5),(4,6),(5,6),(6,7),(7,8); ALL priors 0.9, edges 0.9")
edgesA = [(1,2),(1,3),(2,8),(3,4),(3,5),(4,6),(5,6),(6,7),(7,8)]
npA = Dict{Int64,Float64}(n=>0.9 for n in 1:8)
lpA = Dict{Tuple{Int64,Int64},Float64}(e=>0.9 for e in edgesA)
belA, cA, gA = propagate(edgesA, npA, lpA)
bfA = brute_force(edgesA, npA, lpA)
worst = 0.0
for n in sort(collect(keys(belA)))
    d = abs(belA[n]-bfA[n]); global worst = max(worst,d)
    println("  node $n: framework=$(belA[n])  brute=$(bfA[n])  diff=$d")
end
println("  worst |framework - brute| = $worst")
println("  distinct conditioned sub-problems stored (cache entries): $(length(cA))")
for (k, e) in cA
    println("    entry over edgelist $(sort(e.edgelist))  priors=$(sort(collect(e.current_priors), by=first))")
end
# conditioning traces (faithful framework-posed sub-problems, from the stored diamonds)
trace_join(gA, 8, npA, lpA, belA, gA.uniq; label="D1")
trace_join(gA, 6, npA, lpA, belA, gA.uniq; label="D2")
# inner diamond D3 inside D2's state R_1=1: locate it in D2's sub_diamond_structures and trace it
for dan in gA.roots[6]
    cd = gA.uniq[create_diamond_hash_key(dan.diamond)]
    for (j2, vec) in cd.sub_diamond_structures, inner in vec
        conds = sort(collect(inner.diamond.conditioning_nodes))
        # contextual belief of the inner conditioning node inside D2's state-1 sub-run:
        subnp = Dict{Int64,Float64}(1=>1.0, 3=>0.9, 4=>0.9, 5=>0.9, 6=>1.0)
        sub_lp = Dict{Tuple{Int64,Int64},Float64}(e=>lpA[e] for e in dan.diamond.edgelist)
        belctx = Dict{Int64,Float64}(3 => 1.0*0.9*0.9)   # b(3) inside the state-1 sub-run, by hand: w(1)=1, edge(1,3), prior(3)
        println("  inner diamond at join $j2 inside D2 state R_1=1: C=$conds, edges=$(sort(inner.diamond.edgelist))")
        for s in (1.0, 0.0)
            st = Dict{Int64,Float64}(conds[1] => s)
            p = psi_diamond(inner, j2, subnp, lpA, belctx, gA.uniq, st)
            println("    state ($s,): psi=$p")
        end
        w3 = belctx[conds[1]]
        p1 = psi_diamond(inner, j2, subnp, lpA, belctx, gA.uniq, Dict(conds[1]=>1.0))
        p0 = psi_diamond(inner, j2, subnp, lpA, belctx, gA.uniq, Dict(conds[1]=>0.0))
        println("    w=$w3 -> combined signal at $j2 given R_1=1: $(w3*p1+(1-w3)*p0)  [should equal D2 psi(1)]")
    end
end

println("="^100)
println("EXAMPLE W: the multi-level worked network (RESS Fig. decomp_dag_original). Numbering:")
println("  1..15 = n1..n15, 16 = T1, 17 = S1, 18 = S2, 19 = S3. Sources prior 1.0, others 0.9, edges 0.9.")
edgesW = [(17,1),(18,14),(19,7),(1,2),(1,3),(1,4),(2,5),(5,6),(3,6),(13,6),(14,13),(14,15),
          (15,12),(6,12),(12,16),(4,10),(8,4),(7,8),(7,9),(10,11),(9,11),(11,16)]
npW = Dict{Int64,Float64}(n => (n in (17,18,19) ? 1.0 : 0.9) for n in 1:19)
lpW = Dict{Tuple{Int64,Int64},Float64}(e=>0.9 for e in edgesW)
belW, cW, gW = propagate(edgesW, npW, lpW)

# Path-enumeration inclusion-exclusion oracle (2^41 component states rule out brute force).
function paths_to(edges, v, sources)
    incoming = Dict{Int64,Vector{Tuple{Int64,Int64}}}()
    for e in edges; push!(get!(incoming, e[2], Tuple{Int64,Int64}[]), e); end
    paths = Vector{Vector{Tuple{Int64,Int64}}}()
    function back(n, acc)
        if n in sources; push!(paths, reverse(acc)); return; end
        for e in get(incoming, n, Tuple{Int64,Int64}[])
            back(e[1], vcat(acc, [e]))
        end
    end
    back(v, Tuple{Int64,Int64}[])
    return paths
end
function path_ie(edges, np, lp, v, sources)
    v in sources && return np[v]
    ps = paths_to(edges, v, sources)
    isempty(ps) && return 0.0
    total = 0.0
    for mask in 1:(2^length(ps)-1)
        nodes = Set{Int64}(); es = Set{Tuple{Int64,Int64}}()
        bits = 0
        for i in 1:length(ps)
            if (mask>>(i-1))&1 == 1
                bits += 1
                for e in ps[i]; push!(es, e); push!(nodes, e[1]); push!(nodes, e[2]); end
            end
        end
        p = prod(np[n] for n in nodes) * prod(lp[e] for e in es)
        total += (bits % 2 == 1 ? p : -p)
    end
    return total
end
worstW = 0.0
for n in sort(collect(keys(belW)))
    oracle = path_ie(edgesW, npW, lpW, n, gW.sources)
    d = abs(belW[n]-oracle); global worstW = max(worstW,d)
    println("  node $n: framework=$(belW[n])  path-IE=$oracle  diff=$d")
end
println("  worst |framework - path-IE| = $worstW")
println("  distinct conditioned sub-problems stored (cache entries): $(length(cW))")
edgecounts = Dict{Int,Int}()
for (k,e) in cW; edgecounts[length(e.edgelist)] = get(edgecounts, length(e.edgelist), 0)+1; end
println("  entries by sub-network edge count: $(sort(collect(edgecounts)))")
println("  maximal diamonds at joins: $(sort(collect(keys(gW.roots))))")
trace_join(gW, 6,  npW, lpW, belW, gW.uniq; label="D1")
trace_join(gW, 11, npW, lpW, belW, gW.uniq; label="D2")
trace_join(gW, 12, npW, lpW, belW, gW.uniq; label="D3")
trace_join(gW, 16, npW, lpW, belW, gW.uniq; label="D4")

println("="^100)
println("EXAMPLE W, INTERVAL: non-source priors and all edges Interval(0.85,0.95); sources stay [1,1]")
npWI = Dict{Int64,Interval}(n => (n in (17,18,19) ? Interval(1.0,1.0) : Interval(0.85,0.95)) for n in 1:19)
lpWI = Dict{Tuple{Int64,Int64},Interval}(e=>Interval(0.85,0.95) for e in edgesW)
belWI, _, _ = propagate(edgesW, npWI, lpWI)
npWlo = Dict{Int64,Float64}(n => (n in (17,18,19) ? 1.0 : 0.85) for n in 1:19)
npWhi = Dict{Int64,Float64}(n => (n in (17,18,19) ? 1.0 : 0.95) for n in 1:19)
lpWlo = Dict{Tuple{Int64,Int64},Float64}(e=>0.85 for e in edgesW)
lpWhi = Dict{Tuple{Int64,Int64},Float64}(e=>0.95 for e in edgesW)
belWlo, _, _ = propagate(edgesW, npWlo, lpWlo)
belWhi, _, _ = propagate(edgesW, npWhi, lpWhi)
for n in (4, 6, 11, 12, 16)
    dlo = abs(belWI[n].lower - belWlo[n]); dhi = abs(belWI[n].upper - belWhi[n])
    println("  node $n: interval=[$(belWI[n].lower), $(belWI[n].upper)]  corners=[$(belWlo[n]), $(belWhi[n])]  diff=($dlo, $dhi)")
end

println("="^100)
println("EXAMPLE A, INTERVAL: all priors and edges Interval(0.85,0.95); corner check vs Float64 runs")
npI = Dict{Int64,Interval}(n=>Interval(0.85,0.95) for n in 1:8)
lpI = Dict{Tuple{Int64,Int64},Interval}(e=>Interval(0.85,0.95) for e in edgesA)
belI, _, _ = propagate(edgesA, npI, lpI)
npLo = Dict{Int64,Float64}(n=>0.85 for n in 1:8); lpLo = Dict{Tuple{Int64,Int64},Float64}(e=>0.85 for e in edgesA)
npHi = Dict{Int64,Float64}(n=>0.95 for n in 1:8); lpHi = Dict{Tuple{Int64,Int64},Float64}(e=>0.95 for e in edgesA)
belLo, _, _ = propagate(edgesA, npLo, lpLo)
belHi, _, _ = propagate(edgesA, npHi, lpHi)
for n in sort(collect(keys(belI)))
    dlo = abs(belI[n].lower - belLo[n]); dhi = abs(belI[n].upper - belHi[n])
    println("  node $n: interval=[$(belI[n].lower), $(belI[n].upper)]  corners=[$(belLo[n]), $(belHi[n])]  diff=($dlo, $dhi)")
end
println("done.")
