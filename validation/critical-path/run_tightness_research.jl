# Tightness research: exact interval floats via the DOMINATION SPLIT.
#
# For node v and an interval duration at node u (longest-path mode, floats f_v = P - through_v):
#   Lemma 1 (incomparable): if no complete path contains both u and v, then through_v does not
#     depend on d_u and P is nondecreasing in it, so f_v is NONDECREASING in d_u.
#   Lemma 2 (dominated): if every complete path through u also passes v (v itself included),
#     then any increase of P forced by d_u travels through v, so through_v rises to meet it
#     and f_v is NONINCREASING in d_u. (Proof: if P_new > P_old the new maximiser contains u,
#     hence v, hence is a through-v path, so through_v_new = P_new and f_v_new = 0.)
# Coordinates covered by the lemmas are fixed at their extremal ends; only the remaining set
#   H_v = { u : u shares a complete path with v AND has a complete path bypassing v }
# is corner-enumerated. H_v is reconvergent structure relative to v. Exactness of the corner
# enumeration inside H_v is certified against the exhaustive tier-2 margins (themselves
# oracle-certified in run_interval_validation.jl).
#
# Outputs: per-net PASS/FAIL vs exhaustive, run-count scaling (sum_v 2^|H_v| vs 2^k), and the
# relation between H_v and the diamond conditioning sets from is_det_override = zero-width.
# USAGE: julia -t 1 "validation/cpm_v2/run_tightness_research.jl"

const REPO = raw"c:\Users\ohian\OneDrive - University of Strathclyde\Documents\Programmming Files\Julia Files\InformationPropagation\Info_Prop_Framework_Project"
using Pkg; Pkg.activate(REPO)
include(joinpath(REPO,"InfoPropFrmwrk","src","Algorithms","InfoPropFramework.jl")); using .InfoPropFramework
include(joinpath(REPO,"InfoPropFrmwrk","src","Algorithms","CriticalPathV2","CriticalPathV2Module.jl")); using .CriticalPathV2Module
using JSON, Printf, Dates

const LOG = open(joinpath(REPO, "validation", "cpm_v2", "tightness_research_log.txt"), "w")
logln(args...) = (println(LOG, args...); println(args...))
fails = String[]

function build(edges)
    nodes = sort(collect(union(Set(u for (u,_) in edges), Set(v for (_,v) in edges))))
    sources = Set(n for n in nodes if !any(e->e[2]==n, edges))
    outgoing = Dict{Int64,Set{Int64}}(); incoming = Dict{Int64,Set{Int64}}()
    for (u,v) in edges; push!(get!(outgoing,u,Set{Int64}()), v); push!(get!(incoming,v,Set{Int64}()), u); end
    itersets, anc, desc = find_iteration_sets(edges, outgoing, incoming)
    fk, jn = identify_fork_and_join_nodes(outgoing, incoming)
    (nodes, sources, outgoing, incoming, itersets, anc, desc, fk, jn)
end

# Nodes that can reach a sink / be reached from a source in G minus v.
function bypass_sets(v, nodes, outgoing, incoming)
    sinks = [n for n in nodes if n != v && isempty(get(outgoing, n, Set{Int64}()))]
    S = Set{Int64}(sinks)
    stack = copy(sinks)
    while !isempty(stack)
        n = pop!(stack)
        for p in get(incoming, n, Set{Int64}())
            (p == v || p in S) && continue
            push!(S, p); push!(stack, p)
        end
    end
    srcs = [n for n in nodes if n != v && isempty(get(incoming, n, Set{Int64}()))]
    T = Set{Int64}(srcs)
    stack = copy(srcs)
    while !isempty(stack)
        n = pop!(stack)
        for s in get(outgoing, n, Set{Int64}())
            (s == v || s in T) && continue
            push!(T, s); push!(stack, s)
        end
    end
    (S, T)
end

function tightness_experiment(name, edges, dI, wI)
    logln("== $name ==")
    nodes, sources, outg, incg, its, anc, desc, fk, jn = build(edges)
    varn = sort!([k for (k,v) in dI if !is_degenerate(v)])
    k = length(varn)

    ex = interval_analyze_exact(its, outg, incg, sources, dI, wI;
                                mode=LONGEST_PATH, atol=1e-6, max_corners=1<<20)

    w0 = Dict{Tuple{Int64,Int64},Float64}(e => v.lo for (e,v) in wI)   # edges crisp in tests
    total_runs = 0
    maxH = 0
    gap = 0.0
    Hsizes = Dict{Int64,Int}()
    for v in nodes
        S, T = bypass_sets(v, nodes, outg, incg)
        comp_anc = Set(u for u in get(anc, v, Set{Int64}()) if u != v)
        comp_desc = Set(u for u in get(desc, v, Set{Int64}()) if u != v)
        H = Int64[]
        rule = Dict{Int64,Symbol}()   # :dominated or :incomparable for monotone vars
        for u in varn
            if u == v || (u in comp_anc && !(u in S)) || (u in comp_desc && !(u in T))
                rule[u] = :dominated
            elseif !(u in comp_anc) && !(u in comp_desc)
                rule[u] = :incomparable
            else
                push!(H, u)
            end
        end
        Hsizes[v] = length(H); maxH = max(maxH, length(H))

        fplus = -Inf; fminus = Inf
        d = Dict{Int64,Float64}(kk => vv.lo for (kk,vv) in dI)
        for (target_hi, store) in ((true, :plus), (false, :minus))
            for u in varn
                if get(rule, u, :H) == :incomparable
                    d[u] = target_hi ? dI[u].hi : dI[u].lo
                elseif get(rule, u, :H) == :dominated
                    d[u] = target_hi ? dI[u].lo : dI[u].hi
                end
            end
            for mask in 0:(1 << length(H)) - 1
                for (i,u) in enumerate(H)
                    d[u] = (mask >> (i-1)) & 1 == 1 ? dI[u].hi : dI[u].lo
                end
                r = analyze(its, outg, incg, sources, d, w0; mode=LONGEST_PATH, atol=1e-6)
                total_runs += 1
                if store == :plus
                    fplus = max(fplus, r.margin[v])
                else
                    fminus = min(fminus, r.margin[v])
                end
            end
        end
        m = ex.margin[v]
        gv = max(abs(fminus - m.lo), abs(fplus - m.hi))
        gap = max(gap, gv)
        gv > 1e-6 && push!(fails, @sprintf("%s node %d: split [%.6g,%.6g] vs exact [%.6g,%.6g]",
                                           name, v, fminus, fplus, m.lo, m.hi))
    end

    npI = Dict{Int64,Interval}(n => Interval(get(dI,n,ValueInterval(0.0,0.0)).lo,
                                             get(dI,n,ValueInterval(0.0,0.0)).hi) for n in nodes)
    lpI = Dict{Tuple{Int64,Int64},Interval}(e => Interval(v.lo, v.hi) for (e,v) in wI)
    zero_width = n -> (x = get(npI,n,nothing); x === nothing ? false : x.lower == x.upper)
    _, uniq = new_identify(edges, npI, lpI, sources, fk, jn, anc, desc, its; is_det_override=zero_width)
    C = Set{Int64}()
    for (_, cd) in uniq; union!(C, cd.diamond.conditioning_nodes); end
    logln(@sprintf("  exact-vs-domination-split: max_gap=%.3g  %s", gap, gap <= 1e-6 ? "EXACT (PASS)" : "MISMATCH (FAIL)"))
    logln(@sprintf("  cost: split_runs=%d vs exhaustive=%d (k=%d)  max|H_v|=%d  mean|H_v|=%.2f",
                   total_runs, 2 * ex.corner_count, k, maxH,
                   sum(values(Hsizes)) / length(Hsizes)))
    logln(@sprintf("  diamond conditioning set C=%s (|C|=%d); interval members of C=%s",
                   sort(collect(C)), length(C), sort([n for n in C if n in Set(varn)])))
    logln("  |H_v| by node: ", join(["$v:$(Hsizes[v])" for v in nodes], " "))
end

# Net 1: chapter example A, all durations interval.
let edges = [(1,2),(1,3),(2,8),(3,4),(3,5),(4,6),(5,6),(6,7),(7,8)]
    nodes = sort(collect(union(Set(u for (u,_) in edges), Set(v for (_,v) in edges))))
    dI = Dict{Int64,ValueInterval}(n => ValueInterval(1.0+0.5*n, (1.0+0.5*n)*1.25) for n in nodes)
    wI = Dict{Tuple{Int64,Int64},ValueInterval}(e => ValueInterval(0.5,0.5) for e in edges)
    tightness_experiment("chapterA-allvar", edges, dI, wI)
end

# Net 2: water, 8 largest durations interval.
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
    big = sort(collect(keys(d0)); by=n->-d0[n])[1:8]
    dI = Dict{Int64,ValueInterval}(n => n in big ? ValueInterval(0.8*d0[n], 1.2*d0[n]) :
                                                   ValueInterval(d0[n], d0[n]) for n in keys(d0))
    wI = Dict{Tuple{Int64,Int64},ValueInterval}(e => ValueInterval(v,v) for (e,v) in w0)
    tightness_experiment("water-8var", edges, dI, wI)
end

# Net 3: grid-graph-5x5, 8 largest durations interval (dense reconvergence stress).
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
    for f in readdir(dir)
        endswith(uppercase(f), ".EDGES") && (ef = joinpath(dir,f); break)
    end
    edges, _, _, _ = read_graph_to_dict(ef)
    big = sort(collect(keys(d0)); by=n->-d0[n])[1:8]
    dI = Dict{Int64,ValueInterval}(n => n in big ? ValueInterval(0.8*d0[n], 1.2*d0[n]) :
                                                   ValueInterval(d0[n], d0[n]) for n in keys(d0))
    wI = Dict{Tuple{Int64,Int64},ValueInterval}(e => ValueInterval(v,v) for (e,v) in w0)
    tightness_experiment("grid5x5-8var", edges, dI, wI)
end

logln("\nrun: ", Dates.now())
if isempty(fails)
    logln("TIGHTNESS RESEARCH: DOMINATION SPLIT EXACT ON ALL NETS")
else
    logln("MISMATCHES ($(length(fails))):"); foreach(f->logln("  ",f), fails)
end
close(LOG)
