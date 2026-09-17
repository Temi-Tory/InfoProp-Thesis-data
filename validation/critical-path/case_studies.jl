# Chapter case studies (user-approved 2026-08-18):
#   A. Water / ShortestPath: fastest achievable route to the outlet; which stages have margin.
#   B. Drone-medical / MaxScaling: most reliable single delivery route, using the study's own
#      node priors and link probabilities as multiplicative success factors (nothing invented).
#      Includes an inline soundness check (sampled routes never beat the reported optimum).
#   C. Water / Accumulation with a budget: allowance per stage under 10% headroom at the
#      outlet — the semantically-founded replacement for slide 10's retired "Slack" column.
#   D. Warm runtimes per mode for the slide-11 refresh.
# USAGE: julia -t 1 "validation/cpm_v2/case_studies.jl"

const REPO = raw"c:\Users\ohian\OneDrive - University of Strathclyde\Documents\Programmming Files\Julia Files\InformationPropagation\Info_Prop_Framework_Project"
using Pkg; Pkg.activate(REPO)
include(joinpath(REPO,"InfoPropFrmwrk","src","Algorithms","InfoPropFramework.jl")); using .InfoPropFramework
include(joinpath(REPO,"InfoPropFrmwrk","src","Algorithms","CriticalPathV2","CriticalPathV2Module.jl")); using .CriticalPathV2Module
using JSON, Printf, Random, Dates

const LOG = open(joinpath(REPO, "validation", "cpm_v2", "case_studies_log.txt"), "w")
logln(args...) = (println(LOG, args...); println(args...))

# ---------- A + C + D(water): load water ----------
jw = JSON.parsefile(joinpath(REPO,"case studies","water","water-cpm-inputs.json"))
ta = jw["time_analysis"]
d0 = Dict{Int64,Float64}(parse(Int64,kk)=>Float64(v) for (kk,v) in ta["node_durations"])
w0 = Dict{Tuple{Int64,Int64},Float64}()
for (kk,v) in ta["edge_delays"]
    m = match(r"\((\d+)\s*,\s*(\d+)\)", kk); m===nothing && continue
    w0[(parse(Int64,m[1]),parse(Int64,m[2]))] = Float64(v)
end
wedges, wout, winc, wsrc = read_graph_to_dict(joinpath(REPO,"case studies","water","water.EDGES"))
wits, _, _ = find_iteration_sets(wedges, wout, winc)

logln("=== A. Water / ShortestPath: fastest achievable route ===")
rs = analyze(wits, wout, winc, wsrc, d0, w0; mode=SHORTEST_PATH, atol=1e-6)
logln(@sprintf("fastest completion (project value): %.4g time units", rs.project_value))
logln("optimal route (margin = 0, topological order): ", rs.critical)
near = sort([(n, rs.margin[n]) for n in keys(rs.margin) if rs.margin[n] > 1e-9]; by=x->x[2])
logln("closest alternatives (node, extra time over the fastest route):")
for (n, m) in first(near, 5)
    logln(@sprintf("  node %-3d  +%.4g", n, m))
end

logln("\n=== C. Water / Accumulation with budget (allowance demo) ===")
a = accumulation_analysis(wits, wout, winc, wsrc, d0, w0)
budget = round(1.10 * a.total; digits=6)
ab = accumulation_analysis(wits, wout, winc, wsrc, d0, w0; budget=budget)
logln(@sprintf("total accumulated load at outlet %d: %.4g; budget = %.4g (10%% headroom = %.4g)",
               a.target, a.total, budget, budget - a.total))
logln("top-8 stages by contribution, with sensitivity and allowance:")
logln("  node  contribution  multiplicity  allowance(+load before budget breach)")
for n in first(ab.ranking, 8)
    logln(@sprintf("  %-4d  %-12.4g  %-12d  +%.4g", n, ab.contribution[n], ab.multiplicity[n], ab.allowance[n]))
end

# ---------- B: drone MaxScaling ----------
logln("\n=== B. Drone-medical / MaxScaling: most reliable single delivery route ===")
ddir = joinpath(REPO,"dag_ntwrk_files","drone-medical-delivery-network")
np_j = JSON.parsefile(joinpath(ddir,"float","drone-medical-delivery-network-nodepriors.json"))["nodes"]
lp_j = JSON.parsefile(joinpath(ddir,"float","drone-medical-delivery-network-linkprobabilities.json"))["links"]
dnp = Dict{Int64,Float64}(parse(Int64,kk)=>Float64(v) for (kk,v) in np_j)
dlp = Dict{Tuple{Int64,Int64},Float64}()
for (kk,v) in lp_j
    m = match(r"\((\d+)\s*,\s*(\d+)\)", kk); m===nothing && continue
    dlp[(parse(Int64,m[1]),parse(Int64,m[2]))] = Float64(v)
end
dedges, dout, dinc, dsrc = read_graph_to_dict(joinpath(ddir,"drone-medical-delivery-network.EDGES"))
dits, _, _ = find_iteration_sets(dedges, dout, dinc)
dn = length(Set(n for l in dits for n in l))
rm = analyze(dits, dout, dinc, dsrc, dnp, dlp; mode=MAX_SCALING, atol=1e-9)
logln(@sprintf("network: %d nodes, %d edges, %d sources; factors = study's own node priors + link probabilities",
               dn, length(dedges), length(dsrc)))
logln(@sprintf("best end-to-end route success factor: %.6g", rm.project_value))
logln("most reliable route (ratio slack = 0, topological order): ", rm.critical)
alts = sort([(n, rm.margin[n]) for n in keys(rm.margin) if rm.margin[n] > 1e-9]; by=x->x[2])
logln("closest alternative nodes (ratio slack = best/through - 1):")
for (n, m) in first(alts, 5)
    logln(@sprintf("  node %-4d  %.4g", n, m))
end
# soundness sampling: no random route may beat the optimum
rng = MersenneTwister(7); worst = -Inf; viol = 0
srcv = collect(dsrc)
for _ in 1:2000
    v = rand(rng, srcv); prod_ = get(dnp, v, 1.0)
    while true
        succs = collect(get(dout, v, Set{Int64}()))
        isempty(succs) && break
        nv = rand(rng, succs)
        prod_ *= get(dlp, (v, nv), 1.0) * get(dnp, nv, 1.0)
        v = nv
    end
    prod_ > rm.project_value + 1e-12 && (global viol += 1)
    global worst = max(worst, prod_)
end
logln(@sprintf("soundness sampling: 2000 random routes, best sampled %.6g <= optimum %.6g, violations=%d",
               worst, rm.project_value, viol))

# ---------- D: runtimes ----------
logln("\n=== D. Warm runtimes (mean of 100 reps, for slide-11 refresh) ===")
for (tag, f) in (
        ("water longest", () -> analyze(wits, wout, winc, wsrc, d0, w0; mode=LONGEST_PATH)),
        ("water shortest", () -> analyze(wits, wout, winc, wsrc, d0, w0; mode=SHORTEST_PATH)),
        ("water accumulation", () -> accumulation_analysis(wits, wout, winc, wsrc, d0, w0)),
        ("drone max-scaling", () -> analyze(dits, dout, dinc, dsrc, dnp, dlp; mode=MAX_SCALING)))
    f()
    t = @elapsed for _ in 1:100; f(); end
    logln(@sprintf("  %-18s %.1f microseconds", tag, 1e4*t))
end

logln("\nrun: ", Dates.now())
close(LOG)
