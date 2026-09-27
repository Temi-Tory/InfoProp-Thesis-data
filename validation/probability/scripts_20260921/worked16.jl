const SRC = raw"C:\Users\ohian\OneDrive - University of Strathclyde\Documents\Programmming Files\Julia Files\InformationPropagation\Info_Prop_Framework_Project"
using Pkg; Pkg.activate(joinpath(@__DIR__,"env"))
include(joinpath(SRC,"InfoPropFrmwrk","src","Algorithms","InfoPropFramework.jl")); using .InfoPropFramework
using Printf
# S1=17,S2=18,S3=19
edges = [(17,1),(18,14),(19,7),(1,2),(1,3),(1,4),(2,5),(3,6),(5,6),(13,6),(14,13),(14,15),(15,12),(6,12),(7,8),(7,9),(8,4),(4,10),(10,11),(9,11),(11,16),(12,16)]
nodes = sort(collect(union(Set(u for (u,_) in edges), Set(v for (_,v) in edges))))
sources = Set([17,18,19])
np = Dict{Int64,Float64}(n=>(n in sources ? 1.0 : 0.9) for n in nodes); lp = Dict{Tuple{Int64,Int64},Float64}(e=>0.9 for e in edges)
outgoing = Dict{Int64,Set{Int64}}(); incoming = Dict{Int64,Set{Int64}}()
for (u,v) in edges; push!(get!(outgoing,u,Set{Int64}()),v); push!(get!(incoming,v,Set{Int64}()),u); end
itersets,anc,desc = find_iteration_sets(edges,outgoing,incoming)
fk,jn = identify_fork_and_join_nodes(outgoing,incoming)
roots,uniq = new_identify(edges,np,lp,sources,fk,jn,anc,desc,itersets)
bel = update_beliefs_iterative(edges,itersets,outgoing,incoming,sources,np,lp,desc,anc,roots,jn,fk,uniq)
for n in [1,4,6,11,12,16]; @printf("b(%d)=%.7f\n",n,bel[n]); end
println("roots=",length(roots)," uniq=",length(uniq)," maxcond=",maximum(length(cd.diamond.conditioning_nodes) for (_,cd) in uniq))
for (hk,cd) in uniq; println(" cond=",sort(collect(cd.diamond.conditioning_nodes))," edges=",length(cd.diamond.edgelist)); end
