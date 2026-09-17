# Monte Carlo adversarial check of the domination-split float bounds on water k=32
# (the instance no exhaustive method can verify). Recomputes the split bounds, persists
# them to CSV, then samples 50,000 configurations (25k uniform-interior + 25k random
# corners) and checks: (a) SOUNDNESS - every sampled float lies inside the bounds;
# (b) ATTAINMENT - the bounds are hit by actual configurations (they are, by
# construction: each bound is the float of an explicitly evaluated corner; the MC
# corners provide independent near-attainment evidence). Also reports measured
# microseconds per propagation to substantiate any extrapolated exhaustive cost.
# USAGE: julia -t 1 "validation/cpm_v2/run_mc_check_water_k32.jl"

const REPO = raw"c:\Users\ohian\OneDrive - University of Strathclyde\Documents\Programmming Files\Julia Files\InformationPropagation\Info_Prop_Framework_Project"
using Pkg; Pkg.activate(REPO)
include(joinpath(REPO,"InfoPropFrmwrk","src","Algorithms","InfoPropFramework.jl")); using .InfoPropFramework
include(joinpath(REPO,"InfoPropFrmwrk","src","Algorithms","CriticalPathV2","CriticalPathV2Module.jl")); using .CriticalPathV2Module
using JSON, Printf, Random, Dates

const LOG = open(joinpath(REPO, "validation", "cpm_v2", "mc_check_water_k32_log.txt"), "w")
logln(args...) = (println(LOG, args...); println(args...))

j = JSON.parsefile(joinpath(REPO,"case studies","water","water-cpm-inputs.json"))
ta = j["time_analysis"]
d0 = Dict{Int64,Float64}(parse(Int64,kk)=>Float64(v) for (kk,v) in ta["node_durations"])
w0 = Dict{Tuple{Int64,Int64},Float64}()
for (kk,v) in ta["edge_delays"]
    m = match(r"\((\d+)\s*,\s*(\d+)\)", kk); m===nothing && continue
    w0[(parse(Int64,m[1]),parse(Int64,m[2]))] = Float64(v)
end
edges, outgoing, incoming, source_nodes = read_graph_to_dict(joinpath(REPO,"case studies","water","water.EDGES"))
itersets, anc, desc = find_iteration_sets(edges, outgoing, incoming)
nodes = sort(collect(union(Set(u for (u,_) in edges), Set(v for (_,v) in edges))))
dI = Dict{Int64,ValueInterval}(n => ValueInterval(0.8*d0[n], 1.2*d0[n]) for n in keys(d0))
varn = sort!(collect(keys(dI)))

function bypass_sets(v)
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

logln("recomputing split bounds (k=$(length(varn)))...")
t0 = time(); nruns = 0
fl = Dict{Int64,Float64}(); fu = Dict{Int64,Float64}()
d = Dict{Int64,Float64}(kk => vv.lo for (kk,vv) in dI)
for v in nodes
    S, T = bypass_sets(v)
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
            r = analyze(itersets, outgoing, incoming, source_nodes, d, w0; mode=LONGEST_PATH, atol=1e-6)
            global nruns += 1
            if store == :plus; fplus = max(fplus, r.margin[v]); else; fminus = min(fminus, r.margin[v]); end
        end
    end
    fl[v] = fminus; fu[v] = fplus
end
el = time() - t0
logln(@sprintf("split done: %d runs in %.1fs = %.1f microseconds/run", nruns, el, 1e6*el/nruns))

open(joinpath(REPO, "validation", "cpm_v2", "water_k32_float_bounds.csv"), "w") do io
    println(io, "node,float_lo,float_hi,necessarily_critical,possibly_critical")
    for v in nodes
        println(io, "$v,$(fl[v]),$(fu[v]),$(fu[v] <= 1e-6),$(fl[v] <= 1e-6)")
    end
end

rng = MersenneTwister(2026)
violations = 0
near_lo = Dict{Int64,Float64}(v => Inf for v in nodes)
near_hi = Dict{Int64,Float64}(v => -Inf for v in nodes)
NS = 50_000
t0 = time()
for s in 1:NS
    if s <= NS ÷ 2
        for u in varn; d[u] = dI[u].lo + rand(rng) * (dI[u].hi - dI[u].lo); end
    else
        for u in varn; d[u] = rand(rng, Bool) ? dI[u].hi : dI[u].lo; end
    end
    r = analyze(itersets, outgoing, incoming, source_nodes, d, w0; mode=LONGEST_PATH, atol=1e-6)
    for v in nodes
        m = r.margin[v]
        (m < fl[v] - 1e-9 || m > fu[v] + 1e-9) && (global violations += 1)
        near_lo[v] = min(near_lo[v], m); near_hi[v] = max(near_hi[v], m)
    end
end
el = time() - t0
logln(@sprintf("MC: %d samples in %.1fs. BOUND VIOLATIONS: %d %s", NS, el, violations,
               violations == 0 ? "(SOUND)" : "(!!! UNSOUND !!!)"))
lo_hit = count(v -> near_lo[v] <= fl[v] + 1e-6, nodes)
hi_hit = count(v -> near_hi[v] >= fu[v] - 1e-6, nodes)
maxslack_lo = maximum(near_lo[v] - fl[v] for v in nodes)
maxslack_hi = maximum(fu[v] - near_hi[v] for v in nodes)
logln(@sprintf("attainment: MC reached the lower bound at %d/%d nodes and the upper at %d/%d;", lo_hit, length(nodes), hi_hit, length(nodes)))
logln(@sprintf("  worst MC-to-bound distance: lo %.4g, hi %.4g (bounds are ATTAINED by the split's own witness corners regardless)", maxslack_lo, maxslack_hi))
logln("run: ", Dates.now())
close(LOG)
