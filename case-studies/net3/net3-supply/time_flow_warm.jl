# Warm second-call timing of the Net3 Baseline capacity analysis (the thesis-wide convention:
# wall-clock, single core, second call in a fresh process, JIT excluded). One measurement per
# fresh process. Server default options. Run with: julia -t 1 --project=<env with the package> time_flow_warm.jl
using InformationPropagationAnalysis, JSON
const IPA = InformationPropagationAnalysis

edges, outg, inc, srcs = IPA.Input.read_graph_to_dict(joinpath(@__DIR__, "net3-supply.EDGES"))
d = JSON.parsefile(joinpath(@__DIR__, "Baseline", "Baseline-capacities.json"))
caps = Dict((Int(e["source"]), Int(e["destination"])) =>
            (e["capacity"] isa String ? Inf : Float64(e["capacity"])) for e in d["edges"])
sinks = Int64.(d["target_nodes"])

run() = IPA.analyze_all(edges, outg, inc, caps, sort!(collect(srcs)), sinks;
                        k_failure=2, cut_limit=1000, path_limit=10_000,
                        combination_limit=10_000, max_depth=64)
run()
t = @elapsed r = run()
line = "max_flow=$(round(r.flow.max_flow; digits=2))  warm second call = $(round(t; digits=2)) s  threads=$(Threads.nthreads())  package=$(pkgversion(IPA))"
println(line)
write(joinpath(@__DIR__, "time_flow_warm_output.txt"), line * "\n")
