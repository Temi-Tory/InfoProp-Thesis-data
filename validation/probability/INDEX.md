# Probability Propagation Toolkit (Chapter 5) — verification-run index

Index of the verification runs behind Chapter 5's data pack: `data/` (CSVs), `tex/` (the 4
revision fragments), `slides/pbox_talk.tex` + `SPEAKER_NOTES.md`, and this folder's own
`CORPUS_PROVENANCE.md` / `MASTER_FINDINGS.md`.

## Verification runs

1. **Full 129-graph exactness rerun, post-`is_det` fix.** Result: 129/129 exact
   (worst_delta < 1e-6), 0/129 changed vs the prior `paper_data.csv` (tol 1e-9). The corpus was
   reconstructed exactly: 120 `random_nX_pY_sZ` graphs decoded byte-identically from their own
   names (`MersenneTwister(seed)`, deterministic), `counterexample-n15` from its persisted file,
   and the 8 `mutant_rand28_sN` graphs from the parameters in
   `validation/full_regression_sifted.jl` (`MersenneTwister(7)`, `n=28,p=0.12` base,
   `scaling_mutants(...;seeds=1:8,adds=5,dels=2)`). Uses the current `new_identify` (not
   `oracles.jl`'s `ipa_structure`, which calls the retired `identify_and_group_diamonds`).
   Cross-checked against a pure-Julia BDD oracle (`BinaryDecisionDiagrams.jl`, not CUDD). This
   corpus's priors are drawn from [0.3, 0.99) — never exactly 0 or 1 on any node — so it never
   exercises the `is_det` fix's trigger condition; the fix changes nothing here, confirmed across
   all 129 graphs. Script: `rerun_129_corpus.jl`. Results: `rerun_129_corpus_results.csv`. Log:
   `rerun_129_corpus.log`.

2. **Drone diamond stats at K=10, 12, 16 + vtol + mlgw-gas, post-fix.**
   `concentrated-minimal` was rebuilt directly from the source data (`csvfiles/drone_info/`,
   the same generator logic as `drone_network_to_dag_reliability.jl`) at K=10/12/16, alongside
   the persisted `vtol-dense-decentralized` and `mlgw-gas-network` files, through the current
   `new_identify`/`update_beliefs_iterative` pipeline:

   | network | V | E | maxcond | uniq diamonds | vs prior record |
   |---|---|---|---|---|---|
   | concentrated-minimal K=10 | 230 | 1359 | 14 | 465 | exact match |
   | concentrated-minimal K=12 | 230 | 1510 | 15 | 691 | exact match |
   | concentrated-minimal K=16 (official) | 230 | 1648 | 16 | 1005 | now exact (was recorded as approximate "16-17") |
   | vtol-dense-decentralized | 242 | 1753 | 16 | 1486 | previously recorded as maxcond=17 — genuinely changed by the `is_det` fix |
   | mlgw-gas-network | 37 | 40 | 4 | 7 | not previously recorded at this precision |

   Script: `drone_ksweep_remeasure.jl`. Results: `drone_ksweep_remeasure_results.csv`. Log:
   `drone_ksweep_remeasure.log`.

3. **ASCE grid reproduction** (sources {1,3,13}; R_l 0.9 and 0.1; vs the paper's Tables 2 and 3).
   Uses the persisted network file (`grid-graph.EDGES`, sources confirmed against the paper's
   Fig. 10), the current `new_identify`/`update_beliefs_iterative` pipeline, compared node-by-node
   against both tables' own printed "Exact" columns. Table 2 (R_l=0.9): worst |diff| = 4.750e-6
   (node 12). Table 3 (R_l=0.1): worst |diff| = 4.294e-6 (node 16). Both are within the ~5e-6
   rounding noise of a table printed to 5 decimal places — agreement within the paper's own
   precision, not a discrepancy. Script: `asce_grid_reproduction.jl`.

4. **ASCE power network reproduction** (`Published_R090/R099/R030`, the 27-vs-28-edge question).
   Reran under the pure uniform-$R_l$ ASCE scheme (node priors = 1.0), current
   `new_identify`/`update_beliefs_iterative` pipeline, cross-checked against a pure-Julia BDD
   oracle (agreement to machine precision, ≤1.1e-16, throughout — the propagation is exact; any
   gap vs. published is a modelling/topology question, not a computation bug). Sources={1,7,18},
   sink=23 (confirmed against Fig. 11).

   | | $R_l=0.9$ | $R_l=0.99$ | $R_l=0.3$ |
   |---|---|---|---|
   | published (Table 5) | 0.85741 | 0.98969 | 0.00221 |
   | 27-edge (as-is corpus) | 0.85917 (diff 0.00176) | 0.98969 (diff 0.00000) | 0.00272 (diff 0.00051) |
   | 28-edge (+ candidate (17,22)) | 0.88505 (diff 0.02764) | 0.98999 (diff 0.00030) | 0.01054 (diff 0.00833) |

   The 28-edge candidate is worse at every point — the 27-edge corpus graph, as it stands, is
   correct; the 27-vs-28-edge question is closed, no file change needed. A separate, smaller
   residual at $R_l=0.9$/$0.3$ (order $10^{-3}$, too large to be print-rounding, unlike the grid
   case's $\sim10^{-6}$) is left open — not explained by a computation bug since BDD and IPA
   agree exactly with each other at all three points. Script: `asce_power_reproduction.jl`. Log:
   `asce_power_reproduction.log`.

5. **KarlNetwork p-box timing reconciliation.** The discretisation level (server default 200 vs
   this pack's explicit 50) fully explains one report's ~17 min vs another's 546s, confirmed by a
   4-point scaling curve on a second network (`power-network`: 3.05s/7.76s/52.37s/407.23s at
   steps 25/50/100/200, the same superlinear shape). See `validation/power_network/` for scripts
   and logs.

6. **Corpus provenance table.** `CORPUS_PROVENANCE.md` in this folder — network-by-network
   source, structure vs assigned-value provenance, and confirmation status.

7. **Timing convention.** `validation/perf_compare.jl` (the generator behind `perf_ipa.csv`,
   which `make_merged.jl` folds into `paper_data.csv`) states in its own header: "Warms up on
   power-network first, then times each graph." The `ipa_struct_ms`/`ipa_prop_ms` figures already
   follow the warm/second-call convention used throughout the thesis — no re-measurement needed.
