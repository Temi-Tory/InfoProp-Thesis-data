# ASCE grid reproduction (Tong & Tien 2019, ASCE-ASME J. Risk Uncertainty Eng. Syst. A, Fig. 10):
# sources {1,3,13}, node priors 1.0, all links R_l, compared node-by-node against Tables 2 (R_l=0.9)
# and 3 (R_l=0.1). Uses the CURRENT production pipeline (new_identify/update_beliefs_iterative),
# not the reference-recursion cross-check in grid_beliefs.jl. Real, persisted network file
# (dag_ntwrk_files/grid-graph/grid-graph.EDGES) -- not reconstructed from the figure.
const REPO = raw"C:\Development\Info_Prop_Framework_Project\Info_Prop_Framework_Project"
using Pkg; Pkg.activate(joinpath(REPO, "InfoPropFrmwrk"))
include(joinpath(REPO, "InfoPropFrmwrk", "src", "Algorithms", "InfoPropFramework.jl")); using .InfoPropFramework
using Printf

edgelist, outgoing_index, incoming_index, source_nodes_set = read_graph_to_dict(joinpath(REPO, "dag_ntwrk_files", "grid-graph", "grid-graph.EDGES"))
nodes = sort!(collect(union(Set(u for (u,_) in edgelist), Set(v for (_,v) in edgelist))))
sources = source_nodes_set
println("nodes=", length(nodes), "  edges=", length(edgelist), "  sources=", sort(collect(sources)))
fork_nodes, join_nodes = identify_fork_and_join_nodes(outgoing_index, incoming_index)
iteration_sets, ancestors, descendants = find_iteration_sets(edgelist, outgoing_index, incoming_index)

# Table 2 (R_l=0.9) and Table 3 (R_l=0.1), Exact column, from the paper directly (page 7).
table2 = Dict(2=>0.99000,4=>0.98015,5=>0.90000,6=>0.99510,7=>0.98956,8=>0.89060,9=>0.98100,
              10=>0.88290,11=>0.97734,12=>0.97457,14=>0.97946,15=>0.98498,16=>0.98539)
table3 = Dict(2=>0.19000,4=>0.10092,5=>0.10000,6=>0.02986,7=>0.10269,8=>0.01027,9=>0.10900,
              10=>0.01090,11=>0.01135,12=>0.00215,14=>0.10098,15=>0.01122,16=>0.00134)

for (Rl, table, label) in ((0.9, table2, "Table 2"), (0.1, table3, "Table 3"))
    node_priors = Dict(n => 1.0 for n in nodes)
    link_probability = Dict(e => Rl for e in edgelist)
    root_diamonds, unique_diamonds = new_identify(edgelist, node_priors, link_probability, sources, fork_nodes, join_nodes, ancestors, descendants, iteration_sets)
    beliefs = update_beliefs_iterative(edgelist, iteration_sets, outgoing_index, incoming_index, sources, node_priors, link_probability, descendants, ancestors, root_diamonds, join_nodes, fork_nodes, unique_diamonds)
    println("\n=== R_l=$Rl vs $label ===")
    worst = 0.0
    for n in sort(collect(keys(table)))
        exact = table[n]
        ours = beliefs[n]
        diff = abs(ours - exact)
        worst = max(worst, diff)
        @printf("  node %-3d exact=%.5f  ours=%.10f  diff=%.3e\n", n, exact, ours, diff)
    end
    @printf("worst |diff| over all %d compared nodes = %.3e\n", length(table), worst)
end
println("\ndone")
