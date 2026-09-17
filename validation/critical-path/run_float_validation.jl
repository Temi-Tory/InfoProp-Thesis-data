# CriticalPathV2 Float64 validation: every mode on every network is checked against the
# independent path-enumeration oracle where enumeration is affordable, and against
# soundness invariants + random path sampling where it is not. Persists a full log and
# a summary CSV next to this script.
# USAGE: julia -t 1 "validation/cpm_v2/run_float_validation.jl"

const REPO = raw"c:\Users\ohian\OneDrive - University of Strathclyde\Documents\Programmming Files\Julia Files\InformationPropagation\Info_Prop_Framework_Project"
using Pkg; Pkg.activate(REPO)
include(joinpath(REPO, "InfoPropFrmwrk", "src", "Algorithms", "InfoPropFramework.jl")); using .InfoPropFramework
include(joinpath(REPO, "InfoPropFrmwrk", "src", "Algorithms", "CriticalPathV2", "CriticalPathV2Module.jl")); using .CriticalPathV2Module
include(joinpath(REPO, "validation", "cpm_v2", "oracle.jl")); using .CPMOracle
using JSON, Printf, Random, Dates

const OUTDIR = joinpath(REPO, "validation", "cpm_v2")
const LOG = open(joinpath(OUTDIR, "float_validation_log.txt"), "w")
logln(args...) = (println(LOG, args...); println(args...))

const ATOL = 1e-9
const PATH_CAP = 300_000
failures = String[]
summary_rows = String[]

approx_dict(a::Dict{Int64,Float64}, b::Dict{Int64,Float64}) = begin
    keys(a) == keys(b) || return (false, Inf)
    md = 0.0
    for (k, v) in a
        md = max(md, abs(v - b[k]))
    end
    (md <= 1e-6 * max(1.0, maximum(abs, values(a))), md)
end

scaling_inputs(d, w) = begin
    maxd = isempty(d) ? 1.0 : maximum(values(d))
    sd = Dict{Int64,Float64}(k => 1.0 + v / max(maxd, 1e-12) for (k, v) in d)
    maxw = isempty(w) ? 0.0 : maximum(values(w))
    sw = maxw > 0 ? Dict{Tuple{Int64,Int64},Float64}(k => 1.0 + v / maxw for (k, v) in w) :
                    Dict{Tuple{Int64,Int64},Float64}()
    (sd, sw)
end

function check_path_mode(name, tag, res, P_o, through_o, margin_o, critical_o)
    ok = true
    if !isapprox(res.project_value, P_o; atol = ATOL, rtol = 1e-9)
        ok = false; push!(failures, "$name/$tag: project $(res.project_value) vs oracle $P_o")
    end
    okt, mdt = approx_dict(res.through, through_o)
    okm, mdm = approx_dict(res.margin, margin_o)
    okc = res.critical == critical_o
    okt || push!(failures, "$name/$tag: through maxdiff $mdt")
    okm || push!(failures, "$name/$tag: margin maxdiff $mdm")
    okc || push!(failures, "$name/$tag: critical $(res.critical) vs $(critical_o)")
    allok = ok && okt && okm && okc
    logln(@sprintf("  %-14s ORACLE %-4s  P=%.6g  through_maxdiff=%.3g margin_maxdiff=%.3g critical=%s",
                   tag, allok ? "PASS" : "FAIL", res.project_value, mdt, mdm,
                   okc ? "match($(length(res.critical)))" : "MISMATCH"))
    return allok
end

function invariant_checks(name, tag, res, out_adj, sources, d, w, kind, initial)
    ok = true
    for (n, m) in res.margin
        if m < -1e-6
            ok = false; push!(failures, "$name/$tag: negative margin $m at node $n"); break
        end
    end
    isempty(res.critical) && (ok = false; push!(failures, "$name/$tag: empty critical set"))
    rng = MersenneTwister(42)
    worst = kind == :shortest ? Inf : -Inf
    for _ in 1:2000
        v = rand(rng, sources); path = Int64[v]
        while true
            succs = get(out_adj, v, Int64[])
            isempty(succs) && break
            v = rand(rng, succs); push!(path, v)
        end
        pv = kind == :scaling ? CPMOracle.pathvalue_mul(path, d, w, initial) :
                                CPMOracle.pathvalue_add(path, d, w, initial)
        if kind == :shortest
            pv < res.project_value - 1e-6 && (ok = false; push!(failures, "$name/$tag: sampled path beats P"))
            worst = min(worst, pv)
        else
            pv > res.project_value + 1e-6 && (ok = false; push!(failures, "$name/$tag: sampled path beats P"))
            worst = max(worst, pv)
        end
    end
    logln(@sprintf("  %-14s INVARIANTS %-4s  P=%.6g  sampled_extreme=%.6g", tag, ok ? "PASS" : "FAIL",
                   res.project_value, worst))
    return ok
end

function run_network(name, edges_path, durations, delays)
    logln("== $name ==")
    edgelist, outgoing_index, incoming_index, source_nodes = read_graph_to_dict(edges_path)
    iteration_sets, _, _ = find_iteration_sets(edgelist, outgoing_index, incoming_index)
    out_adj, nodes, o_sources, o_sinks = build_adjacency(edgelist)
    npaths = count_paths_to_sinks(out_adj, o_sources)
    logln(@sprintf("  nodes=%d edges=%d sources=%d sinks=%d paths=%.4g", length(nodes),
                   length(edgelist), length(o_sources), length(o_sinks), npaths))
    use_oracle = npaths <= PATH_CAP
    paths = use_oracle ? enumerate_paths(out_adj, o_sources; cap = PATH_CAP) : nothing
    use_oracle = paths !== nothing

    sd, sw = scaling_inputs(durations, delays)
    net_ok = true
    for (tag, mode, dd, ww, kind, init) in (
            ("longest", LONGEST_PATH, durations, delays, :longest, 0.0),
            ("shortest", SHORTEST_PATH, durations, delays, :shortest, 0.0),
            ("scaling", MAX_SCALING, sd, sw, :scaling, 1.0))
        t0 = time()
        res = analyze(iteration_sets, outgoing_index, incoming_index, source_nodes, dd, ww;
                      mode = mode, atol = 1e-6)
        el = time() - t0
        ok = if use_oracle
            P_o, th_o, mg_o, cr_o = oracle_path_mode(paths, dd, ww; kind = kind, initial = init, atol = 1e-6)
            check_path_mode(name, tag, res, P_o, th_o, mg_o, cr_o)
        else
            invariant_checks(name, tag, res, out_adj, o_sources, dd, ww, kind, init)
        end
        net_ok &= ok
        push!(summary_rows, "$name,$tag,$(use_oracle ? "oracle" : "invariants"),$(ok ? "PASS" : "FAIL"),$(@sprintf("%.6f", el))")
    end

    t0 = time()
    acc = accumulation_analysis(iteration_sets, outgoing_index, incoming_index, source_nodes,
                                durations, delays)
    el = time() - t0
    acc_ok = true
    total_o, mult_o = oracle_accumulation(edgelist, out_adj, nodes, durations, delays, acc.target)
    isapprox(acc.total, total_o; rtol = 1e-9) ||
        (acc_ok = false; push!(failures, "$name/accum: total $(acc.total) vs $total_o"))
    acc.multiplicity == mult_o ||
        (acc_ok = false; push!(failures, "$name/accum: multiplicity mismatch"))
    if length(nodes) <= 300
        for v in nodes
            fv_o, _ = oracle_accumulation(edgelist, out_adj, nodes, durations, delays, v)
            if !isapprox(acc.forward[v], fv_o; rtol = 1e-9, atol = 1e-9)
                acc_ok = false
                push!(failures, "$name/accum: forward at node $v is $(acc.forward[v]) vs oracle $fv_o")
                break
            end
        end
    end
    ident = sum(get(durations, n, 0.0) * c for (n, c) in acc.multiplicity; init = 0.0) +
            sum(get(acc.multiplicity, v, 0) * get(delays, (u, v), 0.0) for (u, v) in edgelist; init = 0.0)
    isapprox(ident, acc.total; rtol = 1e-9) ||
        (acc_ok = false; push!(failures, "$name/accum: adjoint identity $(ident) vs total $(acc.total)"))
    net_ok &= acc_ok
    logln(@sprintf("  %-14s %s %-4s  target=%d total=%.6g adjoint_identity=%s", "accumulation",
                   use_oracle ? "ORACLE" : "IDENTITY", acc_ok ? "PASS" : "FAIL", acc.target, acc.total,
                   isapprox(ident, acc.total; rtol = 1e-9) ? "ok" : "BROKEN"))
    push!(summary_rows, "$name,accumulation,$(use_oracle ? "oracle" : "identity"),$(acc_ok ? "PASS" : "FAIL"),$(@sprintf("%.6f", el))")
    return net_ok
end

# ---------- hand networks with asserted ground truth ----------
logln("=== HAND NETWORKS (asserted expected values) ===")
let
    its = [Set{Int64}([1]), Set{Int64}([2, 3]), Set{Int64}([4])]
    outg = Dict{Int64,Set{Int64}}(1 => Set([2, 3]), 2 => Set([4]), 3 => Set([4]), 4 => Set{Int64}())
    incg = Dict{Int64,Set{Int64}}(2 => Set([1]), 3 => Set([1]), 4 => Set([2, 3]), 1 => Set{Int64}())
    srcs = Set{Int64}([1])
    d = Dict{Int64,Float64}(1 => 1.0, 2 => 5.0, 3 => 2.0, 4 => 1.0)
    w = Dict{Tuple{Int64,Int64},Float64}()

    r = analyze(its, outg, incg, srcs, d, w; mode = LONGEST_PATH)
    @assert r.project_value == 7.0 && r.critical == [1, 2, 4]
    @assert r.margin[3] == 3.0 && r.early_start[4] == 6.0 && r.late_start[3] == 4.0
    r = analyze(its, outg, incg, srcs, d, w; mode = SHORTEST_PATH)
    @assert r.project_value == 4.0 && r.critical == [1, 3, 4] && r.margin[2] == 3.0
    a = accumulation_analysis(its, outg, incg, srcs, d, w)
    @assert a.target == 4 && a.total == 10.0 && a.multiplicity[1] == 2 && a.ranking == [2, 1, 3, 4]
    logln("  diamond net: longest/shortest/accumulation asserted PASS")

    its2 = [Set{Int64}([1]), Set{Int64}([2, 3])]
    outg2 = Dict{Int64,Set{Int64}}(1 => Set([2, 3]), 2 => Set{Int64}(), 3 => Set{Int64}())
    incg2 = Dict{Int64,Set{Int64}}(2 => Set([1]), 3 => Set([1]), 1 => Set{Int64}())
    d2 = Dict{Int64,Float64}(1 => 1.0, 2 => 1.0, 3 => 5.0)
    r = analyze(its2, outg2, incg2, Set{Int64}([1]), d2, w; mode = LONGEST_PATH)
    @assert r.project_value == 6.0 && r.critical == [1, 3] && r.margin[2] == 4.0
    logln("  multi-sink net: longest asserted PASS")
end

# ---------- network sweep ----------
logln("\n=== NETWORK SWEEP (engine vs independent oracle) ===")

function find_edges_file(dir)
    for f in readdir(dir)
        endswith(uppercase(f), ".EDGES") && return joinpath(dir, f)
    end
    for f in readdir(dir)
        (endswith(f, ".csv") && occursin("edge", lowercase(f))) && return joinpath(dir, f)
    end
    return nothing
end

function parse_cpm_json(path)
    j = JSON.parsefile(path)
    lowercase(String(get(j, "data_type", "Float64"))) == "float64" || return nothing
    haskey(j, "time_analysis") || return nothing
    ta = j["time_analysis"]
    d = Dict{Int64,Float64}(parse(Int64, k) => Float64(v) for (k, v) in ta["node_durations"])
    w = Dict{Tuple{Int64,Int64},Float64}()
    for (k, v) in get(ta, "edge_delays", Dict())
        m = match(r"\((\d+)\s*,\s*(\d+)\)", k)
        m === nothing && continue
        w[(parse(Int64, m[1]), parse(Int64, m[2]))] = Float64(v)
    end
    return d, w
end

nets = [
    ("water", joinpath(REPO, "case studies", "water", "water.EDGES"),
     joinpath(REPO, "case studies", "water", "water-cpm-inputs.json")),
]
for folder in ["KarlNetwork", "grid-graph-5x5", "metro_directed_dag_for_ipm",
               "ergo-proxy-dag-network", "drone-medical-delivery-network",
               "continental_medical_network", "hybrid_power_hierarchical",
               "glasgow_to_shetland_extreme", "highland_to_lowland_full_network"]
    dir = joinpath(REPO, "dag_ntwrk_files", folder)
    isdir(dir) || continue
    ef = find_edges_file(dir)
    cpmdir = joinpath(dir, "cpm")
    cj = isdir(cpmdir) ? [joinpath(cpmdir, f) for f in readdir(cpmdir) if endswith(f, ".json")] : String[]
    (ef !== nothing && !isempty(cj)) && push!(nets, (folder, ef, cj[1]))
end

all_ok = true
for (name, ef, cj) in nets
    try
        parsed = parse_cpm_json(cj)
        if parsed === nothing
            logln("== $name == SKIPPED (non-Float64 or unexpected cpm json shape)")
            continue
        end
        d, w = parsed
        global all_ok &= run_network(name, ef, d, w)
    catch e
        global all_ok = false
        push!(failures, "$name: ERROR $(sprint(showerror, e))")
        logln("== $name == ERROR: $(sprint(showerror, e))")
    end
end

logln("\n=== SUMMARY ===")
logln("run: ", Dates.now())
for row in summary_rows; logln(row); end
if isempty(failures)
    logln("ALL CHECKS PASSED")
else
    logln("FAILURES ($(length(failures))):")
    for f in failures; logln("  ", f); end
end
open(joinpath(OUTDIR, "float_validation_summary.csv"), "w") do io
    println(io, "network,mode,check,result,seconds")
    for row in summary_rows; println(io, row); end
end
close(LOG)
