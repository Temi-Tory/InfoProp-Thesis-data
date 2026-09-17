# Post-is_det-fix confirmation rerun of the 129-graph corpus behind paper_data.csv.
# 120/129 (random_nX_pY_sZ family) reconstructed EXACTLY from their own names -- fully
# deterministic (MersenneTwister(seed)) via graph_gen.jl's scaling_random, whose name format
# ("random_n$(n)_p$(...)_s$s") matches paper_data.csv's names byte-for-byte.
# counterexample-n15 loaded from its real persisted file (dag_ntwrk_files/counterexample-n15/).
# mutant_rand28_s1..s8: reconstructed under a DOCUMENTED, NOT verified-identical base+mutation
# seed choice (flagged explicitly in the output) -- the only 8/129 not guaranteed byte-identical
# to the original.
#
# Priors/link probabilities: uniform 0.9 everywhere (matching graph_gen.jl's own verify_graph
# convention) -- non-degenerate, so this corpus never exercised the is_det bug's trigger
# condition (a NON-source node at prior exactly 0 or 1) in the first place; this rerun confirms
# that claim empirically rather than leaving it as reasoning alone.
const REPO = raw"C:\Development\Info_Prop_Framework_Project\Info_Prop_Framework_Project"
using Pkg; Pkg.activate(joinpath(REPO, "InfoPropFrmwrk"))
const BDDENV = joinpath(REPO, "validation", "bddenv"); push!(LOAD_PATH, BDDENV)
include(joinpath(REPO, "InfoPropFrmwrk", "src", "Algorithms", "InfoPropFramework.jl")); using .InfoPropFramework
# Pure-Julia BDD oracle (BinaryDecisionDiagrams.jl), NOT CUDD -- CUDD demanded ~20-30GB twice
# today, including on this run's own smallest graph (n=10), pointing at a CUDD-specific
# instability in this environment right now rather than a graph-complexity problem. Avoiding it
# entirely for this rerun rather than risk a repeat of today's earlier crash.
import BinaryDecisionDiagrams as BDDjl
using Random, Printf, Dates
include(joinpath(REPO, "validation", "graph_gen.jl"))
include(joinpath(REPO, "validation", "oracles.jl"))

const OLD = Dict{String,Float64}()
old_path = joinpath(REPO, "validation", "probability", "data", "paper_data.csv")
open(old_path) do io
    readline(io)  # header
    for line in eachline(io)
        parts = split(line, ',')
        name = parts[1]
        wd = tryparse(Float64, parts[13])
        wd !== nothing && (OLD[name] = wd)
    end
end
println("[$(now())] loaded ", length(OLD), " prior worst_delta values from paper_data.csv")

# --- reconstruct the 129-graph corpus ---
corpus = Tuple{String,Graph}[]
for n in (10,12,15,20,25), p in (0.1,0.15,0.2), s in 1:8
    tag = replace(string(p), "." => "")
    push!(corpus, ("random_n$(n)_p$(tag)_s$s", gen_random_dag(MersenneTwister(s); n=n, p=p)))
end
# counterexample-n15: real persisted file
ce_edgelist, ce_out, ce_in, ce_srcs = read_graph_to_dict(joinpath(REPO, "dag_ntwrk_files", "counterexample-n15", "counterexample-n15.EDGES"))
ce_n = maximum(maximum(e) for e in ce_edgelist)
push!(corpus, ("counterexample-n15", Graph(ce_n, ce_edgelist, sort(collect(ce_srcs)), "counterexample")))
# mutant_rand28_s1..s8: EXACT parameters recovered from validation/full_regression_sifted.jl
# (found after this script's first draft guessed seed=28/adds=6/dels=3 -- corrected here).
base28 = gen_random_dag(MersenneTwister(7); n=28, p=0.12)
for (nm, g) in scaling_mutants("rand28", base28; seeds=1:8, adds=5, dels=2)
    push!(corpus, (nm, g))
end

println("[$(now())] corpus reconstructed: ", length(corpus), " graphs (expect 129)")
flush(stdout)

results = NamedTuple[]
for (name, g) in corpus
    P = make_problem(g)
    D = (node_priors = Dict(n => 0.9 for n in P.all_nodes), link_probs = Dict(e => 0.9 for e in keys(P.eid)))
    w = zeros(Float64, P.V)
    for n in P.all_nodes; w[P.nid[n]] = D.node_priors[n]; end
    for (e,i) in P.eid; w[i] = D.link_probs[e]; end

    # new_identify is the ONLY current, correct diamond identifier (identify_and_group_diamonds /
    # build_unique_diamond_storage_depth_first_parallel -- what oracles.jl's ipa_structure/
    # ipa_propagate call -- are explicitly RETIRED/buggy per DiamondDecompositionModule.jl's own
    # export comment; NOT used here for exactly that reason).
    fork_nodes, join_nodes = identify_fork_and_join_nodes(P.outgoing, P.incoming)
    root_diamonds, unique_diamonds = new_identify(P.edgelist, D.node_priors, D.link_probs, Set(P.sources), fork_nodes, join_nodes, P.anc, P.desc, P.itersets)
    bel = update_beliefs_iterative(P.edgelist, P.itersets, P.outgoing, P.incoming, Set(P.sources), D.node_priors, D.link_probs, P.desc, P.anc, root_diamonds, join_nodes, fork_nodes, unique_diamonds)

    B = bddjl_build(P)
    oracle = bddjl_eval(B, P, w)
    worst_delta = maximum(abs(bel[n] - oracle[n]) for n in P.all_nodes)

    old_wd = get(OLD, name, NaN)
    push!(results, (name=name, V=P.V, E=length(g.edges), worst_delta=worst_delta, old_worst_delta=old_wd))
end

# Save raw results to CSV FIRST, before any summary/reporting code runs -- so a bug in the
# reporting (as happened on the first attempt: a top-level for-loop soft-scope issue) can never
# lose the actual 11+ minutes of computation again.
out_csv = joinpath(REPO, "validation", "probability", "rerun_129_corpus_results.csv")
open(out_csv, "w") do io
    println(io, "name,V,E,worst_delta,old_worst_delta")
    for r in results
        @printf(io, "%s,%d,%d,%.6e,%.6e\n", r.name, r.V, r.E, r.worst_delta, r.old_worst_delta)
    end
end
println("[$(now())] wrote ", out_csv)

function summarize(results)
    n_changed = 0
    n_ok = 0
    for r in results
        changed = !isnan(r.old_worst_delta) && abs(r.worst_delta - r.old_worst_delta) > 1e-9
        changed && (n_changed += 1)
        (r.worst_delta < 1e-6) && (n_ok += 1)
        changed && @printf("  CHANGED: %-24s old=%.3e new=%.3e\n", r.name, r.old_worst_delta, r.worst_delta)
    end
    @printf("\n[%s] %d/%d graphs exact (worst_delta < 1e-6); %d/%d changed vs prior paper_data.csv (tol 1e-9)\n",
            now(), n_ok, length(results), n_changed, length(results))
end

println("[$(now())] === RESULTS ===")
summarize(results)
println("[$(now())] done")
