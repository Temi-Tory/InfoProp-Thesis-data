# Certify the published slide 9/10 water tables against CriticalPathV2 (which is itself
# oracle-certified): slide 9 EF+slack vs LongestPath forward+margin; slide 10 EF column vs
# Accumulation forward. Slide 10's "Slack" column is deliberately NOT reproduced: V2's
# accumulation backward object is the adjoint (sensitivity/allowance), the old min-subtractive
# numbers had no defined semantics (CPM_STATE_OF_UNION.md finding 5).
# USAGE: julia -t 1 "validation/cpm_v2/slide_table_check.jl"

const REPO = raw"c:\Users\ohian\OneDrive - University of Strathclyde\Documents\Programmming Files\Julia Files\InformationPropagation\Info_Prop_Framework_Project"
using Pkg; Pkg.activate(REPO)
include(joinpath(REPO,"InfoPropFrmwrk","src","Algorithms","InfoPropFramework.jl")); using .InfoPropFramework
include(joinpath(REPO,"InfoPropFrmwrk","src","Algorithms","CriticalPathV2","CriticalPathV2Module.jl")); using .CriticalPathV2Module
using JSON, Printf

j = JSON.parsefile(joinpath(REPO,"case studies","water","water-cpm-inputs.json"))
ta = j["time_analysis"]
d0 = Dict{Int64,Float64}(parse(Int64,kk)=>Float64(v) for (kk,v) in ta["node_durations"])
w0 = Dict{Tuple{Int64,Int64},Float64}()
for (kk,v) in ta["edge_delays"]
    m = match(r"\((\d+)\s*,\s*(\d+)\)", kk); m===nothing && continue
    w0[(parse(Int64,m[1]),parse(Int64,m[2]))] = Float64(v)
end
edges, outgoing, incoming, sources = read_graph_to_dict(joinpath(REPO,"case studies","water","water.EDGES"))
itersets, _, _ = find_iteration_sets(edges, outgoing, incoming)

fails = String[]

r = analyze(itersets, outgoing, incoming, sources, d0, w0; mode=LONGEST_PATH, atol=1e-6)
slide9 = [(27,45.0,0.0),(19,33.0,0.0),(11,21.0,0.0),(3,9.0,0.0),(30,43.5,1.5),(14,19.5,1.5)]
for (n, ef, sl) in slide9
    ok = isapprox(r.forward[n], ef; atol=1e-9) && isapprox(r.margin[n], sl; atol=1e-9)
    ok || push!(fails, "slide9 node $n: V2 EF=$(r.forward[n]) slack=$(r.margin[n]) vs slide ($ef,$sl)")
    @printf("slide9  node %-3d EF %-6g slack %-4g  %s\n", n, r.forward[n], r.margin[n], ok ? "MATCH" : "MISMATCH")
end
crit = sort(r.critical)
println("slide9  critical chain from V2 (slack=0): ", crit, "  slide claims 3,11,19,27 among them: ",
        issubset(Set([3,11,19,27]), Set(crit)) ? "YES" : "NO")

a = accumulation_analysis(itersets, outgoing, incoming, sources, d0, w0)
slide10 = [(27,480.0),(30,431.5),(32,415.0),(29,410.5),(19,164.0)]
for (n, ef) in slide10
    ok = isapprox(a.forward[n], ef; atol=1e-9)
    ok || push!(fails, "slide10 node $n: V2 F=$(a.forward[n]) vs slide $ef")
    @printf("slide10 node %-3d F  %-6g  %s\n", n, a.forward[n], ok ? "MATCH" : "MISMATCH")
end
println("slide10 target=$(a.target) total=$(a.total); V2 sensitivity top-5 by contribution: ",
        first(a.ranking, 5))

t = @elapsed for _ in 1:100
    analyze(itersets, outgoing, incoming, sources, d0, w0; mode=LONGEST_PATH, atol=1e-6)
end
@printf("V2 longest-path runtime on water: %.1f microseconds (mean of 100 warm reps)\n", 1e4*t)

println(isempty(fails) ? "SLIDE TABLE CHECK: ALL MATCH" : "MISMATCHES: $(join(fails,"; "))")
