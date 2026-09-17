# Flow validation, items 3-10 of the requirements document (items 1-2 are in
# run_flow_validation.jl): min-cut structure, saturated edges, SPOF (brute
# force), failure-impact ranking, degradation/upgrade thresholds (bisection),
# path-disjoint redundancy (Menger, via the oracle), node capacities
# (node-split vs oracle on the split graph), multi-terminal (already exercised
# by every network in the base run — noted, not re-tested here).
#
# Brute force is exhaustive where the candidate set is small (documented per
# check); sampled, with the sample explicitly logged, where it would not
# finish in reasonable time on the larger corpus networks (ergo-proxy:
# 800/6607, the two largest drone designs).
#
# USAGE: julia -t 1 "validation/flow/run_flow_validation_extended.jl"

const REPO = raw"C:\Development\Info_Prop_Framework_Project\Info_Prop_Framework_Project"
using Pkg; Pkg.activate(REPO)
include(joinpath(REPO, "InfoPropFrmwrk", "src", "Algorithms", "InfoPropFramework.jl")); using .InfoPropFramework
const CAK = InfoPropFramework.CapacityAnalysisKit
using Graphs, GraphsFlows
using JSON, Printf, Dates, Random

const OUTDIR = joinpath(REPO, "validation", "flow")
const CAPDIR = joinpath(OUTDIR, "flow_corpus_capacities")
const LOG = open(joinpath(OUTDIR, "flow_validation_extended_log.txt"), "w")
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
const NODE_CAP_SUBSET = Set(["water", "KarlNetwork", "grid-graph-5x5", "psplib-j301_1"])

summary_rows = String[]
failures = String[]
const RNG = MersenneTwister(20260830)

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

# --- independent oracle max-flow, arbitrary edge subset excluded, arbitrary
#     node subset excluded (for brute-force node/edge removal), arbitrary
#     per-edge capacity override (for threshold bisection). All built fresh
#     from Graphs.jl + GraphsFlows.jl, never touching FlowModule.jl.
function oracle_flow(nodes, edgelist, edge_caps, source_nodes, sink_nodes;
                      exclude_nodes=Set{Int64}(), exclude_edges=Set{Tuple{Int64,Int64}}(),
                      cap_override=nothing)
    keep_nodes = [n for n in nodes if !(n in exclude_nodes)]
    idx = Dict(n => i for (i, n) in enumerate(keep_nodes))
    srcs = [s for s in source_nodes if haskey(idx, s)]
    snks = [t for t in sink_nodes if haskey(idx, t)]
    (isempty(srcs) || isempty(snks)) && return 0.0
    g = Graphs.SimpleDiGraph(length(keep_nodes) + 2)
    s = length(keep_nodes) + 1; t = length(keep_nodes) + 2
    cap = zeros(Float64, length(keep_nodes) + 2, length(keep_nodes) + 2)
    BIG = 1e12
    for (u, v) in edgelist
        (u in exclude_nodes || v in exclude_nodes) && continue
        (u, v) in exclude_edges && continue
        c = cap_override !== nothing && haskey(cap_override, (u, v)) ? cap_override[(u, v)] : edge_caps[(u, v)]
        c <= 0 && continue
        Graphs.add_edge!(g, idx[u], idx[v])
        cap[idx[u], idx[v]] += c
    end
    for sn in srcs; Graphs.add_edge!(g, s, idx[sn]); cap[s, idx[sn]] = BIG; end
    for tn in snks; Graphs.add_edge!(g, idx[tn], t); cap[idx[tn], t] = BIG; end
    f, _ = GraphsFlows.maximum_flow(g, s, t, cap)
    Float64(f)
end

approx(a, b; tol=1e-6) = abs(a - b) <= tol * max(1.0, abs(a), abs(b))

function check_network(name)
    folder, fname = NETWORKS[name]
    edges_path = joinpath(REPO, "dag_ntwrk_files", folder, fname)
    edgelist, outgoing_index, incoming_index, source_nodes_set = read_graph_to_dict(edges_path)
    nodes = sort!(collect(union(Set(u for (u,_) in edgelist), Set(v for (_,v) in edgelist))))
    source_nodes = sort!(collect(source_nodes_set))
    sink_nodes = sort!([n for n in nodes if !haskey(outgoing_index, n) || isempty(outgoing_index[n])])
    edge_caps, node_caps = read_capacities(name)
    large = length(edgelist) > 1500

    logln("== $name == ($(length(nodes))n/$(length(edgelist))e, large=$large)")
    ok_all = true

    baseline = CAK.solve_max_flow_dinic(edgelist, outgoing_index, incoming_index, edge_caps, source_nodes, sink_nodes)

    # --- item 3: min-cut structure --------------------------------------
    mca = CAK.analyze_min_cuts(edgelist, outgoing_index, incoming_index, edge_caps, source_nodes, sink_nodes, baseline; cut_limit=200)
    rep_ok = approx(mca.representative_cut.capacity, baseline.max_flow)
    disc_ok = approx(oracle_flow(nodes, edgelist, edge_caps, source_nodes, sink_nodes;
                                  exclude_edges=Set(mca.representative_cut.crossing_edges)), 0.0)
    mc_ok = rep_ok && disc_ok
    ok_all &= mc_ok
    mc_ok || push!(failures, "$name/mincut: cap_ok=$rep_ok disconnect_ok=$disc_ok")
    logln("  [3] min-cut: capacity=$(mca.representative_cut.capacity) (=max_flow: $rep_ok), removal disconnects s-t: $disc_ok  -> ", mc_ok ? "PASS" : "FAIL")

    if length(mca.edges_in_some_cut) <= 20
        # exhaustive: every subset of the min-cut candidate edges that
        # disconnects s from t must have capacity >= min_cut_capacity, and at
        # least one such subset (the reported one(s)) must equal it exactly.
        cand = mca.edges_in_some_cut
        best = Inf
        for mask in 0:(1 << length(cand)) - 1
            subset = Set(cand[i] for i in 1:length(cand) if (mask >> (i-1)) & 1 == 1)
            isempty(subset) && continue
            if approx(oracle_flow(nodes, edgelist, edge_caps, source_nodes, sink_nodes; exclude_edges=subset), 0.0)
                cap = sum(edge_caps[e] for e in subset)
                best = min(best, cap)
            end
        end
        exhaustive_ok = approx(best, baseline.max_flow)
        ok_all &= exhaustive_ok
        exhaustive_ok || push!(failures, "$name/mincut-exhaustive: best_disconnecting_capacity=$best vs max_flow=$(baseline.max_flow)")
        logln("  [3b] exhaustive subset enumeration over $(length(cand)) candidate edges: min disconnecting capacity=$best -> ", exhaustive_ok ? "PASS" : "FAIL")
    else
        logln("  [3b] skipped (", length(mca.edges_in_some_cut), " candidate edges > 20)")
    end

    # --- item 3c: E_every/E_some against the enumerated cuts directly ------
    # Added after the MinCutUtilitiesModule.jl t_double_star fix (see FINDINGS.md):
    # the pre-fix bug (edges_in_every_cut computed from the wrong reachability
    # side) was NOT caught by [3]/[3b] above, since those only check the
    # representative cut's capacity/disconnection, never edges_in_every_cut or
    # edges_in_some_cut against ground truth. Only exercised when enumeration is
    # complete (2^|free_zone| <= cut_limit) -- a truncated enumeration's
    # intersection/union is not the true E_every/E_some.
    if mca.enumeration.is_complete
        enumerated_sets = [Set(c.crossing_edges) for c in mca.enumeration.cuts]
        true_every = isempty(enumerated_sets) ? Set{Tuple{Int64,Int64}}() : reduce(intersect, enumerated_sets)
        true_some = isempty(enumerated_sets) ? Set{Tuple{Int64,Int64}}() : reduce(union, enumerated_sets)
        every_ok = Set(mca.edges_in_every_cut) == true_every
        some_ok = Set(mca.edges_in_some_cut) == true_some
        lattice_ok = every_ok && some_ok
        ok_all &= lattice_ok
        lattice_ok || push!(failures, "$name/mincut-lattice: edges_in_every_cut=$(sort(mca.edges_in_every_cut)) vs intersection=$(sort(collect(true_every))); edges_in_some_cut=$(sort(mca.edges_in_some_cut)) vs union=$(sort(collect(true_some)))")
        logln("  [3c] E_every == ∩(enumerated cuts) and E_some == ∪(enumerated cuts), $(length(enumerated_sets)) cuts enumerated -> ", lattice_ok ? "PASS" : "FAIL")
    else
        logln("  [3c] skipped (enumeration truncated, free_zone_size=$(mca.enumeration.free_zone_size) > cut_limit)")
    end

    # --- item 4: saturated edges -----------------------------------------
    sat_ok = all(approx(baseline.flow[e], edge_caps[e]) for e in baseline.saturated_edges if haskey(edge_caps, e))
    ok_all &= sat_ok
    sat_ok || push!(failures, "$name/saturated: a reported saturated edge does not carry flow=capacity")
    logln("  [4] saturated edges: $(length(baseline.saturated_edges)) reported, flow=capacity for all: $sat_ok")

    # --- item 5: SPOF nodes, brute force ----------------------------------
    reported_spof = Set(CAK.identify_spof_nodes(edgelist, outgoing_index, incoming_index, source_nodes, sink_nodes))
    st_nodes = setdiff(nodes, Set(source_nodes), Set(sink_nodes))
    sample = large ? Random.shuffle(RNG, collect(st_nodes))[1:min(40, length(st_nodes))] : collect(st_nodes)
    spof_ok = true
    for n in sample
        f = oracle_flow(nodes, edgelist, edge_caps, source_nodes, sink_nodes; exclude_nodes=Set([n]))
        is_spof_oracle = approx(f, 0.0)
        is_spof_reported = n in reported_spof
        if is_spof_oracle != is_spof_reported
            spof_ok = false
            push!(failures, "$name/spof: node $n oracle_disconnects=$is_spof_oracle reported=$is_spof_reported")
        end
    end
    ok_all &= spof_ok
    logln("  [5] SPOF nodes: $(length(reported_spof)) reported, brute-force checked $(length(sample))/$(length(st_nodes)) candidates", large ? " (sampled)" : " (exhaustive)", " -> ", spof_ok ? "PASS" : "FAIL")

    # --- item 6: single-edge failure impact ranking -----------------------
    sef = CAK.analyze_single_edge_failures(edgelist, outgoing_index, incoming_index, edge_caps, source_nodes, sink_nodes, baseline)
    sef_sample = large ? sef[1:min(15, length(sef))] : sef
    sef_ok = true
    for rec in sef_sample
        f = oracle_flow(nodes, edgelist, edge_caps, source_nodes, sink_nodes; exclude_edges=Set([rec.edge]))
        if !approx(f, rec.perturbed_flow)
            sef_ok = false
            push!(failures, "$name/single-edge-failure: edge $(rec.edge) oracle=$f reported=$(rec.perturbed_flow)")
        end
    end
    ok_all &= sef_ok
    logln("  [6] single-edge failure impact: $(length(sef)) candidates (in some min-cut), checked $(length(sef_sample)) against oracle -> ", sef_ok ? "PASS" : "FAIL")

    # --- item 7: degradation threshold, bisection --------------------------
    finite_edges = [e for e in edgelist if isfinite(edge_caps[e])]
    thr_sample = finite_edges[1:min(3, length(finite_edges))]
    target_flow = 0.9 * baseline.max_flow
    thr_ok = true
    for e in thr_sample
        reported = CAK.find_degradation_threshold(edgelist, outgoing_index, incoming_index, edge_caps, source_nodes, sink_nodes, e, target_flow)
        # independent bisection on the SAME edge, via the oracle, not the framework's solver
        lo, hi = 0.0, edge_caps[e]
        f_hi = oracle_flow(nodes, edgelist, edge_caps, source_nodes, sink_nodes)
        if f_hi < target_flow
            # can't reach target even at full capacity — threshold is "not achievable"
            bisect_ok = !reported.target_achievable
        else
            for _ in 1:40
                mid = (lo + hi) / 2
                f = oracle_flow(nodes, edgelist, edge_caps, source_nodes, sink_nodes; cap_override=Dict(e => mid))
                if f >= target_flow
                    hi = mid
                else
                    lo = mid
                end
            end
            bisect_ok = abs(hi - reported.threshold_capacity) <= 1e-3 * max(1.0, edge_caps[e])
        end
        thr_ok &= bisect_ok
        bisect_ok || push!(failures, "$name/threshold: edge $e reported=$(reported.threshold_capacity) bisected=$hi")
    end
    ok_all &= thr_ok
    logln("  [7] degradation thresholds: checked $(length(thr_sample))/$(length(finite_edges)) edges by independent bisection -> ", thr_ok ? "PASS" : "FAIL")

    # --- item 8: path-disjoint redundancy (Menger), edge connectivity ------
    ec = CAK.edge_connectivity(edgelist, outgoing_index, incoming_index, source_nodes, sink_nodes)
    unit_caps = Dict{Tuple{Int64,Int64},Float64}(e => 1.0 for e in edgelist)
    ec_oracle = oracle_flow(nodes, edgelist, unit_caps, [ec.achieving_source], [ec.achieving_sink])
    ec_ok = approx(ec_oracle, Float64(ec.lambda))
    ok_all &= ec_ok
    ec_ok || push!(failures, "$name/edge_connectivity: reported lambda=$(ec.lambda) oracle(unit-cap max-flow)=$ec_oracle")
    logln("  [8] edge connectivity (Menger, edge-disjoint paths): lambda=$(ec.lambda) between $(ec.achieving_source)->$(ec.achieving_sink), oracle unit-capacity max-flow=$ec_oracle -> ", ec_ok ? "PASS" : "FAIL")

    # --- item 9: node capacities (subset only) ------------------------------
    if node_caps !== nothing
        ncf = CAK.solve_node_capacitated_flow(edgelist, outgoing_index, incoming_index, edge_caps, source_nodes, sink_nodes, node_caps)
        nsg = CAK.build_node_split_graph(edgelist, outgoing_index, incoming_index, edge_caps, source_nodes, sink_nodes, node_caps)
        split_nodes = sort!(collect(union(Set(u for (u,_) in nsg.split_edgelist), Set(v for (_,v) in nsg.split_edgelist))))
        ns_oracle = oracle_flow(split_nodes, nsg.split_edgelist, nsg.split_capacities, nsg.split_sources, nsg.split_sinks)
        nc_ok = approx(ns_oracle, ncf.max_flow)
        ok_all &= nc_ok
        nc_ok || push!(failures, "$name/node_capacitated: reported=$(ncf.max_flow) oracle_on_split_graph=$ns_oracle")
        logln("  [9] node-capacitated flow: reported=$(ncf.max_flow), oracle on the same node-split graph=$ns_oracle -> ", nc_ok ? "PASS" : "FAIL")
    else
        logln("  [9] node-capacitated flow: not in this network's generated capacities (not in NODE_CAP_SUBSET) — skipped")
    end

    # --- item 10: multi-source/multi-sink -----------------------------------
    # Already exercised by every network above: the base run_flow_validation.jl
    # pass (three solvers + this file's own `oracle_flow`) already builds an
    # independent super-source/super-sink construction on every network in
    # this corpus, most of which have multiple sources and/or sinks (water:
    # 8/8, highland_to_lowland: 78/27, drone designs: 8-16 sources). Agreement
    # there already IS the multi-terminal check; not re-run here.
    logln("  [10] multi-source/multi-sink: exercised by every check above (", length(source_nodes), " sources, ", length(sink_nodes), " sinks) — see run_flow_validation.jl")

    push!(summary_rows, "$name,mincut_structure,oracle,$(mc_ok ? "PASS" : "FAIL"),")
    push!(summary_rows, "$name,saturated_edges,self-consistency,$(sat_ok ? "PASS" : "FAIL"),")
    push!(summary_rows, "$name,spof_nodes,oracle-bruteforce,$(spof_ok ? "PASS" : "FAIL"),")
    push!(summary_rows, "$name,single_edge_failures,oracle,$(sef_ok ? "PASS" : "FAIL"),")
    push!(summary_rows, "$name,degradation_threshold,oracle-bisection,$(thr_ok ? "PASS" : "FAIL"),")
    push!(summary_rows, "$name,edge_connectivity_menger,oracle,$(ec_ok ? "PASS" : "FAIL"),")
    if node_caps !== nothing
        push!(summary_rows, "$name,node_capacitated_flow,oracle-on-split-graph,$(nc_ok ? "PASS" : "FAIL"),")
    end

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

open(joinpath(OUTDIR, "flow_validation_extended_summary.csv"), "w") do io
    println(io, "network,check,oracle,result,notes")
    for row in summary_rows
        println(io, row)
    end
end

logln()
if isempty(failures)
    logln("FLOW VALIDATION (items 3-10): ALL PASS")
else
    logln("FLOW VALIDATION (items 3-10): ", length(failures), " FAILURE(S):")
    for f in failures
        logln("  ", f)
    end
end
logln("run: ", Dates.now())
close(LOG)
