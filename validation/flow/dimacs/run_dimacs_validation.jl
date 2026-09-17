# Three-solver agreement + oracle (GraphsFlows.jl) + warm timing on the
# DAG-respecting genrmf-style DIMACS instances (generate_genrmf_dag.py).
# Same oracle construction as validation/flow/run_flow_validation.jl.
# USAGE: julia --project=InfoPropFrmwrk "validation/flow/dimacs/run_dimacs_validation.jl"

const REPO = raw"C:\Development\Info_Prop_Framework_Project\Info_Prop_Framework_Project"
using Pkg; Pkg.activate(REPO)
include(joinpath(REPO, "InfoPropFrmwrk", "src", "Algorithms", "InfoPropFramework.jl")); using .InfoPropFramework
const CAK = InfoPropFramework.CapacityAnalysisKit
using Graphs, GraphsFlows
using JSON, Printf, Dates

const HERE = joinpath(REPO, "validation", "flow", "dimacs")
const LOG = open(joinpath(HERE, "dimacs_validation_log.txt"), "w")
logln(args...) = (println(LOG, args...); println(args...))

manifest = JSON.parsefile(joinpath(HERE, "manifest.json"))["instances"]

function oracle_max_flow(nodes, edgelist, edge_caps, source_nodes, sink_nodes)
    idx = Dict(n => i for (i, n) in enumerate(nodes))
    g = Graphs.SimpleDiGraph(length(nodes))
    cap = zeros(Float64, length(nodes), length(nodes))
    for (u, v) in edgelist
        Graphs.add_edge!(g, idx[u], idx[v])
        cap[idx[u], idx[v]] += edge_caps[(u, v)]
    end
    s = idx[source_nodes[1]]; t = idx[sink_nodes[1]]
    f, _ = GraphsFlows.maximum_flow(g, s, t, cap)
    Float64(f)
end

timing_rows = String[]
summary_rows = String[]
failures = String[]

for inst in manifest
    name = inst["name"]
    edges_path = joinpath(HERE, "$name.EDGES")
    cap_path = joinpath(HERE, "$name-capacities.json")
    edgelist, outgoing_index, incoming_index, source_nodes_set = read_graph_to_dict(edges_path)
    nodes = sort!(collect(union(Set(u for (u,_) in edgelist), Set(v for (_,v) in edgelist))))
    source = Int64(inst["source"]); sink = Int64(inst["sink"])
    source_nodes = [source]; sink_nodes = [sink]

    j = JSON.parsefile(cap_path)
    edge_caps = Dict{Tuple{Int64,Int64},Float64}((Int64(e["source"]), Int64(e["destination"])) => Float64(e["capacity"]) for e in j["edges"])

    logln("== $name == ($(length(nodes)) nodes, $(length(edgelist)) edges)")

    # oracle first (also serves as ground truth for three-solver agreement)
    t0 = time(); oracle_val = oracle_max_flow(nodes, edgelist, edge_caps, source_nodes, sink_nodes); oracle_t = time() - t0
    logln(@sprintf("  oracle (GraphsFlows) max_flow=%.6g  %.4fs", oracle_val, oracle_t))

    large = length(edgelist) > 50_000
    solvers = large ?
        ((:dinic, CAK.solve_max_flow_dinic), (:push_relabel, CAK.solve_max_flow_push_relabel)) :
        ((:dinic, CAK.solve_max_flow_dinic), (:edmonds_karp, CAK.solve_max_flow_edmonds_karp), (:push_relabel, CAK.solve_max_flow_push_relabel))
    large && logln("  (edmonds_karp skipped on this instance — $(length(edgelist)) edges, O(VE^2) worst case; documented, not run)")

    for (tag, solver) in solvers
        # warm-up call discarded, second call timed (case_studies.jl convention)
        r1 = solver(edgelist, outgoing_index, incoming_index, edge_caps, source_nodes, sink_nodes)
        t0 = time()
        r2 = solver(edgelist, outgoing_index, incoming_index, edge_caps, source_nodes, sink_nodes)
        el = time() - t0
        agree = abs(r2.max_flow - oracle_val) <= 1e-6 * max(1.0, oracle_val)
        agree || push!(failures, "$name/$tag: max_flow=$(r2.max_flow) vs oracle=$oracle_val")
        logln(@sprintf("  %-14s max_flow=%.6g  %s  warm_time=%.4fs", tag, r2.max_flow, agree ? "AGREE" : "!!MISMATCH!!", el))
        push!(summary_rows, "$name,$tag,oracle=GraphsFlows,$(agree ? "PASS" : "FAIL"),$(@sprintf("%.6f", el))")
        push!(timing_rows, "$name,$(length(nodes)),$(length(edgelist)),$tag,$(@sprintf("%.6f", el))")
    end
    push!(timing_rows, "$name,$(length(nodes)),$(length(edgelist)),oracle_graphsflows,$(@sprintf("%.6f", oracle_t))")
end

open(joinpath(HERE, "dimacs_validation_summary.csv"), "w") do io
    println(io, "network,output,oracle,agreement,seconds")
    for row in summary_rows; println(io, row); end
end
open(joinpath(HERE, "timings.csv"), "w") do io
    println(io, "network,nodes,edges,solver,warm_seconds")
    for row in timing_rows; println(io, row); end
end

logln()
logln(isempty(failures) ? "DIMACS VALIDATION: ALL PASS" : "DIMACS VALIDATION: $(length(failures)) FAILURE(S): $(failures)")
logln("run: ", Dates.now())
close(LOG)
