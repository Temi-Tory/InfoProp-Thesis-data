# Grid IPA vs CUDD cost, mirroring grid_full_suite.jl's COST section exactly: @benchmark, evals=1, MINIMUM time,
# memory, allocs. IPA: propagate(T,w) (inputs + identify + update). CUDD: bdd_reliability(...; sift=true) (build+eval).
const SRC = raw"C:\Users\ohian\OneDrive - University of Strathclyde\Documents\Programmming Files\Julia Files\InformationPropagation\Info_Prop_Framework_Project"
using Pkg; Pkg.activate(joinpath(@__DIR__,"env")); push!(LOAD_PATH, joinpath(@__DIR__,"validation","bddenv"))
include(joinpath(SRC,"InfoPropFrmwrk","src","Algorithms","InfoPropFramework.jl")); using .InfoPropFramework
using CUDD, Random, Printf, BenchmarkTools
include(joinpath(@__DIR__,"validation","graph_gen.jl")); include(joinpath(@__DIR__,"validation","oracles.jl"))
include(joinpath(@__DIR__,"validation","bdd_oracle.jl")); using .BDDReliabilityOracle
g  = load_edges("grid", joinpath(@__DIR__,"net","grid-graph","grid-graph.EDGES"))
P  = make_problem(g); fk,jn = identify_fork_and_join_nodes(P.outgoing,P.incoming)
function inputs(T,w)
    if T==Float64
        Dict{Int64,Float64}(n=>1.0 for n in P.all_nodes), Dict{Tuple{Int64,Int64},Float64}(e=>0.9 for e in keys(P.eid))
    else
        Dict{Int64,Interval}(n=>Interval(1.0,1.0) for n in P.all_nodes),
        Dict{Tuple{Int64,Int64},Interval}(e=>Interval(max(0.0,0.9-w),min(1.0,0.9+w)) for e in keys(P.eid))
    end
end
mkcache(::Type{Float64})=Dict{CacheKey,DiamondCacheEntry{Float64}}(); mkcache(::Type{Interval})=Dict{CacheKey,DiamondCacheEntry{Interval}}()
function propagate(T,w)
    np,lp = inputs(T,w)
    r,u = new_identify(P.edgelist,np,lp,Set{Int64}(P.sources),fk,jn,P.anc,P.desc,P.itersets)
    update_beliefs_iterative(P.edgelist,P.itersets,P.outgoing,P.incoming,P.sources,np,lp,P.desc,P.anc,r,jn,fk,u,mkcache(T))
end
bdd_pt(links) = bdd_reliability(collect(P.edgelist), Dict(Int(n)=>1.0 for n in P.all_nodes),
                    Dict{Tuple{Int,Int},Float64}(e=>links for e in keys(P.eid)), collect(P.sources); sift=true)
# CUDD-side (C heap) memory and peak nodes for one build (not visible to Julia's allocator)
function cudd_native()
    mgr = Cudd_Init(0,0,256,262144,0); Cudd_AutodynEnable(mgr, CUDD.CUDD_REORDER_SIFT)
    ith(id)=Cudd_bddIthVar(mgr,id-1); And(f,g)=(r=Cudd_bddAnd(mgr,f,g);Cudd_Ref(r);r); Or(f,g)=(r=Cudd_bddOr(mgr,f,g);Cudd_Ref(r);r)
    Zero=Cudd_ReadLogicZero(mgr); reach=Dict{Int,Ptr{Nothing}}()
    for n in P.topo
        base=ith(P.nid[n]); if n in P.sources; r=base else acc=Zero; for u in get(P.incoming,n,Set{Int}()); acc=Or(acc,And(reach[u],ith(P.eid[(u,n)]))); end; r=And(base,acc) end
        Cudd_Ref(r); reach[n]=r
    end
    Cudd_ReduceHeap(mgr, CUDD.CUDD_REORDER_SIFT, 0)
    m = try Int(Cudd_ReadMemoryInUse(mgr)) catch; -1 end
    pk = try Int(Cudd_ReadPeakNodeCount(mgr)) catch; -1 end
    nn = Int(Cudd_ReadNodeCount(mgr)); Cudd_Quit(mgr); (nn, pk, m)
end
println("grid V=$(length(P.all_nodes)) E=$(length(g.edges))"); flush(stdout)
case = ARGS[1]
function bench(label, f; n=30)
    b = @benchmark $f() samples=n seconds=90 evals=1
    @printf("RESULT %-30s min %.3f ms  median %.3f ms  mem %.2f MiB  allocs %d\n", label, minimum(b).time/1e6, median(b).time/1e6, b.memory/2^20, b.allocs); flush(stdout)
end
if case=="ipa"
    propagate(Float64,0.0); propagate(Interval,0.05); propagate(Interval,0.10)
    bench("IPA_Float64", ()->propagate(Float64,0.0),n=50); bench("IPA_Interval_w0.05", ()->propagate(Interval,0.05),n=50); bench("IPA_Interval_w0.10", ()->propagate(Interval,0.10),n=50)
elseif case=="cudd_f64"
    for _ in 1:15; bdd_pt(0.9); end
    bench("CUDD_Float64_build_eval", ()->bdd_pt(0.9))
elseif case=="cudd_int"
    for _ in 1:3; bdd_pt(0.9); end
    bench("CUDD_Interval_2builds", ()->(bdd_pt(0.85); bdd_pt(0.95)), n=15)
end
