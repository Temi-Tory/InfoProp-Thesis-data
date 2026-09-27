const SRC = raw"C:\Users\ohian\OneDrive - University of Strathclyde\Documents\Programmming Files\Julia Files\InformationPropagation\Info_Prop_Framework_Project"
using Pkg; Pkg.activate(joinpath(@__DIR__,"env")); push!(LOAD_PATH, joinpath(@__DIR__,"validation","bddenv"))
include(joinpath(SRC,"InfoPropFrmwrk","src","Algorithms","InfoPropFramework.jl")); using .InfoPropFramework
using CUDD, Printf
include(joinpath(@__DIR__,"validation","bdd_oracle.jl")); using .BDDReliabilityOracle
edges,outgoing,incoming,src_vec = read_graph_to_dict(joinpath(@__DIR__,"net",ARGS[1],ARGS[1]*".EDGES"))
nodes = sort(collect(union(Set(u for (u,_) in edges), Set(v for (_,v) in edges))))
np = Dict{Int64,Float64}(n=>0.9 for n in nodes); lp = Dict{Tuple{Int64,Int64},Float64}(e=>0.9 for e in edges)
itersets,anc,desc = find_iteration_sets(edges,outgoing,incoming); fk,jn = identify_fork_and_join_nodes(outgoing,incoming)
sources = Set{Int64}(src_vec)
t_ipa = @elapsed begin
    r,u = new_identify(edges,np,lp,sources,fk,jn,anc,desc,itersets)
    global bel = update_beliefs_iterative(edges,itersets,outgoing,incoming,sources,np,lp,desc,anc,r,jn,fk,u,Dict{CacheKey,DiamondCacheEntry{Float64}}())
end
@printf("NET V=%d E=%d sources=%s  IPA Float64 (cold) %.3f s\n", length(nodes), length(edges), sort(collect(sources)), t_ipa); flush(stdout)
println("starting sifted CUDD build ..."); flush(stdout)
t_bdd = @elapsed ((b, st) = bdd_reliability(collect(Tuple{Int,Int},edges), Dict{Int,Float64}(Int(n)=>0.9 for n in nodes), Dict{Tuple{Int,Int},Float64}((Int(a),Int(c))=>0.9 for (a,c) in edges), collect(sources); sift=true))
worst = maximum(abs(bel[n]-b[n]) for n in nodes)
@printf("CUDD sifted: nodes=%d vars=%d reorderings=%d time=%.2f s ; worst |IPA-BDD| = %.3e\n", st.bdd_total_nodes, st.n_vars, st.reorderings, t_bdd, worst)
