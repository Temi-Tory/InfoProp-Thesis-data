# Make IPA's complexity DEFINITE, not qualitative. Per-instance cost model:
#     Work(IPA) <= sum over unique diamonds d of  2^|C_d| * O(|E_d|)   (equality absent memoisation),
# where C_d = diamond d's conditioning set (computed by new_identify), E_d = its edgelist.
# For each graph we compute the STRUCTURAL prediction directly from new_identify's unique-diamond store
# and compare to the MEASURED work (distinct sub-propagations = cache size) and to the sifted-ROBDD node
# count. Claims validated: (1) measured ops <= sum 2^|C_d| (memoisation never exceeds enumeration);
# (2) maxcond = max|C_d| is the exact conditioning width and tracks log2(bdd_nodes) ~ graph width.
# All nodes & links = 0.9 (all-uncertain => full diamond structure, no is_det pruning).
const REPO = raw"c:\Users\ohian\OneDrive - University of Strathclyde\Documents\Programmming Files\Julia Files\InformationPropagation\Info_Prop_Framework_Project"
using Pkg; Pkg.activate(REPO); push!(LOAD_PATH, joinpath(REPO,"validation","bddenv"))
include(joinpath(REPO,"InfoPropFrmwrk","src","Algorithms","InfoPropFramework.jl")); using .InfoPropFramework
using CUDD, Random, Printf
include(joinpath(REPO,"validation","graph_gen.jl")); include(joinpath(REPO,"validation","oracles.jl"))
include(joinpath(REPO,"validation","graph_families.jl"))
include(joinpath(REPO,"validation","bdd_oracle.jl")); using .BDDReliabilityOracle

function analyze(nm, g)
    P=make_problem(g); fk,jn=identify_fork_and_join_nodes(P.outgoing,P.incoming)
    np=Dict{Int64,Float64}(n=>0.9 for n in P.all_nodes); lp=Dict{Tuple{Int64,Int64},Float64}(e=>0.9 for e in keys(P.eid))
    r,u=new_identify(P.edgelist,np,lp,Set{Int64}(P.sources),fk,jn,P.anc,P.desc,P.itersets)
    conds=[length(d.diamond.conditioning_nodes) for d in values(u)]
    edgs =[length(d.diamond.edgelist)          for d in values(u)]
    ndia=length(conds); maxc = isempty(conds) ? 0 : maximum(conds)
    sum2C = isempty(conds) ? 0.0 : sum(2.0^c for c in conds)
    work  = isempty(conds) ? 0.0 : sum(2.0^conds[i]*edgs[i] for i in 1:ndia)
    cache=Dict{CacheKey,DiamondCacheEntry{Float64}}()
    update_beliefs_iterative(P.edgelist,P.itersets,P.outgoing,P.incoming,P.sources,np,lp,P.desc,P.anc,r,jn,fk,u,cache)
    ipaops=length(cache)+1
    _,st = bdd_reliability(collect(P.edgelist), Dict(Int(n)=>0.9 for n in P.all_nodes),
                           Dict{Tuple{Int,Int},Float64}(e=>0.9 for e in keys(P.eid)), collect(P.sources); sift=true)
    (nm, length(P.all_nodes), length(g.edges), ndia, maxc, sum2C, work, ipaops, st.bdd_total_nodes)
end

graphs = Tuple{String,Graph}[
  ("grid_4x4", load_edges("grid",joinpath(REPO,"dag_ntwrk_files","grid-graph","grid-graph.EDGES"))),
  ("grid_5x5", gen_grid(5,5)),
  ("counterexample", load_edges("cex",joinpath(REPO,"dag_ntwrk_files","counterexample-n15","counterexample-n15.EDGES"))),
  ("bridge_5", gen_bridge(5)), ("complete_8", gen_complete(8)),
  ("layered_5x4", gen_layered(MersenneTwister(2); layers=5, width=4, p=0.5)),
]
for n in (12,15,20,25), s in 1:2; push!(graphs, ("random_n$(n)_s$s", gen_random_dag(MersenneTwister(s); n=n, p=0.15))); end

open(joinpath(REPO,"InfoPropFrmwrk","Publications","My work","RESS_response","data","complexity_validation.csv"),"w") do io
    println(io,"name,V,E,n_diamonds,maxcond,sum_2^C,work_2^C*E,measured_ops,bdd_nodes")
    println("name,V,E,ndia,maxc,sum2C,work,measured_ops,bdd_nodes,check")
    for (nm,g) in graphs
        row = analyze(nm,g)
        @printf(io,"%s,%d,%d,%d,%d,%.0f,%.0f,%d,%d\n", row...)
        ok = row[8] <= row[6]+1e-9   # measured_ops <= sum 2^C
        @printf("%-16s V=%-3d E=%-3d ndia=%-3d maxc=%-2d sum2C=%-8.0f work=%-9.0f ops=%-5d bdd=%-6d %s\n",
                row[1],row[2],row[3],row[4],row[5],row[6],row[7],row[8],row[9], ok ? "ops<=sum2C ok" : "!! ops>sum2C")
        flush(io); flush(stdout)
    end
end
println("# done -> data/complexity_validation.csv")
