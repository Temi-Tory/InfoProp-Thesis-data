# CERTIFIED-BOUND vignette, FRECHET operator (cvxF, provably sound) -- identical to
# certified_bound_vignette.jl (same grid network, same scenarios, x*=0.95) except PBOX_COND_BLEND is
# pinned to :frechet instead of the framework default :positive. See grid_envelope_frechet.jl for why this
# check matters. Output -> data/certified_bound_vignette_frechet.csv (separate file, does not overwrite
# the cvxP data).
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
const XSTAR = 0.95
const Z = 1.96

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
    (bel[TGT], samp)
end

function certify(bel, samp; xstar=XSTAR)
    c = PBA.cdf(bel, xstar); a,b = glo(c), ghi(c)
    band = max(b-a, 0.0)
    phat = count(<=(xstar), samp)/length(samp)
    halfwidth = band/2
    if halfwidth < 1e-9
        Nworst = Nphat = -1
    else
        Nworst = ceil(Int, Z^2*0.25/halfwidth^2)
        Nphat  = ceil(Int, Z^2*phat*(1-phat)/halfwidth^2)
    end
    (a,b,band,phat,Nworst,Nphat)
end

scenarios = [(kind,w,perfect) for kind in (:tri,), w in (0.05,0.10,0.15), perfect in (true,false)]

open(joinpath(REPO,"InfoPropFrmwrk","Publications","My work","RESS_response","data","certified_bound_vignette_frechet.csv"),"w") do io
    println(io,"distribution,regime,width,threshold,ipa_lo,ipa_hi,ipa_band,mc_N_used,mc_phat,N_required_worstcase,N_required_at_phat,bdd_note")
    for (kind,w,perfect) in scenarios
        bel,samp = run(kind,w,perfect; N=6000)
        a,b,band,phat,Nworst,Nphat = certify(bel,samp)
        reg = perfect ? "perfect" : "uncert0.7"
        @printf(io,"%s,%s,%.2f,%.2f,%.4f,%.4f,%.4f,%d,%.4f,%d,%d,%s\n",
                kind,reg,w,XSTAR,a,b,band,6000,phat,Nworst,Nphat,"n/a analytically; falls back to MC (same as mc_phat row)")
        @printf("%-5s %-9s w=%.2f  IPA:[%.3f,%.3f] certified in 1 pass (band=%.3f)  MC(N=6000): phat=%.3f  N_needed(worst)=%d  N_needed(phat)=%d\n",
                kind,reg,w,a,b,band,phat,Nworst,Nphat); flush(stdout)
    end
end
println("# done -> data/certified_bound_vignette_frechet.csv")
