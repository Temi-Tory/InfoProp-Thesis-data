# Interval validation for CriticalPathV2:
#   1. Engine tier-2 (exhaustive corners) vs an INDEPENDENT corner oracle (path
#      enumeration per corner, no engine code): margins and necessary/possible
#      criticality must agree exactly.
#   2. Tier-1 enclosure soundness: encloses exact margins; necessarily-critical is a
#      subset of exact, possibly-critical a superset.
#   3. Diamond-guided experiment: identification with is_det_override = zero-width on
#      the CPM graph; corners enumerated over conditioning-set durations only, other
#      intervals handled by tier-1 enclosure inside each assignment. Sound by
#      construction; the question the experiment answers is TIGHTNESS vs exact, plus
#      the corner-count scaling (2^k exhaustive vs 2^|C| diamond-guided).
# USAGE: julia -t 1 "validation/cpm_v2/run_interval_validation.jl"

const REPO = raw"C:\Development\Info_Prop_Framework_Project\Info_Prop_Framework_Project"
using Pkg; Pkg.activate(REPO)
include(joinpath(REPO,"InfoPropFrmwrk","src","Algorithms","InfoPropFramework.jl")); using .InfoPropFramework
include(joinpath(REPO,"InfoPropFrmwrk","src","Algorithms","CriticalPathV2","CriticalPathV2Module.jl")); using .CriticalPathV2Module
include(joinpath(REPO,"validation","cpm_v2","oracle.jl")); using .CPMOracle
using JSON, Printf, Dates

const LOG = open(joinpath(REPO, "validation", "cpm_v2", "interval_validation_log.txt"), "w")
logln(args...) = (println(LOG, args...); println(args...))
fails = String[]
const ATOL = 1e-9

function build(edges)
    nodes = sort(collect(union(Set(u for (u,_) in edges), Set(v for (_,v) in edges))))
    sources = Set(n for n in nodes if !any(e->e[2]==n, edges))
    outgoing = Dict{Int64,Set{Int64}}(); incoming = Dict{Int64,Set{Int64}}()
    for (u,v) in edges; push!(get!(outgoing,u,Set{Int64}()), v); push!(get!(incoming,v,Set{Int64}()), u); end
    itersets, anc, desc = find_iteration_sets(edges, outgoing, incoming)
    fk, jn = identify_fork_and_join_nodes(outgoing, incoming)
    (nodes, sources, outgoing, incoming, itersets, anc, desc, fk, jn)
end

# Independent corner oracle: path enumeration per corner assignment.
function oracle_corners(edges, dI, wI, kind, initial; atol=1e-6)
    out, nodes, srcs, _ = build_adjacency(edges)
    paths = enumerate_paths(out, srcs; cap=300_000)
    paths === nothing && return nothing
    varn = sort!([k for (k,v) in dI if v.lo != v.hi])
    vare = sort!([k for (k,v) in wI if v.lo != v.hi])
    k = length(varn) + length(vare)
    d = Dict{Int64,Float64}(kk => v.lo for (kk,v) in dI)
    w = Dict{Tuple{Int64,Int64},Float64}(kk => v.lo for (kk,v) in wI)
    mlo = Dict{Int64,Float64}(); mhi = Dict{Int64,Float64}()
    ncrit = Dict{Int64,Bool}(); pcrit = Dict{Int64,Bool}()
    first = true
    for mask in 0:(1<<k)-1
        for (i,n) in enumerate(varn); d[n] = (mask>>(i-1))&1==1 ? dI[n].hi : dI[n].lo; end
        off = length(varn)
        for (i,e) in enumerate(vare); w[e] = (mask>>(off+i-1))&1==1 ? wI[e].hi : wI[e].lo; end
        _, _, mg, cr = oracle_path_mode(paths, d, w; kind=kind, initial=initial, atol=atol)
        crs = Set(cr)
        for (n,m) in mg
            if first
                mlo[n]=m; mhi[n]=m; ncrit[n]=n in crs; pcrit[n]=n in crs
            else
                mlo[n]=min(mlo[n],m); mhi[n]=max(mhi[n],m); ncrit[n]&=n in crs; pcrit[n]|=n in crs
            end
        end
        first = false
    end
    (mlo, mhi, sort!([n for (n,b) in ncrit if b]), sort!([n for (n,b) in pcrit if b]), 1<<k)
end

function check_interval_net(name, edges, dI, wI)
    logln("== $name ==")
    nodes, sources, outg, incg, its, anc, desc, fk, jn = build(edges)
    kvar = count(v->v.lo!=v.hi, values(dI)) + count(v->v.lo!=v.hi, values(wI))

    for (tag, mode, kind, init) in (("longest", LONGEST_PATH, :longest, 0.0),
                                    ("shortest", SHORTEST_PATH, :shortest, 0.0))
        ex = interval_analyze_exact(its, outg, incg, sources, dI, wI; mode=mode, atol=1e-6, max_corners=1<<20)
        oc = oracle_corners(edges, dI, wI, kind, init; atol=1e-6)
        oc === nothing && (logln("  $tag: oracle path cap exceeded, SKIP"); continue)
        mlo_o, mhi_o, nc_o, pc_o, ncorn = oc
        md = 0.0
        for (n,m) in ex.margin
            md = max(md, abs(m.lo - mlo_o[n]), abs(m.hi - mhi_o[n]))
        end
        okm = md <= 1e-6
        okn = ex.necessarily_critical == nc_o
        okp = ex.possibly_critical == pc_o
        okm || push!(fails, "$name/$tag: tier2 margin maxdiff $md vs oracle")
        okn || push!(fails, "$name/$tag: necessarily-critical mismatch $(ex.necessarily_critical) vs $nc_o")
        okp || push!(fails, "$name/$tag: possibly-critical mismatch $(ex.possibly_critical) vs $pc_o")

        t1 = interval_analyze(its, outg, incg, sources, dI, wI; mode=mode, atol=1e-6)
        sound = true
        for (n,m) in ex.margin
            e1 = t1.margin[n]
            (e1.lo <= m.lo + 1e-9 && e1.hi >= m.hi - 1e-9) || (sound=false; break)
        end
        soundn = issubset(Set(t1.necessarily_critical), Set(nc_o))
        soundp = issubset(Set(pc_o), Set(t1.possibly_critical))
        sound && soundn && soundp || push!(fails, "$name/$tag: tier1 enclosure UNSOUND")
        logln(@sprintf("  %-8s corners=%d  tier2-vs-oracle %s (maxdiff=%.2g) ncrit=%s pcrit=%s | tier1 sound=%s",
                       tag, ncorn, okm&&okn&&okp ? "PASS" : "FAIL", md,
                       okn ? "match($(length(nc_o)))" : "MISMATCH",
                       okp ? "match($(length(pc_o)))" : "MISMATCH",
                       sound&&soundn&&soundp ? "PASS" : "FAIL"))
    end

    # --- diamond-guided experiment (longest mode) ---
    npI = Dict{Int64,Interval}(n => Interval(get(dI,n,ValueInterval(0.0,0.0)).lo,
                                             get(dI,n,ValueInterval(0.0,0.0)).hi) for n in nodes)
    lpI = Dict{Tuple{Int64,Int64},Interval}(e => Interval(get(wI,e,ValueInterval(0.0,0.0)).lo,
                                                          get(wI,e,ValueInterval(0.0,0.0)).hi) for e in edges)
    zero_width = n -> begin
        v = get(npI, n, nothing)
        v === nothing ? false : v.lower == v.upper
    end
    roots, uniq = new_identify(edges, npI, lpI, sources, fk, jn, anc, desc, its; is_det_override=zero_width)
    C = Set{Int64}()
    for (_, cd) in uniq; union!(C, cd.diamond.conditioning_nodes); end
    Cvar = sort!([n for n in C if haskey(dI,n) && dI[n].lo != dI[n].hi])

    ex = interval_analyze_exact(its, outg, incg, sources, dI, wI; mode=LONGEST_PATH, atol=1e-6, max_corners=1<<20)
    dgd = Dict(k=>v for (k,v) in dI)
    mlo = Dict{Int64,Float64}(); mhi = Dict{Int64,Float64}(); first = true
    for mask in 0:(1<<length(Cvar))-1
        for (i,n) in enumerate(Cvar)
            x = (mask>>(i-1))&1==1 ? dI[n].hi : dI[n].lo
            dgd[n] = ValueInterval(x, x)
        end
        t1 = interval_analyze(its, outg, incg, sources, dgd, wI; mode=LONGEST_PATH, atol=1e-6)
        for (n,m) in t1.margin
            if first; mlo[n]=m.lo; mhi[n]=m.hi
            else; mlo[n]=min(mlo[n],m.lo); mhi[n]=max(mhi[n],m.hi); end
        end
        first = false
    end
    gap = 0.0; soundc = true
    for (n,m) in ex.margin
        soundc &= (mlo[n] <= m.lo + 1e-9) && (mhi[n] >= m.hi - 1e-9)
        gap = max(gap, (m.lo - mlo[n]) + (mhi[n] - m.hi))
    end
    soundc || push!(fails, "$name/diamond-guided: bounds UNSOUND")
    logln(@sprintf("  diamond-guided: |C|=%d (vs k=%d) corners=%d vs %d  sound=%s  max_tightness_gap=%.4g  %s",
                   length(Cvar), kvar, 1<<length(Cvar), ex.corner_count, soundc ? "yes" : "NO",
                   gap, gap <= 1e-6 ? "EXACT-MATCH" : "conservative"))
end

# Net 1: chapter example A, all durations interval, crisp edges.
let edges = [(1,2),(1,3),(2,8),(3,4),(3,5),(4,6),(5,6),(6,7),(7,8)]
    nodes = sort(collect(union(Set(u for (u,_) in edges), Set(v for (_,v) in edges))))
    dI = Dict{Int64,ValueInterval}(n => ValueInterval(1.0+0.5*n, (1.0+0.5*n)*1.25) for n in nodes)
    wI = Dict{Tuple{Int64,Int64},ValueInterval}(e => ValueInterval(0.5,0.5) for e in edges)
    check_interval_net("chapterA-allvar", edges, dI, wI)
end

# Net 2: water network, the 8 largest durations made interval (+/-20%), delays crisp.
let
    j = JSON.parsefile(joinpath(REPO,"case studies","water","water-cpm-inputs.json"))
    ta = j["time_analysis"]
    d0 = Dict{Int64,Float64}(parse(Int64,k)=>Float64(v) for (k,v) in ta["node_durations"])
    w0 = Dict{Tuple{Int64,Int64},Float64}()
    for (k,v) in ta["edge_delays"]
        m = match(r"\((\d+)\s*,\s*(\d+)\)", k); m===nothing && continue
        w0[(parse(Int64,m[1]),parse(Int64,m[2]))] = Float64(v)
    end
    edges, _, _, _ = read_graph_to_dict(joinpath(REPO,"case studies","water","water.EDGES"))
    big = sort(collect(keys(d0)); by=n->-d0[n])[1:8]
    dI = Dict{Int64,ValueInterval}(n => n in big ? ValueInterval(0.8*d0[n], 1.2*d0[n]) :
                                                   ValueInterval(d0[n], d0[n]) for n in keys(d0))
    wI = Dict{Tuple{Int64,Int64},ValueInterval}(e => ValueInterval(v,v) for (e,v) in w0)
    check_interval_net("water-8var", edges, dI, wI)
end

logln("\nrun: ", Dates.now())
if isempty(fails)
    logln("INTERVAL VALIDATION: ALL PASS")
else
    logln("FAILURES ($(length(fails))):"); foreach(f->logln("  ",f), fails)
end
close(LOG)
