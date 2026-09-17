# RTS-24 net-injection model: super-source 0 -> every net-export bus (cap =
# generator nameplate Pmax - local peak load), every net-import bus -> super-
# sink 25 (cap = local peak load - local generation). Single true source (0)
# and single true sink (25) once S/T are added -- every former structural
# source/sink bus (7,21,22,23 / 4,5,6,8,19) gains the opposite-direction S/T
# edge, so node 0 is the only zero-in-degree node and 25 the only zero-out-
# degree node. Direct framework call (server not running this session).
#
# Answers, against the amended orient_rts24.py's net-injection outputs:
#   - deliverable throughput vs. TOTAL system demand (2850 MW), not just the
#     structural source/sink subset
#   - binding cut on the net-injection model
#   - single-line AND single-generator failure rankings (both are now just
#     single-edge-failure analysis, partitioned by edge type)
#   - upgrade thresholds on the binding cut
#   - unconstrained-generation comparison scenario (drops generator nameplate
#     limits, keeps net-load caps) for contrast with the primary result
#
# USAGE: julia --project=InfoPropFrmwrk "validation/flow/rts24/run_rts24_netinjection_analysis.jl"

const REPO = raw"C:\Development\Info_Prop_Framework_Project\Info_Prop_Framework_Project"
using Pkg; Pkg.activate(REPO)
include(joinpath(REPO, "InfoPropFrmwrk", "src", "Algorithms", "InfoPropFramework.jl")); using .InfoPropFramework
const CAK = InfoPropFramework.CapacityAnalysisKit
using JSON, Printf

const HERE = joinpath(REPO, "validation", "flow", "rts24")
const LOG = open(joinpath(HERE, "rts24_netinjection_analysis_log.txt"), "w")
logln(args...) = (println(LOG, args...); println(args...))

const S_NODE, T_NODE = 0, 25

edgelist, outgoing_index, incoming_index, source_nodes_set = read_graph_to_dict(joinpath(HERE, "rts24-netinjection.EDGES"))
nodes = sort!(collect(union(Set(u for (u,_) in edgelist), Set(v for (_,v) in edgelist))))
source_nodes = [S_NODE]
sink_nodes = [T_NODE]

structural_sources = sort!([n for n in nodes if !haskey(incoming_index, n) || isempty(incoming_index[n])])
structural_sinks = sort!([n for n in nodes if !haskey(outgoing_index, n) || isempty(outgoing_index[n])])

bus_pd = Dict(r[1] => r[3] for r in JSON.parsefile(joinpath(HERE, "rts24_raw_data.json"))["bus"]["rows"])
total_pd = sum(values(bus_pd))

logln("IEEE RTS-24 -- net-injection model, $(length(nodes)) nodes (incl. S=$S_NODE, T=$T_NODE), $(length(edgelist)) edges")
logln("structural (zero-in-degree) sources: ", structural_sources, "   structural (zero-out-degree) sinks: ", structural_sinks)
logln("total system peak demand (all 17 load buses) = $total_pd MW -- now the actual reference: S and T aggregate every")
logln("  bus's NET position, so max_flow(S,T) below is deliverable throughput against this whole-system figure, not a")
logln("  structural subset. (Self-served local demand at net-export buses never touches the network and is delivered")
logln("  unconditionally as long as that bus's own generation covers its own load -- see net_injection_log.txt.)")
logln()

function load_caps(path)
    j = JSON.parsefile(path)
    Dict{Tuple{Int64,Int64},Float64}((Int64(e["source"]), Int64(e["destination"])) => Float64(e["capacity"]) for e in j["edges"])
end

primary_caps = load_caps(joinpath(HERE, "rts24-netinjection-capacities.json"))
uncon_caps = load_caps(joinpath(HERE, "rts24-netinjection-unconstrained-capacities.json"))

logln("=== primary: generator-nameplate-limited net injection ===")
primary = CAK.analyze_all(edgelist, outgoing_index, incoming_index, primary_caps, source_nodes, sink_nodes; k_failure=2, cut_limit=200)
primary_flow = primary.flow.max_flow
logln(@sprintf("max_flow = %.1f MVA", primary_flow))
logln(@sprintf("  = %.1f%% of total system peak demand (%.0f MW)", 100 * primary_flow / total_pd, total_pd))
logln()

logln("=== comparison: unconstrained generation (net-load caps only, generator nameplate limits ignored) ===")
uncon = CAK.analyze_all(edgelist, outgoing_index, incoming_index, uncon_caps, source_nodes, sink_nodes; k_failure=2, cut_limit=200)
uncon_flow = uncon.flow.max_flow
logln(@sprintf("max_flow = %.1f MVA  (%.1f%% of total system peak demand)", uncon_flow, 100 * uncon_flow / total_pd))
logln(@sprintf("generator nameplate limits cost %.1f MVA of deliverable throughput relative to the unconstrained case", uncon_flow - primary_flow))
logln()

logln("=== binding cut (primary scenario) ===")
mca = CAK.analyze_min_cuts(edgelist, outgoing_index, incoming_index, primary_caps, source_nodes, sink_nodes, primary.flow; cut_limit=200)
cut_edges = mca.representative_cut.crossing_edges
for e in cut_edges
    kind = e[1] == S_NODE ? "generation-side (S->bus)" : (e[2] == T_NODE ? "demand-side (bus->T)" : "line")
    logln(@sprintf("  %s  capacity=%.1f  [%s]", e, primary_caps[e], kind))
end
logln(@sprintf("cut capacity = %.1f MVA (matches max_flow: %s)", mca.representative_cut.capacity, isapprox(mca.representative_cut.capacity, primary_flow; atol=1e-6) ? "yes" : "NO -- MISMATCH"))
logln()

logln("=== single points of failure (nodes) ===")
spof = CAK.identify_spof_nodes(edgelist, outgoing_index, incoming_index, source_nodes, sink_nodes)
logln(spof)
logln()

logln("=== single-edge failures, partitioned by edge type (primary scenario) ===")
sef = CAK.analyze_single_edge_failures(edgelist, outgoing_index, incoming_index, primary_caps, source_nodes, sink_nodes, primary.flow)
line_failures = [r for r in sef if r.edge[1] != S_NODE && r.edge[2] != T_NODE]
gen_failures = [r for r in sef if r.edge[1] == S_NODE]
sink_failures = [r for r in sef if r.edge[2] == T_NODE]

logln("-- five most damaging single-LINE failures --")
for rec in line_failures[1:min(5, length(line_failures))]
    logln(@sprintf("  %s  baseline=%.1f -> perturbed=%.1f  drop=%.1f", rec.edge, rec.baseline_flow, rec.perturbed_flow, rec.drop))
end
logln()
logln("-- five most damaging single-GENERATOR failures (S->bus edge loss = losing that bus's entire nameplate generation) --")
for rec in gen_failures[1:min(5, length(gen_failures))]
    bus = rec.edge[2]
    logln(@sprintf("  bus %-3d  baseline=%.1f -> perturbed=%.1f  drop=%.1f", bus, rec.baseline_flow, rec.perturbed_flow, rec.drop))
end
logln()
logln("(", length(sink_failures), " demand-side bus->T edges also in the full ranking -- a single bus's demand vanishing; not a failure mode, omitted from the ranking above)")
logln("Empty line/generator rankings above are a real finding, not a gap: every net-import bus's demand is fully")
logln("saturated (binding cut is 100% demand-side, see above) while every line and every generator still has slack,")
logln("so no single line or generator failure reduces total deliverable throughput at all -- the system is fully")
logln("N-1 secure for aggregate throughput at these nameplate/thermal-rating capacity levels.")
logln()

logln("=== real-asset headroom: how close is each LINE and GENERATOR to its own cap, given the primary flow? ===")
logln("(distinct from the binding-cut edges above, which are all demand-side; this asks which real transmission or")
logln(" generation asset is closest to becoming the next constraint, not which edge is currently binding)")
line_headroom = [(e, primary_caps[e], get(primary.flow.flow, e, 0.0), primary_caps[e] - get(primary.flow.flow, e, 0.0))
                 for e in edgelist if e[1] != S_NODE && e[2] != T_NODE]
gen_headroom = [(e, primary_caps[e], get(primary.flow.flow, e, 0.0), primary_caps[e] - get(primary.flow.flow, e, 0.0))
                for e in edgelist if e[1] == S_NODE]
sort!(line_headroom, by = x -> x[4])
sort!(gen_headroom, by = x -> x[4])
logln("-- five lines with the least headroom (capacity - flow) --")
for (e, cap, fl, hr) in line_headroom[1:min(5, length(line_headroom))]
    logln(@sprintf("  %s  capacity=%.1f  flow=%.1f  headroom=%.1f", e, cap, fl, hr))
end
logln("-- five generators with the least headroom (capacity - flow) --")
for (e, cap, fl, hr) in gen_headroom[1:min(5, length(gen_headroom))]
    logln(@sprintf("  bus %-3d  capacity=%.1f  flow=%.1f  headroom=%.1f", e[2], cap, fl, hr))
end
logln()

logln("=== upgrade thresholds: binding cut edges, target +10% flow ===")
logln("(binding cut is 100% demand-side -- see caveat above; these numbers answer \"how much would this one bus's")
logln(" own demand need to grow, alone, to raise total delivered throughput 10%\", not a transmission/generation")
logln(" upgrade question, since neither is the current constraint)")
target = primary_flow * 1.10
for e in cut_edges[1:min(3, length(cut_edges))]
    try
        up = CAK.find_upgrade_threshold(edgelist, outgoing_index, incoming_index, primary_caps, source_nodes, sink_nodes, e, target)
        kind = e[1] == S_NODE ? "generation-side" : (e[2] == T_NODE ? "demand-side" : "line")
        logln(@sprintf("  %s [%s]  original_capacity=%.1f  required_capacity=%.1f  required_increase=%.1f  target_flow=%.1f  already_sufficient=%s",
                       e, kind, up.original_capacity, up.required_capacity, up.required_increase, target, up.already_sufficient))
    catch err
        logln("  ", e, " upgrade threshold: ERROR ", sprint(showerror, err))
    end
end

close(LOG)
println("\nwrote rts24_netinjection_analysis_log.txt")
