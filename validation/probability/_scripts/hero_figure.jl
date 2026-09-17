# Data for the imprecise-reliability HERO figure: belief-CDF of a sink node under uniform input
# distributions, showing (a) Monte-Carlo empirical CDF (truth), (b) IPA p-box band (tight, sound),
# (c) NAIVE p-box band (no conditioning -> unsound/wrong). Chosen graph: random_n12_s3 (naive fails
# badly). steps=200 for a tight IPA band. Outputs CSV: x, emp_cdf, ipa_lo, ipa_hi, naive_lo, naive_hi.
const REPO = raw"c:\Users\ohian\OneDrive - University of Strathclyde\Documents\Programmming Files\Julia Files\InformationPropagation\Info_Prop_Framework_Project"
using Pkg; Pkg.activate(REPO); push!(LOAD_PATH, joinpath(REPO,"validation","bddenv"))
include(joinpath(REPO,"InfoPropFrmwrk","src","Algorithms","InfoPropFramework.jl")); using .InfoPropFramework
using Random, Printf
include(joinpath(REPO,"validation","graph_gen.jl")); include(joinpath(REPO,"validation","oracles.jl"))
PBA.setSteps(200)
glo(c)=hasproperty(c,:lo) ? glo(c.lo) : Float64(c); ghi(c)=hasproperty(c,:hi) ? ghi(c.hi) : Float64(c)

g=gen_random_dag(MersenneTwister(3); n=12, p=0.2); P=make_problem(g); target=12
rng=MersenneTwister(1); box=Dict{Any,Tuple{Float64,Float64}}()
for n in P.all_nodes; b=0.4+0.4*rand(rng); box[n]=(max(0.0,b-0.15),min(1.0,b+0.15)); end
for e in keys(P.eid); b=0.4+0.4*rand(rng); box[e]=(max(0.0,b-0.15),min(1.0,b+0.15)); end
fk,jn=identify_fork_and_join_nodes(P.outgoing,P.incoming)
pb(naive)=begin
    np=Dict{Int64,pbox}(n=>PBA.uniform(box[n]...) for n in P.all_nodes); lp=Dict{Tuple{Int64,Int64},pbox}(e=>PBA.uniform(box[e]...) for e in keys(P.eid))
    roots,uniq= naive ? (Dict{Int64,Vector{DiamondsAtNode}}(),Dict{UInt64,DiamondComputationData{pbox}}()) : new_identify(P.edgelist,np,lp,Set{Int64}(P.sources),fk,jn,P.anc,P.desc,P.itersets)
    update_beliefs_iterative(P.edgelist,P.itersets,P.outgoing,P.incoming,P.sources,np,lp,P.desc,P.anc,roots,jn,fk,uniq,Dict{CacheKey,DiamondCacheEntry{pbox}}())
end
ipa=pb(false); nai=pb(true)
r=MersenneTwister(42); samp=Float64[]
for _ in 1:100000
    np=Dict{Int64,Float64}(n=>box[n][1]+(box[n][2]-box[n][1])*rand(r) for n in P.all_nodes); lp=Dict{Tuple{Int64,Int64},Float64}(e=>box[e][1]+(box[e][2]-box[e][1])*rand(r) for e in keys(P.eid))
    roots,uniq=new_identify(P.edgelist,np,lp,Set{Int64}(P.sources),fk,jn,P.anc,P.desc,P.itersets)
    bel=update_beliefs_iterative(P.edgelist,P.itersets,P.outgoing,P.incoming,P.sources,np,lp,P.desc,P.anc,roots,jn,fk,uniq); push!(samp,bel[target])
end
sort!(samp); emp(x)=count(<=(x),samp)/length(samp)
open(joinpath(REPO,"validation","hero_figure.csv"),"w") do io
    println(io,"x,emp_cdf,ipa_lo,ipa_hi,naive_lo,naive_hi")
    for x in 0.0:0.01:0.6
        ci=PBA.cdf(ipa[target],x); cn=PBA.cdf(nai[target],x)
        @printf(io,"%.3f,%.4f,%.4f,%.4f,%.4f,%.4f\n", x, emp(x), glo(ci),ghi(ci), glo(cn),ghi(cn))
    end
end
@printf("wrote hero_figure.csv  MC belief(%d) range=[%.3f,%.3f]\n", target, samp[1], samp[end])
