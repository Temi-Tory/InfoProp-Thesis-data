# Point-by-point reviewer response — evidence map
Status tags: [DONE] concrete new evidence exists (file/number below) · [WRITE] paper-writing only ·
[FUTURE] out of current scope. Validation code + numbers live in `Info_Prop_Framework_Project/validation/`.

## Cross-cutting reframing (state once, up front)
The dPrPm reference implementation is unavailable and its authors unreachable, so it cannot serve as a
reproducible validation baseline. We therefore validate IPA against an INDEPENDENT, OPEN, EXACT oracle —
a canonical reduced-ordered BDD (CUDD, in-process, same language) — across a broad corpus, and we release
the full IPA implementation and validation harness. dPrPm is retained only as a secondary, explicitly
caveated comparison. (Answers R2.1, R2.2, R2.3, R3.2 together.)

IMPORTANT correctness note: the paper's benchmark 16-node grid (sources 1,3,13) is our `grid-graph`. During
hardening we found the previous diamond-identification produced WRONG reliabilities on this exact network
(max node error 3.3e-3 at nodes 7,8,11,15), root-caused it (a context/hkey collision in reconvergent
grids), and fixed it. Corrected IPA now matches the exact ROBDD to 1.1e-16. => the published grid table
must be re-checked/updated against the corrected exact values.

## Reviewer #2
- **R2.1 Limited benchmarks (single 16-node).** [DONE] Corpus now: 129 random+mutant DAGs (n=4..~130,
  density 0.05–0.46, 2 probability vectors) + 6 topological families {multi-source, grid/lattice,
  layered/k-partite, bridge (non-series-parallel), series-parallel, complete} + larger n=30–50 + real
  infrastructure {power, grid, KarlNetwork, drone, metro, munin} + adversarial {fanin-k, mesh-w}. All
  exact vs sifted BDD. Files: `full_regression_sifted.jl`, `families_validate.jl`, `large_graphs.jl`.
- **R2.2 Runtime not controlled (published numbers).** [DONE] In-process, same-language IPA-vs-CUDD timing
  + peak RAM (`perf_compare.jl`). No dependence on published dPrPm runtimes.
- **R2.3 No comparison to exact methods (BDD).** [DONE] Quantitative CUDD comparison, naive AND sifted
  ordering: ROBDD node counts (sifted median 489, max 20 323), build/eval time, peak RAM, per-node
  exactness (worst 1.1e-16). Files: `cudd_intractable.jl`, `perf_compare.jl`, `paper_tables.tex`.
- **R2.4 Complexity qualitative.** [DONE/WRITE] Treewidth framing: sifted BDD ≈ 2^pathwidth, IPA ≈
  2^(conditioning-nesting) ≥ that; measured op-counts; fanin-k worst case 2^k (→ 2k+1 with factorization);
  density sweep shows both ~2^width. Honest: BDD ≥ IPA on every family tested. `treewidth_sweep.jl`,
  `adversarial_scaling.jl`, `paper_adversarial.tex`. (Write the derivation formally.)
- **R2.5 Drone case lacks reliability insight.** [WRITE] IPA already produces per-node reliabilities +
  imprecise bounds for the drone networks; add engineering interpretation / decision-support narrative.
- **R2.6 Scalability (depth 16–18).** [DONE/WRITE] Two parts, kept distinct:
  (i) [DONE] State the practical EXACT range empirically — full-exact IPA is fast up to conditioning/
  nesting depth ~D (cost grows 2^depth beyond); factorization removes IPA's self-inflicted 2^k on
  independent structure, widening D. (ii) [FUTURE] For graphs deeper than D, a depth-limited HYBRID
  (condition exactly to depth D, stop beyond) would trade exactness for tractability. NOTE: this is a
  PROPOSED fallback, not the method, and NOT implemented. The everyday method does not degrade: full
  interval IPA is EXACT (machine precision, by construction) and full p-box IPA is sound + discretisation-
  tight. Only the opt-in hybrid loosens — and there, interval gives a rigorous OUTER bound (naive interval
  eval over-approximates monotone funcs, so it is sound-but-wider), whereas p-box would need Fréchet
  combination for the un-conditioned depth (independence-assuming p-box combination is UNSOUND, measured).
- **R2.7 Reproducibility of Algorithm 1.** [DONE] Correct, fully-specified, open `new_identify`
  (`DiamondDecomposition/Internal/NewIdentify.jl`) + `rc_core.jl` reference + validation harness;
  diamond identification, conditioning-set selection (context-aware), and supernode caching all explicit.
- **R2.8 Editorial.** [WRITE].

## Reviewer #3
- **R3.1 Compare to Cutset Conditioning / Junction Tree.** [DONE/WRITE] Treewidth analysis positions IPA
  as cutset conditioning specialized to source-to-node reachability, achieving the same ~2^treewidth bound
  as junction-tree inference; independent-diamond factorization is the specialization that avoids
  conditioning on independent shared forks jointly. Write the formal comparison.
- **R3.2 Benchmark vs exact solvers (BDD) on same grid/drone.** [DONE] CUDD on the grid benchmark
  (= our grid-graph) and corpus; drone via CUDD where tractable + MC beyond. See R2.3.
- **R3.3 DAG transformation of bidirectional multiplex.** [WRITE/FUTURE] Justify the level-ordering
  restriction; note IPA is DAG-exact and cyclic/bidirectional is out of scope (future: unrolling / SCC).
- **R3.4 High-treewidth / hybrid approx+exact.** [FUTURE] The proposed hybrid is a DEPTH-LIMITED scheme:
  condition exactly to depth D, and beyond D combine reconvergent parents without conditioning to get a
  rigorous BOUND (interval: sound outer bound; p-box: via Fréchet). NOTE — full imprecise IPA is NOT itself
  cheaper than exact: it uses the SAME conditioning depth, so it does not by itself solve deep nesting; the
  cost saving comes only from CAPPING the depth. Not implemented — future work. (Do not claim imprecise
  propagation as a free scalability fix.)

## Reviewer (detailed / R1-style)
- **t1 Detailed pseudocode + multi-level nested example.** [DONE/WRITE] `new_identify` is precise;
  worked multi-level examples validated (`pbox_test2.jl` node-6 two-fork case; grid). Add to paper.
- **t2 Supernode maps storage/query; overlapping diamonds / shared conditioning; cache explosion.** [DONE]
  computation_lookup keyed by context-aware `create_diamond_hash_key`; overlapping diamonds & shared
  conditioning are exactly the collision we fixed; factorization + zero-weight skip prevent explosion.
- **t3 Prove Lemma 4.1/4.2 (conditional invariance, supernode equivalence).** [DONE(constructive)/WRITE]
  `rc_core.jl` is a constructive proof of conditional invariance (exact total probability); formalize.
- **t4 Overlapping/non-hierarchical diamonds, no info loss/cycles.** [DONE] Context-aware conditioning +
  factorization; the grid bug was precisely this — now correct (0 wrong on 129 + families).
- **t5 Complexity tighter bounds.** [DONE/WRITE] See R2.4 (treewidth).
- **t6 Drone DAG transparency (probs from distances, levels, bidirectional).** [WRITE].
- **t7 Figures high-quality + captions.** [WRITE] Artifacts in `paper_{tables,figures,adversarial,imprecise}.tex`.
- **t8 Broader applicability (Bayesian nets) / limitations.** [DONE/WRITE] PGM/junction-tree connection
  (R3.1); NEW capability = exact imprecise (interval/p-box) reliability, which BDD/PGM engines don't do
  natively.

## NEW contribution to foreground (not in the original submission)
Exact IMPRECISE reliability: with interval inputs IPA returns the exact belief range (machine precision,
129/129 graphs); with p-box inputs it returns sound, discretisation-tight bounds. Naive
independence-assuming propagation is UNSOUND on reconvergent networks (interval over-width up to 0.45;
p-box CDF error 0.12–0.42). BDDs cannot propagate imprecise inputs natively. Files: `paper_imprecise.tex`,
`interval_sweep.jl`, `pbox_test*.jl`, `PBOX_ANALYSIS.md`.
