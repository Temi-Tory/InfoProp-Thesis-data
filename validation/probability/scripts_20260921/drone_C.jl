const SRC = raw"C:\Users\ohian\OneDrive - University of Strathclyde\Documents\Programmming Files\Julia Files\InformationPropagation\Info_Prop_Framework_Project"
using Pkg; Pkg.activate(joinpath(@__DIR__,"env"))
include(joinpath(SRC,"InfoPropFrmwrk","src","Algorithms","InfoPropFramework.jl")); using .InfoPropFramework
using Printf
for name in ["drone-network-fw-reliant-centralized","drone-network-vtol-dense-decentralized","drone-network-concentrated-minimal"]
    try
    base = joinpath(@__DIR__,"net",name)
    edges,outgoing,incoming,src_vec = read_graph_to_dict(joinpath(base,"$name.EDGES"))
    np = read_node_priors_from_json(joinpath(base,"interval","$name-nodepriors.json"))
    lp = read_edge_probabilities_from_json(joinpath(base,"interval","$name-linkprobabilities.json"))
    itersets,anc,desc = find_iteration_sets(edges,outgoing,incoming)
    fk,jn = identify_fork_and_join_nodes(outgoing,incoming)
    local uniq
    t = @elapsed ((_,uniq) = new_identify(edges,np,lp,Set(src_vec),fk,jn,anc,desc,itersets))
    mc = isempty(uniq) ? 0 : maximum(length(cd.diamond.conditioning_nodes) for (_,cd) in uniq)
    @printf("%s,E=%d,uniq=%d,maxcond=%d,identify_s=%.2f\n",name,length(edges),length(uniq),mc,t); flush(stdout)
    catch ex; println(name," FAILED: ",sprint(showerror,ex)[1:min(end,300)]); flush(stdout); end
end
