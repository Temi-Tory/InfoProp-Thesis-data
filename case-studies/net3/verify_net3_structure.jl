# Net3 case study, section 1: structure verification against the framework's own graph object.
# Requirements doc: "check the graph object's zero-in-degree nodes are exactly the reservoirs
# (and any tank oriented as a source), and its sinks are demand junctions. Report the counts:
# nodes, edges, sources, sinks, forks, joins, layers, unique diamonds, maximum conditioning
# width (the corpus inventory has 97 nodes, 51 diamonds, width 5; confirm after orientation)."
const REPO = raw"C:\Development\Info_Prop_Framework_Project\Info_Prop_Framework_Project"
using Pkg; Pkg.activate(joinpath(REPO, "InfoPropFrmwrk"))
include(joinpath(REPO, "InfoPropFrmwrk", "src", "Algorithms", "InfoPropFramework.jl")); using .InfoPropFramework
using Printf

const NET3DIR = joinpath(REPO, "dag_ntwrk_files", "net3")
edgelist, outgoing_index, incoming_index, source_nodes_set = read_graph_to_dict(joinpath(NET3DIR, "net3.EDGES"))
nodes = sort(collect(union(Set(u for (u,_) in edgelist), Set(v for (_,v) in edgelist))))
sinks = sort([n for n in nodes if isempty(get(outgoing_index, n, Set{Int}()))])
sources = sort(collect(source_nodes_set))

println("nodes=", length(nodes), "  edges=", length(edgelist))
println("sources (indegree 0) = ", sources, "  (n=", length(sources), ")")
println("sinks (outdegree 0)  = ", sinks, "  (n=", length(sinks), ")")

# node type lookup from net3-node-mapping.txt
node_type = Dict{Int,String}()
open(joinpath(NET3DIR, "net3-node-mapping.txt")) do io
    readline(io)
    for line in eachline(io)
        parts = split(line, ',')
        node_type[parse(Int, parts[2])] = parts[3]
    end
end
println("\nsource node types: ", [(n, node_type[n]) for n in sources])
n_reservoirs = count(==("reservoir"), values(node_type))
n_tanks = count(==("tank"), values(node_type))
n_junctions = count(==("junction"), values(node_type))
println("node types overall: reservoir=$n_reservoirs tank=$n_tanks junction=$n_junctions")
non_reservoir_sources = [n for n in sources if node_type[n] != "reservoir"]
println("sources that are NOT reservoirs (expect: tanks oriented as sources, if any): ",
        [(n, node_type[n]) for n in non_reservoir_sources])
non_junction_sinks = [n for n in sinks if node_type[n] != "junction"]
println("sinks that are NOT junctions (flag if any): ", [(n, node_type[n]) for n in non_junction_sinks])

fork_nodes, join_nodes = identify_fork_and_join_nodes(outgoing_index, incoming_index)
iteration_sets, ancestors, descendants = find_iteration_sets(edgelist, outgoing_index, incoming_index)
println("\nforks=", length(fork_nodes), "  joins=", length(join_nodes), "  layers=", length(iteration_sets))

for (label, np, lp) in (
    ("degenerate (all priors/links = 1.0)", Dict(n => 1.0 for n in nodes), Dict(e => 1.0 for e in edgelist)),
    ("non-degenerate (uniform 0.9)", Dict(n => 0.9 for n in nodes), Dict(e => 0.9 for e in edgelist)),
)
    root_diamonds, unique_diamonds = new_identify(edgelist, np, lp, Set(sources), fork_nodes, join_nodes, ancestors, descendants, iteration_sets)
    maxcond = length(unique_diamonds) == 0 ? 0 : maximum(length(dc.diamond.conditioning_nodes) for dc in values(unique_diamonds))
    @printf("%-40s unique diamonds=%-4d maxcond=%d\n", label, length(unique_diamonds), maxcond)
end
println("\n(corpus inventory expectation: 97 nodes, 51 diamonds, width 5)")
println("done")
