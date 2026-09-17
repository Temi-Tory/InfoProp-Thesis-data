# Thesis writing pack — Net3 (integrated case study)

Consolidated copies only, for convenience while writing — every file here also lives at its
original location (named below), which stays the source of truth if this copy and that ever
drift. Structure follows the CPM pack's own convention (`validation/cpm_v2/thesis_writing_pack/`).

## Chapter narrative material

- **`net3_RESULTS.md`** — the full write-up: source and hash, orientation rule and time step,
  network statistics, every input value's source or its stated assumption, headline numbers per
  toolkit and scenario, the JSON-serialization bug found and fixed while verifying the flow
  toolkit, and the reproduction commands. Original: `dag_ntwrk_files/net3/RESULTS.md`.
- **`net3_analysis_json/`** — the exact raw request + response JSON the server returned for
  every toolkit x scenario run in that write-up (7 runs: Baseline reliability/flow/schedule,
  MaxScaling schedule, Degraded flow, Interval reliability/schedule), warm second-call timing
  measured separately (see RESULTS.md section 5, not re-derivable from these files alone since
  they were saved on the first successful call of each). Original:
  `dag_ntwrk_files/net3/net3-scenarios/responses/`.
- **`net3_scenarios_summary.csv`** — one row per toolkit x scenario run, HTTP status and
  headline metric. Original: `dag_ntwrk_files/net3/net3-scenarios/net3_scenarios_summary.csv`.

## Appendix A (network specification)

- **`net3-node-mapping.txt`** — EPANET id -> integer id -> node type (reservoir/tank/junction),
  97 rows. Original: `dag_ntwrk_files/net3/net3-node-mapping.txt`.
- **`net3_orientation_log.txt`** — every link's flow sign and the direction it was oriented,
  full 119-link log (0 dropped for acyclicity). Original:
  `dag_ntwrk_files/net3/net3_orientation_log.txt`.
- **`net3_reliability_input_classification.csv`** — per-edge classification (pump / dummy-
  connector / real pipe), the .inp file's own length and diameter, and the resulting Baseline
  probability — the full working behind the reliability numbers in RESULTS.md section 2.
  Original: `dag_ntwrk_files/net3/net3-scenarios/reliability_input_classification.csv`.

## Bib

- **`net3_bib_additions.bib`** — EPANET 2 manual (Rossman 2000), the pipe break-rate source
  (Barfuss 2023), the pump availability source (Butts 2022), and the three AWWA standards the
  schedule section cites (C600-17, C605-17, C651-14). Append to `references.bib`. Original:
  `net3_bib_additions.bib` (repo root).

## Code changes behind the numbers (not copied here — see the repo)

- `InfoPropFrmwrk/src/Server/Core/Common.jl` — new `sanitize_for_json` helper: recursively
  converts non-finite Float64 (Inf/-Inf/NaN) to string tokens before JSON serialization. The
  unbounded reservoir-edge and tank-connector capacities in this case study are the first inputs
  in the project to exercise this path in a live analysis result.
- `InfoPropFrmwrk/src/Server/Handlers/CapacityHandlers.jl`,
  `InfoPropFrmwrk/src/Server/Handlers/CriticalPathHandlers.jl`,
  `InfoPropFrmwrk/src/Server/Handlers/ProbabilityHandlers.jl` — each routes its success response
  through `sanitize_for_json` at the point it was already constructing one directly (not through
  the shared `json_response` helper).
- `net3_to_ipf.py`, `net3_reliability_inputs.py`, `net3_capacity_inputs.py`,
  `net3_schedule_inputs.py`, `dag_ntwrk_files/net3/net3-scenarios/run_net3_scenarios.py` — repo
  root / case-study scripts, all reproducible from scratch per net3_RESULTS.md's own commands
  (section 7).

## Not carried into this chapter (investigated, ruled out during this session)

- **p-box scenario**: not built. The network's total conditioning-state cost (5.47e4) is past
  the point where a comparably-costed network failed to complete within budget in this session's
  earlier drone-corpus testing; the probability chapter already covers the tractability boundary
  in depth. Decision recorded in net3_RESULTS.md section 1.
- **A "51 diamonds, width 5" figure** recorded in the project's working notes does not describe
  this network — it belongs to a different, pre-existing, BFS-oriented Net3 conversion
  (`dag_ntwrk_files/net3-water/`) already in the corpus. Traced and explained in net3_RESULTS.md
  section 1; nothing in any chapter draft used the old figure yet, so nothing needed correcting.
