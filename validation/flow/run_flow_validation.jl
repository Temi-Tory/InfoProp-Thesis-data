# Flow (CapacityAnalysisKit) validation: three-solver agreement (Dinic,
# Edmonds-Karp, push-relabel) plus an external oracle (GraphsFlows.jl) on the
# max-flow value, and post-solve invariants (capacity feasibility, flow
# conservation, max-flow = min-cut), on the corpus in
# validation/flow/flow_corpus_capacities/ (seed/rule: that folder's README).
# Same summary-CSV + full-log shape as validation/cpm_v2/run_float_validation.jl.
# USAGE: julia -t 1 "validation/flow/run_flow_validation.jl"

const REPO = raw"C:\Development\Info_Prop_Framework_Project\Info_Prop_Framework_Project"
using Pkg; Pkg.activate(REPO)
include(joinpath(REPO, "InfoPropFrmwrk", "src", "Algorithms", "InfoPropFramework.jl")); using .InfoPropFramework
const CAK = InfoPropFramework.CapacityAnalysisKit
using Graphs, GraphsFlows
using JSON, Printf, Dates

const OUTDIR = joinpath(REPO, "validation", "flow")
const CAPDIR = joinpath(OUTDIR, "flow_corpus_capacities")
const LOG = open(joinpath(OUTDIR, "flow_validation_log.txt"), "w")
logln(args...) = (println(LOG, args...); println(args...))

const NETWORKS = Dict(
    "water" => ("water", "water.EDGES"),
    "KarlNetwork" => ("KarlNetwork", "KarlNetwork.EDGES"),
    "grid-graph-5x5" => ("grid-graph-5x5", "grid-graph-5x5.EDGES"),
    "metro_directed_dag_for_ipm" => ("metro_directed_dag_for_ipm", "metro_directed_dag_for_ipm.EDGES"),
    "ergo-proxy-dag-network" => ("ergo-proxy-dag-network", "ergo-proxy-dag-network.EDGES"),
    "drone-network-fw-reliant-centralized" => ("drone-network-fw-reliant-centralized", "drone-network-fw-reliant-centralized.EDGES"),
    "drone-network-vtol-dense-decentralized" => ("drone-network-vtol-dense-decentralized", "drone-network-vtol-dense-decentralized.EDGES"),
    "drone-network-concentrated-minimal" => ("drone-network-concentrated-minimal", "drone-network-concentrated-minimal.EDGES"),
    "continental_medical_network" => ("continental_medical_network", "continental_medical_network.EDGES"),
    "glasgow_to_shetland_extreme" => ("glasgow_to_shetland_extreme", "glasgow_to_shetland_extreme.EDGES"),
    "highland_to_lowland_full_network" => ("highland_to_lowland_full_network", "highland_to_lowland_full_network.EDGES"),
    "psplib-j301_1" => ("psplib-j301_1", "j301_1.EDGES"),
)

summary_rows = String[]
failures = String[]

function read_capacities(name)
    j = JSON.parsefile(joinpath(CAPDIR, "$name-capacities.json"))
    edge_caps = Dict{Tuple{Int64,Int64},Float64}(
        (Int64(e["source"]), Int64(e["destination"])) => Float64(e["capacity"]) for e in j["edges"]
    )
    node_caps = haskey(j, "nodes") ?
        Dict{Int64,Float64}(Int64(n["node"]) => Float64(n["capacity"]) for n in j["nodes"]) :
        nothing
    (edge_caps, node_caps)
end

# --- external oracle: GraphsFlows.jl on a plain Graphs.jl DiGraph, completely
#     independent of this framework's own FlowModule.jl implementation.
function oracle_max_flow(nodes, edgelist, edge_caps, source_nodes, sink_nodes)
    idx = Dict(n => i for (i, n) in enumerate(nodes))
    g = Graphs.SimpleDiGraph(length(nodes))
    cap = zeros(Float64, length(nodes), length(nodes))
    for (u, v) in edgelist
        Graphs.add_edge!(g, idx[u], idx[v])
        cap[idx[u], idx[v]] = edge_caps[(u, v)]
    end
    # multi-source/multi-sink -> super-source/super-sink, same construction
    # the server itself uses (CapacityHandlers.jl), built independently here
    s = Graphs.add_vertex!(g) ? Graphs.nv(g) : error("could not add super-source")
    t = Graphs.add_vertex!(g) ? Graphs.nv(g) : error("could not add super-sink")
    cap2 = zeros(Float64, Graphs.nv(g), Graphs.nv(g))
    cap2[1:size(cap,1), 1:size(cap,2)] .= cap
    BIG = 1e12
    for sn in source_nodes
        Graphs.add_edge!(g, s, idx[sn]); cap2[s, idx[sn]] = BIG
    end
    for tn in sink_nodes
        Graphs.add_edge!(g, idx[tn], t); cap2[idx[tn], t] = BIG
    end
    f, F = GraphsFlows.maximum_flow(g, s, t, cap2)
    Float64(f)
end

function check_network(name)
    folder, fname = NETWORKS[name]
    edges_path = joinpath(REPO, "dag_ntwrk_files", folder, fname)
    edgelist, outgoing_index, incoming_index, source_nodes_set = read_graph_to_dict(edges_path)
    nodes = sort!(collect(union(Set(u for (u,_) in edgelist), Set(v for (_,v) in edgelist))))
    source_nodes = sort!(collect(source_nodes_set))
    sink_nodes = sort!([n for n in nodes if !haskey(outgoing_index, n) || isempty(outgoing_index[n])])

    edge_caps, node_caps = read_capacities(name)
    logln("== $name == ($(length(nodes)) nodes, $(length(edgelist)) edges, $(length(source_nodes)) sources, $(length(sink_nodes)) sinks)")

    t0 = time()
    oracle_val = oracle_max_flow(nodes, edgelist, edge_caps, source_nodes, sink_nodes)
    oracle_t = time() - t0

    ok_all = true
    results = Dict{Symbol,CAK.FlowSolveResult}()
    for (tag, solver) in ((:dinic, CAK.solve_max_flow_dinic),
                          (:edmonds_karp, CAK.solve_max_flow_edmonds_karp),
                          (:push_relabel, CAK.solve_max_flow_push_relabel))
        t0 = time()
        r = solver(edgelist, outgoing_index, incoming_index, edge_caps, source_nodes, sink_nodes)
        el = time() - t0
        results[tag] = r

        diff = abs(r.max_flow - oracle_val)
        agree = diff <= 1e-6 * max(1.0, oracle_val)
        ok_all &= agree
        agree || push!(failures, "$name/$tag: max_flow=$(r.max_flow) vs oracle=$oracle_val diff=$diff")

        # post-solve invariants, independent of the module's own `validate` kwarg
        cap_ok = all(r.flow[e] <= edge_caps[e] + 1e-6 && r.flow[e] >= -1e-6 for e in keys(edge_caps) if haskey(r.flow, e))
        cons_ok = all(
            abs(sum(get(r.flow, (u, n), 0.0) for u in get(incoming_index, n, Set{Int64}())) -
                sum(get(r.flow, (n, v), 0.0) for v in get(outgoing_index, n, Set{Int64}()))) <= 1e-6
            for n in nodes if !(n in source_nodes) && !(n in sink_nodes)
        )
        mc_ok = abs(r.max_flow - r.mincut_capacity) <= 1e-6 * max(1.0, r.max_flow)
        inv_ok = cap_ok && cons_ok && mc_ok
        ok_all &= inv_ok
        inv_ok || push!(failures, "$name/$tag: invariant failure cap_ok=$cap_ok cons_ok=$cons_ok mc_ok=$mc_ok")

        logln(@sprintf("  %-14s max_flow=%.6g  oracle_diff=%.2e  %s  invariants=%s  %.4fs",
                       tag, r.max_flow, diff, agree ? "AGREE" : "!!MISMATCH!!",
                       inv_ok ? "ok" : "BROKEN", el))
        push!(summary_rows, "$name,$tag,oracle=GraphsFlows,$(agree ? "PASS" : "FAIL"),$(@sprintf("%.6f", el))")
    end
    logln(@sprintf("  oracle (GraphsFlows) max_flow=%.6g  %.4fs", oracle_val, oracle_t))
    push!(summary_rows, "$name,oracle,external,$(oracle_val),$(@sprintf("%.6f", oracle_t))")

    # cross-solver agreement (independent of the oracle)
    vals = [r.max_flow for r in values(results)]
    cross_ok = maximum(vals) - minimum(vals) <= 1e-6 * max(1.0, maximum(vals))
    ok_all &= cross_ok
    cross_ok || push!(failures, "$name: solver disagreement $vals")
    logln("  three-solver agreement: ", cross_ok ? "PASS" : "FAIL (!!)")

    return ok_all
end

all_ok = true
for name in sort(collect(keys(NETWORKS)))
    try
        global all_ok &= check_network(name)
    catch e
        logln("== $name == ERROR: ", sprint(showerror, e))
        push!(failures, "$name: EXCEPTION $(sprint(showerror, e))")
        global all_ok = false
    end
end

open(joinpath(OUTDIR, "flow_validation_summary.csv"), "w") do io
    println(io, "network,output,oracle,agreement,seconds")
    for row in summary_rows
        println(io, row)
    end
end

logln()
if isempty(failures)
    logln("FLOW VALIDATION: ALL PASS")
else
    logln("FLOW VALIDATION: ", length(failures), " FAILURE(S):")
    for f in failures
        logln("  ", f)
    end
end
logln("run: ", Dates.now())
close(LOG)
