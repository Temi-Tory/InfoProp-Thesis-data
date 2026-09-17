# TIGHTNESS-ENVELOPE sweep on the GRID, FRECHET operator (cvxF, provably sound) -- identical to
# grid_envelope.jl (same network, same regime sweep) except PBOX_COND_BLEND is pinned to :frechet instead
# of the framework default :positive. Purpose: check whether the manuscript's "all headline claims use
# only the provable Frechet-based bound" statement holds if that operator is actually used, since neither
# grid_envelope.jl nor certified_bound_vignette.jl ever set this and both therefore ran under the default
# (cvxP, empirically validated but not proven). Output -> data/grid_envelope_frechet.csv (separate file;
# does not overwrite the cvxP data, which is still the empirically-validated-tighter result).
const REPO = raw"c:\Users\ohian\OneDrive - University of Strathclyde\Documents\Programmming Files\Julia Files\InformationPropagation\Info_Prop_Framework_Project"
using Pkg; Pkg.activate(REPO); push!(LOAD_PATH, joinpath(REPO,"validation","bddenv"))
include(joinpath(REPO,"InfoPropFrmwrk","src","Algorithms","InfoPropFramework.jl")); using .InfoPropFramework
using Random, Printf, Distributions
include(joinpath(REPO,"validation","graph_gen.jl")); include(joinpath(REPO,"validation","oracles.jl"))
InfoPropFramework.InputProcessingModule.PBOX_COND_BLEND[] = :frechet
@assert InfoPropFramework.InputProcessingModule.PBOX_COND_BLEND[] == :frechet
quiet(f)=redirect_stdout(f, devnull)
glo(c)=hasproperty(c,:lo) ? glo(c.lo) : Float64(c); ghi(c)=hasproperty(c,:hi) ? ghi(c.hi) : Float64(c)
PBA.setSteps(50)
const STEPS = 50
mkdist(kind,v,w) = begin
    a=max(0.0,v-w); b=min(1.0,v+w)
    kind==:uni  ? Uniform(a,b) :
    kind==:skew ? TriangularDist(a,b, a+0.25*(b-a)) :
                  TriangularDist(a,b, clamp(v,a,b))
end
pbfromdist(d) = (qs=quantile.(d,[(i-0.5)/STEPS for i in 1:STEPS]); PBA.pbox(qs,qs))
ONEPB() = PBA.makepbox(PBA.interval(1.0,1.0))

g = load_edges("grid", joinpath(REPO,"dag_ntwrk_files","grid-graph","grid-graph.EDGES"))
P = make_problem(g); fk,jn = identify_fork_and_join_nodes(P.outgoing,P.incoming); TGT=16

function run(kind, w, perfect; N=6000)
    dl = mkdist(kind, 0.9, w)
    np = perfect ? Dict{Int64,pbox}(n=>ONEPB() for n in P.all_nodes) :
                   Dict{Int64,pbox}(n=>pbfromdist(mkdist(kind,0.7,w)) for n in P.all_nodes)
    lp = Dict{Tuple{Int64,Int64},pbox}(e=>pbfromdist(dl) for e in keys(P.eid))
    bel = quiet() do
        r,u=new_identify(P.edgelist,np,lp,Set{Int64}(P.sources),fk,jn,P.anc,P.desc,P.itersets)
        update_beliefs_iterative(P.edgelist,P.itersets,P.outgoing,P.incoming,P.sources,np,lp,P.desc,P.anc,r,jn,fk,u,Dict{CacheKey,DiamondCacheEntry{pbox}}())
    end
    rng=MersenneTwister(42); samp=Float64[]; dn = perfect ? nothing : mkdist(kind,0.7,w)
    for _ in 1:N
        npf=Dict{Int64,Float64}(n=> dn===nothing ? 1.0 : rand(rng,dn) for n in P.all_nodes)
        lpf=Dict{Tuple{Int64,Int64},Float64}(e=>rand(rng,dl) for e in keys(P.eid))
        r,u=new_identify(P.edgelist,npf,lpf,Set{Int64}(P.sources),fk,jn,P.anc,P.desc,P.itersets)
        b=update_beliefs_iterative(P.edgelist,P.itersets,P.outgoing,P.incoming,P.sources,npf,lpf,P.desc,P.anc,r,jn,fk,u); push!(samp,b[TGT])
    end
    sort!(samp); emp(x)=count(<=(x),samp)/length(samp); u=0.0; bd=0.0
    for x in 0.0:0.02:1.0; c=PBA.cdf(bel[TGT],x); u=max(u,glo(c)-emp(x),emp(x)-ghi(c)); bd=max(bd,ghi(c)-glo(c)); end
    (max(u,0.0), bd, samp[1], samp[end])
end

open(joinpath(REPO,"InfoPropFrmwrk","Publications","My work","RESS_response","data","grid_envelope_frechet.csv"),"w") do io
    println(io,"distribution,regime,width,unsound,band,mc_lo,mc_hi,status")
    for kind in (:tri,:uni,:skew), perfect in (true,false), w in (0.05,0.10,0.15)
        u,bd,lo,hi = run(kind,w,perfect)
        reg = perfect ? "perfect" : "uncert0.7"
        st = u<0.03 ? "sound" : "UNSOUND"
        @printf(io,"%s,%s,%.2f,%.3f,%.3f,%.3f,%.3f,%s\n", kind, reg, w, u, bd, lo, hi, st); flush(io)
        @printf("%-5s %-9s w=%.2f  unsound=%.3f band=%.2f  %s\n", kind, reg, w, u, bd, st); flush(stdout)
    end
end
println("# done -> data/grid_envelope_frechet.csv")
