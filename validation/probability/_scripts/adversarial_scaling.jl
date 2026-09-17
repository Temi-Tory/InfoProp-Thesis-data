# Scaling / crossover study on the adversarial families: how sifted-ROBDD size and IPA operation count
# grow with the stress parameter. Shows the complementary worst cases.
#   fanin-k : IPA op-count ~ 2^k, ROBDD linear in k   (IPA loses)
#   mesh-w  : ROBDD grows with width w, IPA modest     (BDD loses, if it does)
# Correctness of a few small instances is checked against the tiered oracle (path-enum, else Monte Carlo).
# GUARDS: ROBDD build aborts past NODE_CAP live nodes; IPA fan-in only run while 2^k <= OP_CAP.
const REPO = raw"c:\Users\ohian\OneDrive - University of Strathclyde\Documents\Programmming Files\Julia Files\InformationPropagation\Info_Prop_Framework_Project"
using Pkg; Pkg.activate(REPO)
push!(LOAD_PATH, joinpath(REPO,"validation","bddenv"))
include(joinpath(REPO,"InfoPropFrmwrk","src","Algorithms","InfoPropFramework.jl")); using .InfoPropFramework
using CUDD, Random, Printf
include(joinpath(REPO,"validation","graph_gen.jl")); include(joinpath(REPO,"validation","oracles.jl"))
include(joinpath(REPO,"validation","new_identify.jl"))
include(joinpath(REPO,"validation","graph_adversarial.jl"))
include(joinpath(REPO,"validation","bdd_oracle.jl")); using .BDDReliabilityOracle
include(joinpath(REPO,"validation","oracles_tiered.jl")); using .TieredOracles

const NODE_CAP = 3_000_000
const OP_CAP   = 300_000

# guarded sifted-ROBDD node count (edges+sources only)
function bdd_nodes(edges, sources; cap=NODE_CAP)
    nodes = sort(collect(union(Set(u for (u,_) in edges), Set(v for (_,v) in edges))))
    nid = Dict(n=>i for (i,n) in enumerate(nodes)); eid=Dict{Tuple{Int,Int},Int}()
    for (k,e) in enumerate(edges); eid[e]=length(nodes)+k; end
    inc=Dict{Int,Vector{Int}}(); for (u,v) in edges; push!(get!(inc,v,Int[]),u); end
    _topo(ns,ed)=begin d=Dict(v=>0 for v in ns);o=Dict(v=>Int[] for v in ns);for (u,v) in ed;d[v]+=1;push!(o[u],v);end
        q=sort([v for v in ns if d[v]==0]);r=Int[];while !isempty(q);u=popfirst!(q);push!(r,u);for w in o[u];d[w]-=1;d[w]==0&&push!(q,w);end;end;r;end
    try
        mgr=Cudd_Init(0,0,256,262144,0); Cudd_AutodynEnable(mgr,CUDD.CUDD_REORDER_SIFT)
        ith(i)=Cudd_bddIthVar(mgr,i-1); And(f,g)=(r=Cudd_bddAnd(mgr,f,g);Cudd_Ref(r);r); Or(f,g)=(r=Cudd_bddOr(mgr,f,g);Cudd_Ref(r);r)
        Z=Cudd_ReadLogicZero(mgr); srcset=Set(sources); reach=Dict{Int,Ptr{Nothing}}()
        for v in _topo(nodes,edges)
            base=ith(nid[v])
            if v in srcset; r=base else; acc=Z; for u in get(inc,v,Int[]); acc=Or(acc,And(reach[u],ith(eid[(u,v)]))); end; r=And(base,acc) end
            Cudd_Ref(r); reach[v]=r
            Int(Cudd_ReadNodeCount(mgr))>cap && (nc=Int(Cudd_ReadNodeCount(mgr));Cudd_Quit(mgr);return (:blowup,nc))
        end
        Cudd_ReduceHeap(mgr,CUDD.CUDD_REORDER_SIFT,0); t=Int(Cudd_ReadNodeCount(mgr)); Cudd_Quit(mgr); (:ok,t)
    catch; (:error,-1) end
end

function ipa_opcount(edges, sources)
    n = maximum(maximum(e) for e in edges)
    g = Graph(n, sort(collect(edges)), sort(collect(sources)), "adv")
    P = make_problem(g); D = draw_probs(P, MersenneTwister(1007))
    fork, join = identify_fork_and_join_nodes(P.outgoing, P.incoming)
    roots, uniq = new_identify(P.edgelist, D.node_priors, D.link_probs, Set{Int64}(P.sources), fork, join, P.anc, P.desc, P.itersets)
    maxc = isempty(uniq) ? 0 : maximum(length(cd.diamond.conditioning_nodes) for (_,cd) in uniq)
    cache = Dict{CacheKey, DiamondCacheEntry{Float64}}()
    bel = update_beliefs_iterative(P.edgelist, P.itersets, P.outgoing, P.incoming, P.sources, D.node_priors, D.link_probs, P.desc, P.anc, roots, join, fork, uniq, cache)
    (length(cache)+1, length(uniq), maxc, P, D, bel)
end

# validate a small instance via tiered oracle
function validate(edges, sources, P, D, bel)
    np = Dict{Int,Float64}(n=>D.node_priors[n] for n in P.all_nodes)
    lp = Dict{Tuple{Int,Int},Float64}(e=>D.link_probs[e] for e in keys(P.eid))
    pe = path_enum_reliability(collect(edges), np, lp, collect(sources); path_cap=18)
    if pe !== nothing
        return ("pathenum", maximum(abs(bel[n]-pe[n]) for n in keys(pe)))
    end
    mc, er = monte_carlo_reliability(collect(edges), np, lp, collect(sources); N=1_000_000, seed=7)
    ("MC", maximum(abs(bel[n]-mc[n]) for n in P.all_nodes) / max(maximum(values(er)),1e-12))  # in stderr units
end

println("family,param,V,E,ipa_ops,ipa_uniq,ipa_maxcond,bdd_status,bdd_nodes,valid_oracle,valid_metric")
# fanin-k
for k in 2:2:16
    2^k > OP_CAP && break
    e, s = gen_fanin_k(k); V=length(union(Set(u for (u,_) in e),Set(v for (_,v) in e)))
    op, nu, mc, P, D, bel = ipa_opcount(e, s)
    bs, bn = bdd_nodes(e, s)
    vo, vm = k <= 10 ? validate(e, s, P, D, bel) : ("skip", -1.0)
    @printf("fanin,%d,%d,%d,%d,%d,%d,%s,%d,%s,%.3e\n", k, V, length(e), op, nu, mc, bs, bn, vo, vm)
end
# mesh-w (fixed length L=8)
for w in 2:8
    e, s = gen_mesh(w, 8); V=length(union(Set(u for (u,_) in e),Set(v for (_,v) in e)))
    op, nu, mc, P, D, bel = ipa_opcount(e, s)
    bs, bn = bdd_nodes(e, s)
    vo, vm = w <= 5 ? validate(e, s, P, D, bel) : ("skip", -1.0)
    @printf("mesh,%d,%d,%d,%d,%d,%d,%s,%d,%s,%.3e\n", w, V, length(e), op, nu, mc, bs, bn, vo, vm)
end
println("# done")
