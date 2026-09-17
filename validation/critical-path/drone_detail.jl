# Drone MaxScaling case-study detail for the CPM chapter: per-destination best-route
# success (the service-quality view), factor ranges (for the cost-of-a-leg argument),
# and the best route's hop count. Extends case_studies.jl section B.
# USAGE: julia -t 1 "validation/cpm_v2/drone_detail.jl"

const REPO = raw"c:\Users\ohian\OneDrive - University of Strathclyde\Documents\Programmming Files\Julia Files\InformationPropagation\Info_Prop_Framework_Project"
using Pkg; Pkg.activate(REPO)
include(joinpath(REPO,"InfoPropFrmwrk","src","Algorithms","InfoPropFramework.jl")); using .InfoPropFramework
include(joinpath(REPO,"InfoPropFrmwrk","src","Algorithms","CriticalPathV2","CriticalPathV2Module.jl")); using .CriticalPathV2Module
using JSON, Printf, Dates

const LOG = open(joinpath(REPO, "validation", "cpm_v2", "drone_detail_log.txt"), "w")
logln(args...) = (println(LOG, args...); println(args...))

ddir = joinpath(REPO,"dag_ntwrk_files","drone-medical-delivery-network")
dnp = Dict{Int64,Float64}(parse(Int64,k)=>Float64(v)
    for (k,v) in JSON.parsefile(joinpath(ddir,"float","drone-medical-delivery-network-nodepriors.json"))["nodes"])
dlp = Dict{Tuple{Int64,Int64},Float64}()
for (k,v) in JSON.parsefile(joinpath(ddir,"float","drone-medical-delivery-network-linkprobabilities.json"))["links"]
    m = match(r"\((\d+)\s*,\s*(\d+)\)", k); m===nothing && continue
    dlp[(parse(Int64,m[1]),parse(Int64,m[2]))] = Float64(v)
end
edges, dout, dinc, dsrc = read_graph_to_dict(joinpath(ddir,"drone-medical-delivery-network.EDGES"))
dits, _, _ = find_iteration_sets(edges, dout, dinc)

logln(@sprintf("node priors: min=%.4f max=%.4f | link probs: min=%.4f max=%.4f",
               minimum(values(dnp)), maximum(values(dnp)), minimum(values(dlp)), maximum(values(dlp))))
logln(@sprintf("best possible single leg (max link x max node) = %.4f -> every added leg costs at least %.1f%% of success",
               maximum(values(dlp))*maximum(values(dnp)), 100*(1-maximum(values(dlp))*maximum(values(dnp)))))

r = analyze(dits, dout, dinc, dsrc, dnp, dlp; mode=MAX_SCALING, atol=1e-9)
sinks = sort([n for l in dits for n in l if isempty(get(dout,n,Set{Int64}()))])
logln("destinations (sinks): ", length(sinks))
ranked = sort([(s, r.forward[s]) for s in sinks]; by=x->-x[2])
logln("top-8 destinations by best-route success:")
for (s, v) in first(ranked, 8)
    logln(@sprintf("  sink %-4d  %.4f", s, v))
end
logln("bottom-3 destinations by best-route success:")
for (s, v) in last(ranked, 3)
    logln(@sprintf("  sink %-4d  %.4f", s, v))
end
below = count(x -> x[2] < 0.5, ranked)
logln(@sprintf("destinations with best-route success below 0.5: %d of %d", below, length(sinks)))
logln("global best route (ratio slack 0): ", r.critical, "  edges on route: ", length(r.critical)-1)
logln("run: ", Dates.now())
close(LOG)
