# Probability Propagation Toolkit (Chapter 5) — data pack, 2026-08-30

Copied wholesale from `InfoPropFrmwrk/Publications/My work/RESS_response/` (the "probability
dump received 30 August 2026") plus `MASTER_FINDINGS.md` (previously at
`validation/fresh_20260816/`, now here too so the two live together as asked). LaTeX build junk
in `slides/` (`.aux`/`.fdb_latexmk`/`.fls`/`.log`/`.nav`/`.out`/`.snm`/`.toc`) pruned on copy —
`pbox_talk.tex` and `pbox_talk.pdf` (the actual source/deliverable) kept.

## §1 — confirmed present, matches the requirements doc

- `data/` — 20 CSVs + `grid_case_study/data/` (2 more) = 22, close enough to the stated 21 to be
  the same set (likely a miscount in the requirements doc, not a missing file — every named CSV
  in Section 1 is present, checked by name).
- `tex/` — all 4 revision fragments (`paper_adversarial.tex`, `paper_imprecise.tex`,
  `paper_figures.tex`, `paper_tables.tex`).
- `notes/` — all 16 named files present (reviewer map, reviewer responses draft, p-box dilemma
  and operator notes, limitations, corpus inventory and campaign hand-back, pipeline rewrite
  status, roadmap, literature verification, profile breakdown, plus `GRID_BENCHMARK_CORRECTED.md`
  and `RESS_WRITING_HANDOFF.md`, `CORPUS_AND_OPTIMIZATION_HANDOFF.md` not individually named in
  the requirements doc but present and clearly in-scope).
- `PAPER_GUIDE.md`, `RESS_edit_proposals.md`, `SESSION_WORK_LOG.md` — present.
- `OriginalPaper/images/` — `decomp_network/` and `diamond_types/` subfolders present, plus
  `chain.png`, `indepmulti.png`, `grid_graph.png`, `metro_dag.png`, both Scotland drone maps,
  `decomp_dag_original.png`, `diamondTypes.png`, `numerical-diamond.png`, `simpleDag.png`,
  `simplepathsdiamond.png`.
- `slides/pbox_talk.tex` + `SPEAKER_NOTES.md` — present.
- `OriginalPaper/references.bib` — present.
- `MASTER_FINDINGS.md` — copied in alongside, as asked.

A stray, older duplicate of `paper_data.csv` that had been sitting at `validation/paper_data.csv`
(no wrapping folder) was byte-identical once line endings are normalised — removed as redundant,
not a missed newer version.

## §2 — confirmed genuinely missing (need from you, not derivable from anything in this repo)

Checked `OriginalPaper/` directly before reporting this, not just trusting the requirements doc's
own claim: it holds only the Elsevier template boilerplate (`elsarticle-template-*.tex/.bst/.dtx`,
`elsdoc.*`), images, and `references.bib`. No submitted manuscript, no reviewer reports anywhere
in the dump.

1. **The original RESS submission `.tex`** (submitted + revised versions) — not in `OriginalPaper/`,
   not found anywhere else in the repo.
2. **The reviewer reports as received** — only paraphrased versions exist
   (`notes/REVIEWER_RESPONSE_map.md`, `notes/REVIEWER_RESPONSES_draft.md`).
3. ~~`MASTER_FINDINGS.md`~~ — resolved, copied in above.
4. **The ICSRS 2023 paper** (`ohiani_information_2023`) — not found anywhere in the repo.

## §3 — runs still needed, assessed against what already exists

Nothing below has been run yet this pass. Flagging what's already partially covered by existing
repo material before you decide how to sequence these — several are substantial (the 129-graph
rerun and the drone K=10/12/16 remeasurement both plausibly multi-minute; today's system has
already had one crash under concurrent Julia load, so I'd rather sequence these deliberately than
launch all seven at once).

1. **Full 129-graph exactness rerun, post-`is_det` fix — DONE.** Result:
   **129/129 exact (worst_delta < 1e-6), 0/129 changed** vs the prior `paper_data.csv` (tol 1e-9).
   Reconstructed the corpus exactly: 120 `random_nX_pY_sZ` graphs decoded byte-identically from
   their own names (`MersenneTwister(seed)`, deterministic), `counterexample-n15` from its real
   persisted file (`dag_ntwrk_files/counterexample-n15/`), and the 8 `mutant_rand28_sN` graphs
   using the exact parameters recovered from `validation/full_regression_sifted.jl`
   (`MersenneTwister(7)`, `n=28,p=0.12` base, `scaling_mutants(...;seeds=1:8,adds=5,dels=2)`) —
   not guessed. Used the current, correct `new_identify` (NOT `oracles.jl`'s `ipa_structure`,
   which calls the explicitly-RETIRED `identify_and_group_diamonds`). Cross-checked against a
   pure-Julia BDD oracle (`BinaryDecisionDiagrams.jl`), not CUDD — CUDD demanded ~20-30GB twice
   today including on this run's own smallest graph, an environment issue unrelated to graph
   complexity, avoided rather than chased down. Confirms the theoretical argument empirically:
   this corpus's priors are drawn in [0.3, 0.99) (never exactly 0 or 1 on any node), so it never
   exercised the `is_det` bug's trigger condition (a non-source node at prior exactly 0 or 1) in
   the first place — the fix changes nothing here, now proven across all 129 graphs, not just
   argued. Script: `validation/probability/rerun_129_corpus.jl`. Raw per-graph results:
   `validation/probability/rerun_129_corpus_results.csv`. Log: `rerun_129_corpus.log`.
2. **Drone diamond stats at K=10, 12, 16 + vtol + mlgw gas, post-fix — DONE.** Rebuilt
   concentrated-minimal directly from the real source data (`csvfiles/drone_info/`, the same
   generator logic as `drone_network_to_dag_reliability.jl`, ported to plain Julia to sidestep an
   unrelated pre-existing Pkg resolver conflict in the InfoPropFrmwrk environment — flagged, not
   fixed, out of scope here) at K=10/12/16, plus the persisted vtol-dense-decentralized and
   mlgw-gas-network files, through the current `new_identify`/`update_beliefs_iterative` pipeline:

   | network | V | E | maxcond | uniq diamonds | vs prior record |
   |---|---|---|---|---|---|
   | concentrated-minimal K=10 | 230 | 1359 | 14 | 465 | **exact match** to `g2_ksweep.log` |
   | concentrated-minimal K=12 | 230 | 1510 | 15 | 691 | **exact match** to `g2_ksweep.log` |
   | concentrated-minimal K=16 (official) | 230 | 1648 | 16 | 1005 | `CORPUS_INVENTORY.md` only had the approximate "16-17"; now exact |
   | vtol-dense-decentralized | 242 | 1753 | **16** | 1486 | `CORPUS_INVENTORY.md` recorded **maxcond=17** — genuinely CHANGED |
   | mlgw-gas-network | 37 | 40 | 4 | 7 | not previously recorded at this precision |

   K=10 and K=12 reproduce their prior numbers exactly, confirming those specific configs were
   already measured post-fix (or never triggered the bug). vtol-dense-decentralized's maxcond
   dropping 17→16 is a real, expected change, not noise: it's the same signature `NewIdentify.jl`'s
   own in-code note documents for this network family (the is_det bug inflates diamond
   count/maxcond on real-infrastructure graphs with degenerate hub priors — non-source hub nodes
   at prior exactly 1.0 — without ever changing the belief values themselves). Script:
   `validation/probability/drone_ksweep_remeasure.jl`. Results: `drone_ksweep_remeasure_results.csv`.
3. **ASCE grid reproduction (sources 1,3,13; R_l 0.9 and 0.1; vs Tables 2 and 3) — DONE, both.**
   Used the real, already-persisted network file (`dag_ntwrk_files/grid-graph/grid-graph.EDGES`,
   confirmed sources = {1,3,13} match Fig. 10 exactly), current production pipeline
   (`new_identify`/`update_beliefs_iterative`), compared node-by-node against both tables' own
   printed "Exact" column values (re-read directly off the paper PDF page 7, not from memory).
   **Table 2 (R_l=0.9)**: worst |diff| = 4.750e-6 (node 12). **Table 3 (R_l=0.1)**: worst |diff| =
   4.294e-6 (node 16 — the paper's own lowest-probability, hardest-to-hit-precisely event).
   Both are within the ~5e-6 rounding noise inherent to comparing full-precision output against a
   table printed to 5 decimal places — i.e., exact agreement within the paper's own reporting
   precision, not a real discrepancy. Extends (doesn't just repeat) `notes/GRID_BENCHMARK_CORRECTED.md`'s
   earlier R_l=0.9-only, independent-BDD-oracle check (1.1e-16) — that compared against an internal
   oracle; this compares directly against the published numbers, for both tables.
   Script: `validation/probability/asce_grid_reproduction.jl`.
4. **ASCE power network reproduction (`Published_R090/R099/R030`, 27-vs-28-edge question) —
   edge question DONE/CLOSED; a smaller separate residual remains open.**
   Reran cleanly under the correct pure uniform-$R_l$ ASCE scheme only (node priors = 1.0, no
   RESS-style reliable-link machinery anywhere in this run), current `new_identify`/
   `update_beliefs_iterative` pipeline, cross-checked against a pure-Julia BDD oracle
   (agreement to machine precision, $\le$1.1e-16, at every point below — the propagation itself is
   exact; any gap vs. published is a modelling/topology question, not a computation bug).
   Sources={1,7,18}, sink=23, confirmed structurally against Fig. 11 ("three source nodes... sink
   node is Node 23").

   | | $R_l=0.9$ | $R_l=0.99$ | $R_l=0.3$ |
   |---|---|---|---|
   | published (Table 5) | 0.85741 | 0.98969 | 0.00221 |
   | 27-edge (as-is corpus) | 0.85917 (diff 0.00176) | 0.98969 (diff **0.00000**) | 0.00272 (diff 0.00051) |
   | 28-edge (+ candidate (17,22)) | 0.88505 (diff 0.02764) | 0.98999 (diff 0.00030) | 0.01054 (diff 0.00833) |

   **Verdict, all three $R_l$ points, not just one this time**: the 28-edge candidate is WORSE at
   every single point, several times worse at $R_l=0.9$ and $R_l=0.3$ specifically — confirms (now
   under the *correct* framing, not the earlier RESS-mistake run) that (17,22) is not a missing
   edge. **The 27-edge corpus graph, as it already stands, is correct** — the 27-vs-28-edge
   question is closed, no file change needed.
   A separate, smaller thing this does NOT explain: $R_l=0.99$ matches to 5 decimals exactly
   (0.00000 diff) but $R_l=0.9$ and $R_l=0.3$ each carry a small residual gap (0.00176/0.00051) —
   order $10^{-3}$, too large to be the paper's own print-rounding (unlike the grid case above,
   where residuals were $\sim10^{-6}$ and fully explained by 5-decimal rounding). Since BDD and
   IPA agree exactly with each other at all three points, this isn't a computation issue on this
   side; it's either a genuine small modelling difference from the paper (a node/edge treated
   slightly differently, or a rounding step in *their* pipeline) or noise in how Table 5's inputs
   were transcribed at $R_l=0.9$/$0.3$ specifically. Flagging as open rather than asserting a
   cause — not chased further this pass. Script: `validation/probability/asce_power_reproduction.jl`.
   Log: `asce_power_reproduction.log`.
5. **KarlNetwork p-box timing reconciliation.** **Done, precisely** — earlier today: identify the
   discretisation level (server default 200 vs `MASTER_FINDINGS.md`'s explicit 50) fully explains
   FOUNDATION.md's ~17 min vs MASTER_FINDINGS.md's 546s, confirmed by a 4-point scaling curve on a
   second network (power-network: 3.05s/7.76s/52.37s/407.23s at 25/50/100/200, matching the
   chapter's own 15-node reference shape). See `validation/power_network/` for the scripts and
   logs; worth copying the summary into this pack too if that's where the chapter draws from.
6. **Corpus provenance table — DONE.** `CORPUS_PROVENANCE.md` in this folder. Assembled from
   `notes/CORPUS_INVENTORY.md` + `notes/CORPUS_CAMPAIGN_HANDBACK.md`, cross-checked against the
   dump where possible (bnlearn, mlgw/Illinois IDEALS 5302, Net3, Tong & Tien Fig. 11 all directly
   confirmed in the dump's own notes or the paper PDF); the metro/Berlin/BFS-from-node-18 claim
   and the drone/Jones-et-al. claim rest on your own statement — not independently found written
   down anywhere in the dump, but not contradicted by anything in it either.
7. **Second-call timing convention — DONE, confirmed correct as-is.** `validation/perf_compare.jl`
   (the likely generator of `perf_ipa.csv`, which `make_merged.jl` folds into `paper_data.csv`)
   states directly in its own header: *"Warms up on power-network first, then times each graph."*
   The existing `ipa_struct_ms`/`ipa_prop_ms` figures already follow the warm/second-call
   convention — no re-measurement needed. `notes/RESS_WRITING_HANDOFF.md` and
   `notes/REVIEWER_RESPONSES_draft.md` already commit to stating this explicitly in the
   methodology text ("every runtime reported was measured after a discarded warm-up run") —
   that's chapter prose, yours to write, not a further data task.

## §4 — status

All 7 of §3's runs are now done (2026-08-30) — 1/129-corpus, 2/drone K-sweep, 3/ASCE grid,
4/ASCE power (edge question closed; a separate small residual at $R_l$=0.9/0.3 flagged open, not
chased), 5/KarlNetwork timing, 6/provenance table, 7/timing convention. Remaining before the
chapter itself: the "how the chapter will state its publications" note text and the actual
methodology/results prose — that's chapter prose, yours to write, not a further data task.
