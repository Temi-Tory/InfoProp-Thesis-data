# Scaling probe for the domination split: ALL durations interval, where exhaustive corner
# enumeration (2^k) is impossible and the split's cost is sum_v 2^|H_v|. Exactness here rests
# on the two lemmas plus the k=8 oracle agreement in run_tightness_research.jl; no oracle
# exists at this scale, which is the point.
# USAGE: julia -t 1 "validation/cpm_v2/run_tightness_scaling.jl"

const REPO = raw"c:\Users\ohian\OneDrive - University of Strathclyde\Documents\Programmming Files\Julia Files\InformationPropagation\Info_Prop_Framework_Project"
using Pkg; Pkg.activate(REPO)
include(joinpath(REPO,"InfoPropFrmwrk","src","Algorithms","InfoPropFramework.jl")); using .InfoPropFramework
include(joinpath(REPO,"InfoPropFrmwrk","src","Algorithms","CriticalPathV2","CriticalPathV2Module.jl")); using .CriticalPathV2Module
using JSON, Printf, Dates

const LOG = open(joinpath(REPO, "validation", "cpm_v2", "tightness_scaling_log.txt"), "w")
logln(args...) = (println(LOG, args...); println(args...))
const RUN_BUDGET = 3_000_000

function build(edges)
    nodes = sort(collect(union(Set(u for (u,_) in edges), Set(v for (_,v) in edges))))
    sources = Set(n for n in nodes if !any(e->e[2]==n, edges))
    outgoing = Dict{Int64,Set{Int64}}(); incoming = Dict{Int64,Set{Int64}}()
    for (u,v) in edges; push!(get!(outgoing,u,Set{Int64}()), v); push!(get!(incoming,v,Set{Int64}()), u); end
    itersets, anc, desc = find_iteration_sets(edges, outgoing, incoming)
    (nodes, sources, outgoing, incoming, itersets, anc, desc)
end

function bypass_sets(v, nodes, outgoing, incoming)
    sinks = [n for n in nodes if n != v && isempty(get(outgoing, n, Set{Int64}()))]
    S = Set{Int64}(sinks); stack = copy(sinks)
    while !isempty(stack)
        n = pop!(stack)
        for p in get(incoming, n, Set{Int64}())
            (p == v || p in S) && continue
            push!(S, p); push!(stack, p)
        end
    end
    srcs = [n for n in nodes if n != v && isempty(get(incoming, n, Set{Int64}()))]
    T = Set{Int64}(srcs); stack = copy(srcs)
    while !isempty(stack)
        n = pop!(stack)
        for s in get(outgoing, n, Set{Int64}())
            (s == v || s in T) && continue
            push!(T, s); push!(stack, s)
        end
    end
    (S, T)
end

function split_all_var(name, edges, dI, wI)
    logln("== $name ==")
    nodes, sources, outg, incg, its, anc, desc = build(edges)
    varn = sort!([k for (k,v) in dI if !is_degenerate(v)])
    k = length(varn)

    plans = Dict{Int64,Tuple{Vector{Int64},Dict{Int64,Symbol}}}()
    total = 0
    maxH = 0
    for v in nodes
        S, T = bypass_sets(v, nodes, outg, incg)
        comp_anc = Set(u for u in get(anc, v, Set{Int64}()) if u != v)
        comp_desc = Set(u for u in get(desc, v, Set{Int64}()) if u != v)
        H = Int64[]; rule = Dict{Int64,Symbol}()
        for u in varn
            if u == v || (u in comp_anc && !(u in S)) || (u in comp_desc && !(u in T))
                rule[u] = :dominated
            elseif !(u in comp_anc) && !(u in comp_desc)
                rule[u] = :incomparable
            else
                push!(H, u)
            end
        end
        plans[v] = (H, rule)
        total += 2 * (1 << length(H))
        maxH = max(maxH, length(H))
    end
    logln(@sprintf("  k=%d interval durations: exhaustive would need 2^%d = %.3g runs", k, k, 2.0^k))
    logln(@sprintf("  split needs %d runs (max|H_v|=%d, mean|H_v|=%.2f)", total, maxH,
                   sum(length(p[1]) for p in values(plans)) / length(plans)))
    if total > RUN_BUDGET
        logln("  over budget ($RUN_BUDGET); reporting the boundary, not running")
        return
    end

    w0 = Dict{Tuple{Int64,Int64},Float64}(e => v.lo for (e,v) in wI)
    t0 = time()
    fl = Dict{Int64,Float64}(); fu = Dict{Int64,Float64}()
    d = Dict{Int64,Float64}(kk => vv.lo for (kk,vv) in dI)
    for v in nodes
        H, rule = plans[v]
        fplus = -Inf; fminus = Inf
        for (target_hi, store) in ((true, :plus), (false, :minus))
            for u in varn
                r = get(rule, u, :H)
                if r == :incomparable
                    d[u] = target_hi ? dI[u].hi : dI[u].lo
                elseif r == :dominated
                    d[u] = target_hi ? dI[u].lo : dI[u].hi
                end
            end
            for mask in 0:(1 << length(H)) - 1
                for (i,u) in enumerate(H)
                    d[u] = (mask >> (i-1)) & 1 == 1 ? dI[u].hi : dI[u].lo
                end
                r = analyze(its, outg, incg, sources, d, w0; mode=LONGEST_PATH, atol=1e-6)
                if store == :plus; fplus = max(fplus, r.margin[v]); else; fminus = min(fminus, r.margin[v]); end
            end
        end
        fl[v] = fminus; fu[v] = fplus
    end
    el = time() - t0
    ncrit = sort!([n for n in nodes if fu[n] <= 1e-6])
    pcrit = sort!([n for n in nodes if fl[n] <= 1e-6])
    logln(@sprintf("  completed in %.2fs: necessarily_critical=%s (%d) possibly_critical=%d nodes",
                   el, ncrit, length(ncrit), length(pcrit)))
end

let
    j = JSON.parsefile(joinpath(REPO,"case studies","water","water-cpm-inputs.json"))
    ta = j["time_analysis"]
    d0 = Dict{Int64,Float64}(parse(Int64,kk)=>Float64(v) for (kk,v) in ta["node_durations"])
    w0 = Dict{Tuple{Int64,Int64},Float64}()
    for (kk,v) in ta["edge_delays"]
        m = match(r"\((\d+)\s*,\s*(\d+)\)", kk); m===nothing && continue
        w0[(parse(Int64,m[1]),parse(Int64,m[2]))] = Float64(v)
    end
    edges, _, _, _ = read_graph_to_dict(joinpath(REPO,"case studies","water","water.EDGES"))
    dI = Dict{Int64,ValueInterval}(n => ValueInterval(0.8*d0[n], 1.2*d0[n]) for n in keys(d0))
    wI = Dict{Tuple{Int64,Int64},ValueInterval}(e => ValueInterval(v,v) for (e,v) in w0)
    split_all_var("water-ALLvar (k=32)", edges, dI, wI)
end

let
    dir = joinpath(REPO,"dag_ntwrk_files","grid-graph-5x5")
    cj = joinpath(dir,"cpm",[f for f in readdir(joinpath(dir,"cpm")) if endswith(f,".json")][1])
    j = JSON.parsefile(cj)
    ta = j["time_analysis"]
    d0 = Dict{Int64,Float64}(parse(Int64,kk)=>Float64(v) for (kk,v) in ta["node_durations"])
    w0 = Dict{Tuple{Int64,Int64},Float64}()
    for (kk,v) in get(ta,"edge_delays",Dict())
        m = match(r"\((\d+)\s*,\s*(\d+)\)", kk); m===nothing && continue
        w0[(parse(Int64,m[1]),parse(Int64,m[2]))] = Float64(v)
    end
    ef = nothing
    for f in readdir(dir); endswith(uppercase(f),".EDGES") && (ef = joinpath(dir,f); break); end
    edges, _, _, _ = read_graph_to_dict(ef)
    dI = Dict{Int64,ValueInterval}(n => ValueInterval(0.8*d0[n], 1.2*d0[n]) for n in keys(d0))
    wI = Dict{Tuple{Int64,Int64},ValueInterval}(e => ValueInterval(v,v) for (e,v) in w0)
    split_all_var("grid5x5-ALLvar (k=25)", edges, dI, wI)
end

logln("\nrun: ", Dates.now())
close(LOG)
