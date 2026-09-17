const REPO = raw"C:\Development\Info_Prop_Framework_Project\Info_Prop_Framework_Project"
using Pkg; Pkg.activate(joinpath(REPO, "InfoPropFrmwrk"))
include(joinpath(REPO, "InfoPropFrmwrk", "src", "Algorithms", "InfoPropFramework.jl")); using .InfoPropFramework
using Printf

edgelist, outgoing_index, incoming_index, source_nodes_set = read_graph_to_dict(joinpath(REPO, "dag_ntwrk_files", "net3-water", "net3-water.EDGES"))
nodes = sort(collect(union(Set(u for (u,_) in edgelist), Set(v for (_,v) in edgelist))))
sinks = sort([n for n in nodes if isempty(get(outgoing_index, n, Set{Int}()))])
sources = sort(collect(source_nodes_set))
println("nodes=", length(nodes), " edges=", length(edgelist), " sources=", sources, " sinks=", sinks)

fork_nodes, join_nodes = identify_fork_and_join_nodes(outgoing_index, incoming_index)
iteration_sets, ancestors, descendants = find_iteration_sets(edgelist, outgoing_index, incoming_index)
println("forks=", length(fork_nodes), " joins=", length(join_nodes), " layers=", length(iteration_sets))

node_priors = Dict(n => 0.9 for n in nodes)
link_probability = Dict(e => 0.9 for e in edgelist)
root_diamonds, unique_diamonds = new_identify(edgelist, node_priors, link_probability, Set(sources), fork_nodes, join_nodes, ancestors, descendants, iteration_sets)
maxcond = length(unique_diamonds) == 0 ? 0 : maximum(length(dc.diamond.conditioning_nodes) for dc in values(unique_diamonds))
@printf("unique diamonds=%d maxcond=%d\n", length(unique_diamonds), maxcond)
println("done")
