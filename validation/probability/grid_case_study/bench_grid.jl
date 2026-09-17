# GRID cost suite (run ALONE, single-thread). Empirically confirms the complexity analysis:
#   (1) @benchmark  -> median time + memory + allocs for Float64 / Interval / p-box@{50,200,800}
#   (2) time profiler (per-sample, source-file attributed) -> %% time PBA vs IPA vs other(Base/GC)
#   (3) alloc profiler -> bytes PBA vs IPA vs other
# plus the grid's DEFINITE structural numbers (n_diamonds, maxcond, measured_ops) so the cost is tied to
# the 2^|C_d| enumeration. Config A (paper): node priors EXACT 1.0, links 0.9. Imprecise = links only:
#   Interval  links [0.9-w, 0.9+w];  p-box links triangular(mode 0.9, +/-w) via quantile pbox; nodes exact 1.0.
const REPO = raw"c:\Users\ohian\OneDrive - University of Strathclyde\Documents\Programmming Files\Julia Files\InformationPropagation\Info_Prop_Framework_Project"
using Pkg; Pkg.activate(REPO); push!(LOAD_PATH, joinpath(REPO,"validation","bddenv"))
include(joinpath(REPO,"InfoPropFrmwrk","src","Algorithms","InfoPropFramework.jl")); using .InfoPropFramework
using Random, Printf, BenchmarkTools, Profile, Distributions, Logging
import Profile.Allocs
Logging.disable_logging(Logging.Warn)   # silence PBA "Disagreement between theoretical/observed" flood
include(joinpath(REPO,"validation","graph_gen.jl")); include(joinpath(REPO,"validation","oracles.jl"))
const DAT   = joinpath(REPO,"InfoPropFrmwrk","Publications","My work","RESS_response","grid_case_study","data")
const NOTES = joinpath(REPO,"InfoPropFrmwrk","Publications","My work","RESS_response","notes")

g  = load_edges("grid", joinpath(REPO,"dag_ntwrk_files","grid-graph","grid-graph.EDGES"))
P  = make_problem(g); fk,jn = identify_fork_and_join_nodes(P.outgoing,P.incoming)
const W = 0.05    # cost is ~independent of band width; one width suffices for timing

tri_pbox(v,w) = begin                     # method C: precise triangular p-box from quantiles
    steps = PBA.parametersPBA.steps
    a=max(0.0,v-w); b=min(1.0,v+w); c=clamp(v,a,b)
    qs = quantile.(TriangularDist(a,b,c), [(i-0.5)/steps for i in 1:steps])
    PBA.pbox(qs, qs)
end
one_pb() = PBA.makepbox(PBA.interval(1.0,1.0))

function inputs(T)
    if T==Float64
        return Dict{Int64,Float64}(n=>1.0 for n in P.all_nodes),
               Dict{Tuple{Int64,Int64},Float64}(e=>0.9 for e in keys(P.eid))
    elseif T==Interval
        return Dict{Int64,Interval}(n=>Interval(1.0,1.0) for n in P.all_nodes),
               Dict{Tuple{Int64,Int64},Interval}(e=>Interval(max(0.0,0.9-W),min(1.0,0.9+W)) for e in keys(P.eid))
    else
        return Dict{Int64,pbox}(n=>one_pb() for n in P.all_nodes),
               Dict{Tuple{Int64,Int64},pbox}(e=>tri_pbox(0.9,W) for e in keys(P.eid))
    end
end
mkcache(::Type{Float64})  = Dict{CacheKey,DiamondCacheEntry{Float64}}()
mkcache(::Type{Interval}) = Dict{CacheKey,DiamondCacheEntry{Interval}}()
mkcache(::Type{pbox})     = Dict{CacheKey,DiamondCacheEntry{pbox}}()
function mkrun(T, steps)
    T==pbox && PBA.setSteps(steps)
    np,lp = inputs(T)
    () -> begin
        r,u = new_identify(P.edgelist,np,lp,Set{Int64}(P.sources),fk,jn,P.anc,P.desc,P.itersets)
        update_beliefs_iterative(P.edgelist,P.itersets,P.outgoing,P.incoming,P.sources,np,lp,P.desc,P.anc,r,jn,fk,u,mkcache(T))
    end
end

# structural numbers (definite) for the grid, config A
let (np,lp) = inputs(Float64)
    r,u = new_identify(P.edgelist,np,lp,Set{Int64}(P.sources),fk,jn,P.anc,P.desc,P.itersets)
    conds=[length(d.diamond.conditioning_nodes) for d in values(u)]
    cache=Dict{CacheKey,DiamondCacheEntry{Float64}}()
    update_beliefs_iterative(P.edgelist,P.itersets,P.outgoing,P.incoming,P.sources,np,lp,P.desc,P.anc,r,jn,fk,u,cache)
    global GRID_NDIA=length(conds); global GRID_MAXC=isempty(conds) ? 0 : maximum(conds); global GRID_OPS=length(cache)+1
end

# ---- attribution helpers (no inline break/elseif; use early-return classify) ----
isPBA(f)=occursin("ProbabilityBoundsAnalysis",f); isIPA(f)=occursin("InfoPropFrmwrk",f)||occursin("InformationPropagation",f)
function classify(frames)
    for fr in frames
        f=String(fr.file)
        isPBA(f) && return "PBA"
        isIPA(f) && return "IPA"
    end
    return "other"
end
function bucket_time()
    data, ld = Profile.retrieve()
    tally=Dict("PBA"=>0,"IPA"=>0,"other"=>0); n=0; s=Vector{Any}()
    function flush_sample()
        isempty(s) && return
        lbl="other"
        for p in s
            frs=get(ld,p,nothing); frs===nothing && continue
            c=classify(frs); (c!="other") && (lbl=c; break)
        end
        tally[lbl]+=1; n+=1; empty!(s)
    end
    for ip in data
        ip==0 ? flush_sample() : push!(s,ip)
    end
    tally, n
end
function bucket_allocs(res)
    tally=Dict("PBA"=>0,"IPA"=>0,"other"=>0)
    for a in res.allocs; tally[classify(a.stacktrace)] += a.size; end
    tally
end
pct(d,k)= 100*d[k]/max(1,sum(values(d)))

open(joinpath(DAT,"grid_cost.csv"),"w") do io
    @printf(io,"# grid config A: n_diamonds=%d maxcond=%d measured_ops=%d\n", GRID_NDIA, GRID_MAXC, GRID_OPS)
    println(io,"type,median_ms,memory_MiB,allocs")
    # p-box@800 dropped on the grid: ~9 min/run (p-box@200 is ~35s, ~quadratic). @50/@200 give the scaling;
    # the @800 tightness point lives in the small-graph steps curve (pbox_steps_scaling).
    for (nm,T,steps,ns) in (("Float64",Float64,0,100),("Interval",Interval,0,100),
                            ("pbox@50",pbox,50,5),("pbox@200",pbox,200,3))
        run=mkrun(T,steps); run()                            # warmup
        b = @benchmark ($run)() samples=ns seconds=400 evals=1
        @printf(io,"%s,%.3f,%.3f,%d\n", nm, median(b).time/1e6, b.memory/2^20, b.allocs); flush(io)
        @printf("BENCH %-9s median=%.3f ms  mem=%.2f MiB  allocs=%d\n", nm, median(b).time/1e6, b.memory/2^20, b.allocs); flush(stdout)
    end
end

open(joinpath(NOTES,"profile_breakdown.md"),"w") do io
    println(io,"# Grid cost profiling — IPA vs PBA (empirical complexity confirmation)\n")
    @printf(io,"Grid (paper config A, nodes 1.0 / links 0.9). Structural: n_diamonds=%d, maxcond=%d, measured_ops=%d.\n", GRID_NDIA, GRID_MAXC, GRID_OPS)
    println(io,"Attribution = per-sample leaf-first source-file bucketing.\n")
    for (nm,T,steps,iters,arate) in (("pbox@200",pbox,200,1,0.002),("Interval",Interval,0,200,0.1))
        run=mkrun(T,steps); run()
        Profile.clear(); Profile.@profile (for _ in 1:iters; run(); end)
        tt,ns = bucket_time()
        Allocs.clear(); Allocs.@profile sample_rate=arate run()
        aa = bucket_allocs(Allocs.fetch())
        println(io,"\n## $nm")
        @printf(io,"- TIME  (%d samples): PBA %.1f%% | IPA %.1f%% | other(Base/GC) %.1f%%\n", ns, pct(tt,"PBA"),pct(tt,"IPA"),pct(tt,"other"))
        @printf(io,"- ALLOC (sampled)   : PBA %.1f%% | IPA %.1f%% | other %.1f%%  (%.1f MiB sampled)\n", pct(aa,"PBA"),pct(aa,"IPA"),pct(aa,"other"), sum(values(aa))/2^20)
        @printf("PROFILE %-9s TIME PBA=%.0f%% IPA=%.0f%% other=%.0f%% | ALLOC PBA=%.0f%% IPA=%.0f%%\n", nm, pct(tt,"PBA"),pct(tt,"IPA"),pct(tt,"other"),pct(aa,"PBA"),pct(aa,"IPA")); flush(stdout)
    end
    println(io,"\n_For p-box, %%-time in PBA quantifies the 2^|C_d| conditioning-state convolution cost; IPA%% is\nthe diamond identification + belief bookkeeping. 'other' = Base array/GC not inside a PBA/IPA frame._")
end
println("# done -> grid_case_study/data/grid_cost.csv , notes/profile_breakdown.md")
