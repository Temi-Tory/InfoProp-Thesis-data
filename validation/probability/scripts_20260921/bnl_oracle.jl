const SRC = raw"C:\Users\ohian\OneDrive - University of Strathclyde\Documents\Programmming Files\Julia Files\InformationPropagation\Info_Prop_Framework_Project"
using Pkg; Pkg.activate(joinpath(@__DIR__,"env")); push!(LOAD_PATH, joinpath(@__DIR__,"validation","bddenv"))
include(joinpath(SRC,"InfoPropFrmwrk","src","Algorithms","InfoPropFramework.jl")); using .InfoPropFramework
using CUDD, Printf
include(joinpath(@__DIR__,"validation","bdd_oracle.jl")); using .BDDReliabilityOracle
name = ARGS[1]
edges,outgoing,incoming,src_vec = read_graph_to_dict(joinpath(@__DIR__,"net",name,name*".EDGES"))
nodes = sort(collect(union(Set(u for (u,_) in edges), Set(v for (_,v) in edges))))
sources = Set{Int64}(src_vec)
mk(p,q) = (Dict{Int64,typeof(p)}(n=>p for n in nodes), Dict{Tuple{Int64,Int64},typeof(p)}(e=>p for e in edges))
itersets,anc,desc = find_iteration_sets(edges,outgoing,incoming); fk,jn = identify_fork_and_join_nodes(outgoing,incoming)
function ipa(np,lp,T)
    r,u = new_identify(edges,np,lp,sources,fk,jn,anc,desc,itersets)
    b = update_beliefs_iterative(edges,itersets,outgoing,incoming,sources,np,lp,desc,anc,r,jn,fk,u,Dict{CacheKey,DiamondCacheEntry{T}}())
    (b, length(u), isempty(u) ? 0 : maximum(length(cd.diamond.conditioning_nodes) for (_,cd) in u))
end
npf,lpf = mk(0.9,0.9); npi,lpi = mk(Interval(0.85,0.95),Interval(0.85,0.95))
tf = @elapsed ((bf,nu,mc) = ipa(npf,lpf,Float64))
@printf("IPA_F64 %s V=%d E=%d uniq=%d maxcond=%d t=%.2fs\n", name, length(nodes), length(edges), nu, mc, tf); flush(stdout)
ti = @elapsed ((bi,_,_) = ipa(npi,lpi,Interval))
@printf("IPA_INT %s t=%.2fs\n", name, ti); flush(stdout)
bd(p) = bdd_reliability(collect(Tuple{Int,Int},edges), Dict{Int,Float64}(Int(n)=>p for n in nodes), Dict{Tuple{Int,Int},Float64}((Int(a),Int(c))=>p for (a,c) in edges), collect(sources); sift=true)
tb = @elapsed ((b9,st) = bd(0.9))
@printf("BDD_F64 %s robdd_nodes=%d t=%.2fs\n", name, st.bdd_total_nodes, tb); flush(stdout)
dF = maximum(abs(bf[n]-b9[n]) for n in nodes)
(blo,_) = bd(0.85); (bhi,_) = bd(0.95)
over = maximum(max(blo[n]-bi[n].lower, bi[n].upper-bhi[n], 0.0) for n in nodes)
uns  = maximum(max(bi[n].lower-blo[n], bhi[n]-bi[n].upper, 0.0) for n in nodes)
@printf("RESULT %s V=%d E=%d uniq=%d maxcond=%d robdd=%d f64_delta=%.3e int_overwidth=%.3e int_unsound=%.3e\n", name, length(nodes), length(edges), nu, mc, st.bdd_total_nodes, dF, over, uns)
