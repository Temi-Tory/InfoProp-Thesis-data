# Full CapacityAnalysisKit run on the oriented IEEE RTS-24, direct framework
# call (server not running this session — user runs it themselves; same
# analysis, same code path as /flow-analysis would use, just not the HTTP
# envelope). Answers the case-study questions from the requirements doc:
# deliverable throughput vs demand, binding cut, five most damaging line/
# generator failures, upgrade threshold for the two binding lines, SPOF.
#
# USAGE: julia --project=InfoPropFrmwrk "validation/flow/rts24/run_rts24_analysis.jl"

const REPO = raw"C:\Development\Info_Prop_Framework_Project\Info_Prop_Framework_Project"
using Pkg; Pkg.activate(REPO)
include(joinpath(REPO, "InfoPropFrmwrk", "src", "Algorithms", "InfoPropFramework.jl")); using .InfoPropFramework
const CAK = InfoPropFramework.CapacityAnalysisKit
using JSON, Printf

const HERE = joinpath(REPO, "validation", "flow", "rts24")
const LOG = open(joinpath(HERE, "rts24_analysis_log.txt"), "w")
logln(args...) = (println(LOG, args...); println(args...))

edgelist, outgoing_index, incoming_index, source_nodes_set = read_graph_to_dict(joinpath(HERE, "rts24.EDGES"))
nodes = sort!(collect(union(Set(u for (u,_) in edgelist), Set(v for (_,v) in edgelist))))
source_nodes = sort!(collect(source_nodes_set))
sink_nodes = sort!([n for n in nodes if !haskey(outgoing_index, n) || isempty(outgoing_index[n])])

j = JSON.parsefile(joinpath(HERE, "rts24-capacities.json"))
edge_caps = Dict{Tuple{Int64,Int64},Float64}((Int64(e["source"]), Int64(e["destination"])) => Float64(e["capacity"]) for e in j["edges"])
node_caps = Dict{Int64,Float64}(Int64(n["node"]) => Float64(n["capacity"]) for n in j["nodes"])

bus_pd = Dict(r[1] => r[3] for r in JSON.parsefile(joinpath(HERE, "rts24_raw_data.json"))["bus"]["rows"])
total_pd = sum(values(bus_pd))

logln("IEEE RTS-24 — oriented DAG, $(length(nodes)) nodes, $(length(edgelist)) edges")
logln("structural sources (generator buses, no incoming line): ", source_nodes)
logln("structural sinks (load buses, no outgoing line): ", sink_nodes)
logln("total system peak demand (all 17 load buses): $total_pd MW — NOTE: max-flow below is only between the")
logln("  structural source/sink SUBSET (buses with zero local load / zero local generation respectively);")
logln("  several other buses carry both generation and load and are not source or sink nodes in this graph,")
logln("  so this max-flow is not directly the whole system's deliverable throughput against total demand —")
logln("  flagged as a modeling limitation, not resolved here (see RESULTS.md).")
logln()

# node_capacities now applied — the build_node_split_graph ID-collision bug
# (v_in=2v/v_out=2v+1 colliding with RTS-24's own small 1..24 IDs once only a
# SUBSET of buses are split) is fixed (offset-based split IDs, see
# NodeCapacitatedFlowModule.jl and validation/flow/FINDINGS.md).
logln("=== unconstrained (edge capacities only, no generator node limits) ===")
edge_only = CAK.analyze_all(edgelist, outgoing_index, incoming_index, edge_caps, source_nodes, sink_nodes;
                             k_failure=2, cut_limit=200)
logln("max_flow = ", edge_only.flow.max_flow, " MVA")
logln()

logln("=== node-capacitated (generator buses limited to nameplate Pmax) ===")
ncf = CAK.solve_node_capacitated_flow(edgelist, outgoing_index, incoming_index, edge_caps, source_nodes, sink_nodes, node_caps)
logln("max_flow = ", ncf.max_flow, " MVA  (edge-capacity-only was ", edge_only.flow.max_flow, " MVA — generator")
logln("  nameplate limits are the binding constraint here, not the lines, once applied)")
logln()

r = edge_only

logln("=== throughput ===")
logln("max_flow = ", r.flow.max_flow, " MVA (between structural sources/sinks only)")
logln("min_cut_capacity = ", r.flow.mincut_capacity)

logln()
logln("=== binding cut ===")
mca = CAK.analyze_min_cuts(edgelist, outgoing_index, incoming_index, edge_caps, source_nodes, sink_nodes, r.flow; cut_limit=200)
for e in mca.representative_cut.crossing_edges
    logln("  ", e, " capacity=", edge_caps[e])
end

logln()
logln("=== single points of failure (nodes) ===")
spof = CAK.identify_spof_nodes(edgelist, outgoing_index, incoming_index, source_nodes, sink_nodes)
logln(spof)

logln()
logln("=== five most damaging single-line failures ===")
sef = CAK.analyze_single_edge_failures(edgelist, outgoing_index, incoming_index, edge_caps, source_nodes, sink_nodes, r.flow)
for rec in sef[1:min(5, length(sef))]
    logln(@sprintf("  %s  baseline=%.1f -> perturbed=%.1f  drop=%.1f", rec.edge, rec.baseline_flow, rec.perturbed_flow, rec.drop))
end

logln()
logln("=== two binding lines: upgrade threshold to +10%% flow ===")
if !isempty(mca.representative_cut.crossing_edges)
    target = r.flow.max_flow * 1.10
    for e in mca.representative_cut.crossing_edges[1:min(2, length(mca.representative_cut.crossing_edges))]
        try
            up = CAK.find_upgrade_threshold(edgelist, outgoing_index, incoming_index, edge_caps, source_nodes, sink_nodes, e, target)
            logln(@sprintf("  %s  original_capacity=%.1f  required_capacity=%.1f  required_increase=%.1f  target_flow=%.1f  already_sufficient=%s",
                           e, up.original_capacity, up.required_capacity, up.required_increase, target, up.already_sufficient))
        catch err
            logln("  ", e, " upgrade threshold: ERROR ", sprint(showerror, err))
        end
    end
end

close(LOG)
println("\nwrote rts24_analysis_log.txt")
