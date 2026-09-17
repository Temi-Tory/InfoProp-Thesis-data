# Section 3 item 4 of the probability data-pack requirements: ASCE power-network reproduction
# (Tong & Tien, ASCE-ASME J. Risk Uncertainty Eng. Syst. A, 5(3):04019011, Fig. 11 / Table 5),
# under the CORRECT pure uniform-R_l scheme (no RESS-style reliable-link machinery -- that
# framing was used by mistake earlier in this session and is not repeated here). Resolves the
# 27-vs-28-edge question cleanly: runs the AS-IS 27-edge corpus graph AND a 28-edge candidate
# (adding (17,22), the only edge tested earlier -- under the WRONG framing -- as a possible
# missing link) side by side, at all three published R_l values, and reports which is closer.
#
# Node 23 is the sink (confirmed: outdegree 0, matches "sink node is Node 23", Fig. 11).
# Sources = {1,7,18} (confirmed: indegree 0, matches "three source nodes").
# Node priors = 1.0 everywhere (nodes are perfectly reliable in this paper's model; only edges
# carry R_l) -- same convention as asce_grid_reproduction.jl (Section 3 item 3, already verified
# essentially exact against Tables 2/3 under this same convention).
# Cross-checked against a pure-Julia BDD oracle (BinaryDecisionDiagrams.jl, not CUDD) for
# exactness confidence, same pattern as the 129-graph corpus rerun (item 1).
const REPO = raw"C:\Development\Info_Prop_Framework_Project\Info_Prop_Framework_Project"
using Pkg; Pkg.activate(joinpath(REPO, "InfoPropFrmwrk"))
include(joinpath(REPO, "InfoPropFrmwrk", "src", "Algorithms", "InfoPropFramework.jl")); using .InfoPropFramework
const BDDENV = joinpath(REPO, "validation", "bddenv"); push!(LOAD_PATH, BDDENV)
import BinaryDecisionDiagrams as BDDjl
using Printf
include(joinpath(REPO, "validation", "graph_gen.jl"))
include(joinpath(REPO, "validation", "oracles.jl"))

edgelist27, _, _, sources_set = read_graph_to_dict(joinpath(REPO, "dag_ntwrk_files", "power-network", "power-network.EDGES"))
n = maximum(maximum(e) for e in edgelist27)
sources = sort(collect(sources_set))
println("baseline: n=$n edges=", length(edgelist27), " sources=", sources)

edgelist28 = vcat(edgelist27, [(17,22)])
println("candidate: n=$n edges=", length(edgelist28), " sources=", sources, " (+ (17,22))")

published = Dict(0.9 => 0.85741, 0.99 => 0.98969, 0.3 => 0.00221)

function run_graph(edges, n, sources, label)
    g = Graph(n, edges, sources, label)
    P = make_problem(g)
    fork_nodes, join_nodes = identify_fork_and_join_nodes(P.outgoing, P.incoming)
    results = Dict{Float64,NamedTuple}()
    for Rl in (0.9, 0.99, 0.3)
        node_priors = Dict(nd => 1.0 for nd in P.all_nodes)
        link_probability = Dict(e => Rl for e in P.edgelist)
        root_diamonds, unique_diamonds = new_identify(P.edgelist, node_priors, link_probability, Set(P.sources), fork_nodes, join_nodes, P.anc, P.desc, P.itersets)
        beliefs = update_beliefs_iterative(P.edgelist, P.itersets, P.outgoing, P.incoming, Set(P.sources), node_priors, link_probability, P.desc, P.anc, root_diamonds, join_nodes, fork_nodes, unique_diamonds)

        w = zeros(Float64, P.V)
        for nd in P.all_nodes; w[P.nid[nd]] = 1.0; end
        for (e,i) in P.eid; w[i] = Rl; end
        B = bddjl_build(P)
        oracle = bddjl_eval(B, P, w)

        sink = maximum(P.all_nodes)
        ipa_val = beliefs[sink]
        bdd_val = oracle[sink]
        pub = published[Rl]
        results[Rl] = (ipa=ipa_val, bdd=bdd_val, ipa_vs_bdd=abs(ipa_val-bdd_val), pub=pub, diff_vs_pub=abs(ipa_val-pub))
    end
    return results
end

println()
println("=== baseline (27 edges, as-is) ===")
r27 = run_graph(edgelist27, n, sources, "power-baseline")
for Rl in (0.9, 0.99, 0.3)
    r = r27[Rl]
    @printf("  R_l=%.2f  IPA=%.5f  BDD=%.5f  |IPA-BDD|=%.2e  published=%.5f  |IPA-published|=%.5f\n",
            Rl, r.ipa, r.bdd, r.ipa_vs_bdd, r.pub, r.diff_vs_pub)
end

println()
println("=== candidate (28 edges, +(17,22)) ===")
r28 = run_graph(edgelist28, n, sources, "power-candidate28")
for Rl in (0.9, 0.99, 0.3)
    r = r28[Rl]
    @printf("  R_l=%.2f  IPA=%.5f  BDD=%.5f  |IPA-BDD|=%.2e  published=%.5f  |IPA-published|=%.5f\n",
            Rl, r.ipa, r.bdd, r.ipa_vs_bdd, r.pub, r.diff_vs_pub)
end

println()
println("=== verdict: does adding (17,22) move IPA closer to published, per R_l? ===")
for Rl in (0.9, 0.99, 0.3)
    d27 = r27[Rl].diff_vs_pub
    d28 = r28[Rl].diff_vs_pub
    verdict = d28 < d27 ? "CLOSER (28-edge better)" : (d28 > d27 ? "WORSE (27-edge better)" : "NO CHANGE")
    @printf("  R_l=%.2f  27-edge diff=%.5f  28-edge diff=%.5f  -> %s\n", Rl, d27, d28, verdict)
end
println("\ndone")
