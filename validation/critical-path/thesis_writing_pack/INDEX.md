# Thesis writing pack — CPM (psplib-j301_1 + corpus validation)

Consolidated copies only, for convenience while writing — every file here
also lives at its original location (named below), which stays the source
of truth if this copy and that ever drift.

## Appendix A

- **`appendix_a_durations_successors.csv`** — 30 rows, node/duration/successors,
  parsed directly from `psplib/j30/j301_1.sm`. Nodes 1 and 32 (dummy
  start/end, duration 0) omitted.

## Appendix B

- **`float_validation_summary.csv`** — 10 networks × 4 modes (longest,
  shortest, scaling, accumulation), oracle/invariant PASS results. Original:
  `validation/cpm_v2/float_validation_summary.csv` — pre-existing, not
  generated this session.
- **`float_validation_log.txt`** — the full run log behind that CSV. Same
  origin/caveat as above.
- **`interval_validation_log.txt`** — chapterA-allvar and water-8var:
  tier2-vs-oracle, tier1-soundness, diamond-guided tightness, all PASS.
  Original: `validation/cpm_v2/interval_validation_log.txt`. Re-run this
  session, after the interval-split fix — this is the fixed engine's output.
- **`mc_check_psplib_j301_1_log.txt`** — 50,524-run split recompute +
  50,000-sample Monte Carlo soundness/attainment check on psplib-j301_1
  itself. 0 bound violations. Generated this session by
  `validation/cpm_v2/run_mc_check_psplib_j301_1.jl`.
- **`psplib_j301_1_float_bounds.csv`** — the per-node float bounds
  (necessarily/possibly critical) that MC check validated against. Same
  script as above.
- **`mc_check_water_k32_log.txt`** / **`water_k32_float_bounds.csv`** — the
  pre-existing water k=32 precedent this session's psplib MC check was
  templated from (`run_mc_check_water_k32.jl`, not written this session).
- **`case_studies_log.txt`** — the pre-existing "Warm runtimes" precedent
  (`validation/cpm_v2/case_studies.jl`) that this session's own warm-timing
  methodology (see `psplib_j301_1_RESULTS.md`) follows.

## Chapter 7 narrative material

- **`psplib_j301_1_RESULTS.md`** — the full write-up: network structure, all
  four CPM passes (LongestPath float/interval, ShortestPath, Accumulation),
  the interval-split bug found and fixed on this instance (wrong "NP-hard"
  message → real cause → the fix → re-verification), warm vs first-call
  timing for every pass, and the reproduction commands. Original:
  `dag_ntwrk_files/psplib-j301_1/RESULTS.md`.
- **`psplib_j301_1_analysis_json/`** — the exact raw JSON the server
  returned for every pass in that write-up, warm/post-fix where applicable
  (`time-longest-path-interval-result.json` is the FIXED tier-2
  `exact_domination_split` result, not the original wrong
  `conservative_enclosure` one). Original:
  `dag_ntwrk_files/psplib-j301_1/_analysis-results/`.

## Code changes behind the interval numbers (not copied here — see the repo)

- `InfoPropFrmwrk/src/Algorithms/CriticalPathV2/Internal/DominationSplit.jl` —
  the margin-snap fix + new `SplitDeclined` exception.
- `InfoPropFrmwrk/src/Algorithms/CriticalPathV2/Internal/IntervalScheme.jl` —
  the same snap applied to tier 2 as a precaution.
- `InfoPropFrmwrk/src/Server/Handlers/AnalysisCommon.jl` — catches
  `SplitDeclined` specifically now, not a blanket `ArgumentError`.
- `psplib_to_ipf.py`, `verify_interval_split.jl`, `time_psplib_modes.jl`,
  `validation/cpm_v2/run_mc_check_psplib_j301_1.jl` — repo root / validation
  scripts, all reproducible from scratch per `psplib_j301_1_RESULTS.md`'s own
  commands.
