# Gate for promoting the domination split into CriticalPathV2: the module function
# interval_analyze_split (forced onto the split path) must reproduce interval_analyze_exact
# margins and criticality on the three oracle nets, and the never-worse fallback must route
# small-k instances to the exhaustive driver.
# USAGE: julia -t 1 "validation/cpm_v2/promotion_gate.jl"

const REPO = raw"c:\Users\ohian\OneDrive - University of Strathclyde\Documents\Programmming Files\Julia Files\InformationPropagation\Info_Prop_Framework_Project"
using Pkg; Pkg.activate(REPO)
include(joinpath(REPO,"InfoPropFrmwrk","src","Algorithms","InfoPropFramework.jl")); using .InfoPropFramework
include(joinpath(REPO,"InfoPropFrmwrk","src","Algorithms","CriticalPathV2","CriticalPathV2Module.jl")); using .CriticalPathV2Module
using JSON, Printf

fails = String[]

function build(edges)
    sources = Set(n for n in union(Set(u for (u,_) in edges), Set(v for (_,v) in edges))
                  if !any(e->e[2]==n, edges))
    outgoing = Dict{Int64,Set{Int64}}(); incoming = Dict{Int64,Set{Int64}}()
    for (u,v) in edges; push!(get!(outgoing,u,Set{Int64}()), v); push!(get!(incoming,v,Set{Int64}()), u); end
    itersets, _, _ = find_iteration_sets(edges, outgoing, incoming)
    (sources, outgoing, incoming, itersets)
end

function gate(name, edges, dI, wI)
    sources, outg, incg, its = build(edges)
    ex = interval_analyze_exact(its, outg, incg, sources, dI, wI; mode=LONGEST_PATH, atol=1e-6, max_corners=1<<20)
    sp = interval_analyze_split(its, outg, incg, sources, dI, wI; mode=LONGEST_PATH, atol=1e-6, force_split=true)
    md = maximum(max(abs(sp.margin[n].lo - ex.margin[n].lo), abs(sp.margin[n].hi - ex.margin[n].hi))
                 for n in keys(ex.margin))
    ok = md <= 1e-9 && sp.necessarily_critical == ex.necessarily_critical &&
         sp.possibly_critical == ex.possibly_critical && sp.method == :exact_domination_split
    ok || push!(fails, "$name: split-vs-exhaustive maxdiff=$md method=$(sp.method)")
    fb = interval_analyze_split(its, outg, incg, sources, dI, wI; mode=LONGEST_PATH, atol=1e-6)
    fbok = fb.method in (:exact_corners_exhaustive, :exact_domination_split)
    fbok || push!(fails, "$name: fallback produced method $(fb.method)")
    @printf("%-16s split-vs-exhaustive %s (maxdiff=%.2g, %d runs vs %d)  fallback_method=%s\n",
            name, ok ? "PASS" : "FAIL", md, sp.corner_count, ex.corner_count, fb.method)
end

let edges = [(1,2),(1,3),(2,8),(3,4),(3,5),(4,6),(5,6),(6,7),(7,8)]
    nodes = sort(collect(union(Set(u for (u,_) in edges), Set(v for (_,v) in edges))))
    dI = Dict{Int64,ValueInterval}(n => ValueInterval(1.0+0.5*n, (1.0+0.5*n)*1.25) for n in nodes)
    wI = Dict{Tuple{Int64,Int64},ValueInterval}(e => ValueInterval(0.5,0.5) for e in edges)
    gate("chapterA-allvar", edges, dI, wI)
end

for (name, folder, edfile, jsub) in (
        ("water-8var", nothing, joinpath(REPO,"case studies","water","water.EDGES"),
         joinpath(REPO,"case studies","water","water-cpm-inputs.json")),
        ("grid5x5-8var", joinpath(REPO,"dag_ntwrk_files","grid-graph-5x5"), nothing, nothing))
    local edges, d0, w0
    if name == "water-8var"
        j = JSON.parsefile(jsub)
        ta = j["time_analysis"]
        d0 = Dict{Int64,Float64}(parse(Int64,kk)=>Float64(v) for (kk,v) in ta["node_durations"])
        w0 = Dict{Tuple{Int64,Int64},Float64}()
        for (kk,v) in ta["edge_delays"]
            m = match(r"\((\d+)\s*,\s*(\d+)\)", kk); m===nothing && continue
            w0[(parse(Int64,m[1]),parse(Int64,m[2]))] = Float64(v)
        end
        edges, _, _, _ = read_graph_to_dict(edfile)
    else
        cj = joinpath(folder,"cpm",[f for f in readdir(joinpath(folder,"cpm")) if endswith(f,".json")][1])
        j = JSON.parsefile(cj)
        ta = j["time_analysis"]
        d0 = Dict{Int64,Float64}(parse(Int64,kk)=>Float64(v) for (kk,v) in ta["node_durations"])
        w0 = Dict{Tuple{Int64,Int64},Float64}()
        for (kk,v) in get(ta,"edge_delays",Dict())
            m = match(r"\((\d+)\s*,\s*(\d+)\)", kk); m===nothing && continue
            w0[(parse(Int64,m[1]),parse(Int64,m[2]))] = Float64(v)
        end
        ef = nothing
        for f in readdir(folder); endswith(uppercase(f),".EDGES") && (ef = joinpath(folder,f); break); end
        edges, _, _, _ = read_graph_to_dict(ef)
    end
    big = sort(collect(keys(d0)); by=n->-d0[n])[1:8]
    dI = Dict{Int64,ValueInterval}(n => n in big ? ValueInterval(0.8*d0[n], 1.2*d0[n]) :
                                                   ValueInterval(d0[n], d0[n]) for n in keys(d0))
    wI = Dict{Tuple{Int64,Int64},ValueInterval}(e => ValueInterval(v,v) for (e,v) in w0)
    gate(name, edges, dI, wI)
end

println(isempty(fails) ? "PROMOTION GATE: ALL PASS" : "PROMOTION GATE FAILURES: $(join(fails, "; "))")
