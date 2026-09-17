# Net3 end-to-end case study: results

Chapter 10/11 (integrated case study — chapter numbering is shifting through the thesis rewrite;
this pack does not depend on the final number). Built 2026-08-30 per
`net3_case_study_requirements.md`. Every number below is source, computed, or explicitly flagged
as assumed — none is unstated.

## 1. Source and structure

- Source: EPANET Example Network 3 (`Net3.inp`), obtained from WNTR 1.5.0's own bundled network
  library (`wntr/library/networks/Net3.inp`) — the standard distribution copy, not a hand-edited
  one. sha256: `ea3e825c4fef0b5cba47fb06301bc85253f18b6364dc96c44d9fb492c40faa52`. Cite the EPANET 2
  user manual (Rossman 2000) — see `net3_bib_additions.bib`.
- Conversion: `net3_to_ipf.py` (WNTR steady-state simulation, orientation by the sign of each
  link's flow at the simulation's final timestep — 604,800 s, i.e. the end of the .inp file's own
  7-day run). **0 links dropped for acyclicity** — the flow-direction orientation is naturally a
  DAG already, no forcing needed. 3 links had exactly zero flow at that timestep (links 101, and
  two others — see `net3_orientation_log.txt`); these default to the model's own declared
  direction, the orientation rule's stated tie-break, not a special case.
- Structure: **97 nodes** (2 reservoirs, 3 tanks, 92 junctions), **119 edges** (117 pipes, 2
  pumps, 0 valves). Sources (indegree 0) = {1, 2, 4} = {Lake, River, tank "1"} — both reservoirs
  plus one tank oriented as a source by the flow simulation, exactly the pattern the requirements
  doc anticipated. Sinks (outdegree 0) = 18 nodes, 16 junctions + 2 tanks (flagged, not a
  problem: a tank can legitimately end up net-outflow-free at one simulation snapshot).
  Forks = 35, joins = 23, layers = 28.
- **Diamond structure: 307 unique diamonds (incl. nested), maxcond 12, 21 join nodes anchor a
  diamond (the "maximal"/root count).** This does not match a "51 diamonds, width 5" figure
  recorded earlier in the project's working notes. Traced: that figure belongs to a *different*,
  pre-existing Net3 conversion already in the corpus (`dag_ntwrk_files/net3-water/`), oriented by
  an arbitrary BFS from a chosen root — the same topological heuristic used for the metro
  network, with no hydraulic grounding. Recomputing on that older file directly gives exactly 51
  unique diamonds, maxcond 5, 20 maximal diamonds — confirming the figure describes that file,
  not this one. The two networks have almost the same number of maximal diamond *locations* (20
  vs 21); the difference is depth of nesting (maxcond 5 vs 12), consistent with real hydraulic
  flow direction preserving more genuine loop structure than an arbitrary BFS tree. This
  conversion (flow-oriented) is the one specified by the requirements doc and is used throughout
  this pack. maxcond 12 is comfortably tractable (well under the ~18 threshold flagged elsewhere
  in the project as the practical exact-inference limit).
- **p-box was not run for this case study** (decided with the user, 2026-08-30): the total
  conditioning-state cost, sum(2^|C|) over all 307 diamonds, is 5.47e4 — past the point where a
  comparably-costed network (drone concentrated-minimal, K=8, sum 2^|C|=7,758) failed to
  complete within budget in this session's own earlier testing. The probability chapter already
  carries the full p-box tractability-boundary story in depth; re-demonstrating it here on a
  network past that boundary would add cost without adding a new finding.

## 2. Reliability inputs

Node priors: **all 97 nodes = 1.0, exact.** Reliability lives entirely on the edges in this
model — reservoirs and tanks have no failure mode of their own here, and a junction is a demand
point, not a component.

Edges, three classes:
- **2 pumps**: P = 0.99. Butts, E. (2022), "Reliability in Water and Pumping Systems," *Water
  Well Journal*, 25 July 2022 — general water-pumping-system literature (frames 90/95/99% as the
  levels appropriate when a failure between rebuilds is unacceptable for a critical asset), not
  Net3-specific data. Stated as such.
- **3 dummy tank-connector pipes** (EPANET links 20, 40, 50 — each Length=99 ft, Diameter=99 in,
  Roughness=199, confirmed a placeholder, not a real pipe, by inspecting the .inp file directly):
  P = 1.0, exact. Assumption: represents the tank's own boundary, not a length of main.
- **114 real pipes**: P(no failure in 1 year) from an annual break-rate model. Break rate by
  diameter class (breaks per 100 mile-years), Barfuss, S. L. (2023), "Water Main Break Rates in
  the USA and Canada: A Comprehensive Study," Utah Water Research Laboratory, Utah State
  University, December 2023, Figures 38/39/37 ("Total", all materials combined — Net3.inp
  carries no pipe material, so a material-averaged, diameter-differentiated rate is used;
  diameter is in the .inp file): 3-12 in → 13.3, 14-24 in → 3.1, 30-36 in → 0.2. Converted via
  the standard Poisson/exponential model: lambda = (rate/100) * length_miles; P = exp(-lambda).
  Horizon: 1 year. Resulting range: **0.891 to 1.000** over the 114 real pipes.

Value forms: Baseline (Float64) and Interval (+/-5% relative half-width on every non-degenerate
probability; the exact-1.0 values are not widened). Both verified live against the server.
Sample Baseline beliefs (5 of 97): node 32 = 0.856, node 29 = 0.930, node 81 = 0.977,
node 54 = 0.810, node 78 = 0.843.

## 3. Capacity inputs

Unit: **L/s throughout.** Pipe capacity: Q = v*A, v = **1.5 m/s** (the conservative end of the
requirements doc's 1.5-2.0 m/s range). Pump capacity: pump curve's own maximum tabulated flow
point, read directly from the .inp file's `[CURVES]` section (not assumed) — Pump 10 (Lake):
4,000 GPM = 252.4 L/s; Pump 335 (River): 14,000 GPM = 883.3 L/s. Reservoir edges: unbounded
(`Inf`), highest priority — takes precedence even over the pump-curve figure for Pump 10, which
is directly the Lake reservoir's own edge. Dummy tank-connector pipes: unbounded, same grounds
as their reliability treatment. Demand / super-sink: one added node (id 98), one edge in from
each of the 58 demand junctions (`net3_demand_by_sink.csv`, from the EPANET simulation itself),
capacity = that junction's demand — same construction as the RTS-24 case study.

Scenarios:
- **Baseline**: max_flow = **1837.90 L/s** against total system demand.
- **Degraded**: the network's dominant transmission main (EPANET link 329, edge 97->19, 45,500
  ft / 8.6 mi at 30 in — by a wide margin the longest large-diameter pipe; the next comparable-
  diameter pipe is under 5,000 ft) derated to 50% of its Baseline capacity (684.06 -> 342.03
  L/s), and Pump 335 (River source, the larger of the two pumps) set to 0 (out). max_flow =
  **954.64 L/s** — a 48% drop from Baseline.

**A real server bug was found and fixed while verifying this section**: the first flow-analysis
call on Baseline returned HTTP 500, `ArgumentError: Inf not allowed to be written in JSON spec`.
Root cause: an analysis result (not the input, which correctly parses the "Inf" string token per
the established convention) legitimately produced a raw Julia `Inf` — the reservoir-edge and
tank-connector unbounded capacities are the first inputs in this project to genuinely exercise
that path in a live analysis result — and the server tried to serialize it directly, which the
JSON spec (correctly) refuses. Fixed generally, not per-field: a `sanitize_for_json` helper
(`InfoPropFrmwrk/src/Server/Core/Common.jl`) recursively converts non-finite Float64 values to
their string tokens ("Inf"/"-Inf"/"NaN") before serialization, applied at the response boundary
in the Capacity, Critical-Path and Probability handlers. Re-verified after a server restart:
both scenarios now return 200 cleanly (see numbers above).

## 4. Schedule inputs

Interpretation: **restoration programme** (recommissioning of each pipe, pump and tank), the
interpretation both source documents steer toward (their own "(a)"/"(b)" labels are swapped
between the two, but the substance agrees: "closer to the CPM literature," per the working
notes). Pipes and pumps are the graph's edges (their recommissioning is what takes time on a
route); reservoirs and junctions are not physical assets and get node duration 0; tanks get a
node duration.

Grounding: City of Aurora, "Testing and Disinfecting Requirements for New Water Mains" (retrieved
30 August 2026), itself citing AWWA C600-17 (ductile iron), AWWA C605-13/17 (PVC/PVCO) for
testing and AWWA C651-14 for disinfection — national reference standards, not one city's own
invention:
- Isolate: 1 hour, **assumed** (no published figure found for this specific step).
- Pressure/leak test: 2 hours, fixed (Aurora spec, citing AWWA C600-17/C605-17).
- Flush: computed per pipe from the 3.0 ft/s minimum scour velocity (Aurora spec, citing AWWA
  C600-17/C605-13): time = 3 * length_ft / 3.0 ft/s (three pipe-volumes displaced).
- Chlorination hold: 24 hours, fixed (AWWA C651-14, cited directly by the Aurora spec).
- Bacteriological sampling: 24 h (first sample, undisturbed) + 16 h (resample, undisturbed) =
  40 hours, fixed (Aurora spec).
- Pipe total = 1 + 2 + flush + 24 + 40 = **67 hours + flush** (flush ranges from near-zero for
  short pipes to 12.6 h for the 45,500 ft trunk main). **The two fixed regulatory hold times (64
  of the 67 fixed hours) dominate every pipe's duration** — this is realistic, not a modelling
  artefact: real water-main restoration is gated by disinfection procedure, not by any one pipe's
  own geometry. Stated as a finding, not engineered around.
- Pump total: 8 hours, **assumed** (Aurora spec names pump stations in its own scope but gives no
  pump-specific duration distinct from the general sequence).
- Tank node duration: 24 hours, **assumed**, explicitly outside the Aurora spec's own coverage
  ("This section does not include disinfecting procedures for water storage tanks").

Value forms: Baseline (Float64), Interval (+/-20% relative half-width, this session's
established convention for CPM interval scenarios). Degraded reuses the Baseline schedule (its
own scenario is a flow/capacity event, not a schedule change).

Results:
- **Baseline, LongestPath**: project value = **1773.33 hours** (~73.9 days). 28 of 97 nodes
  critical (not degenerate — neither "all tied" nor "one node only").
- **Interval, LongestPath**: the exact domination split was declined. `AnalysisCommon.jl`
  screens on the count of non-degenerate interval inputs before computing either method's
  cost; Net3's 122 interval durations exceed the fixed threshold (kvar ≤ 60) at which the
  split is even attempted, so no bypass-set cost was priced and the toolkit returned the
  conservative enclosure directly (confirmed from the server response: `method:
  "conservative_enclosure"`, `corner_count: 0`, 0.001 s). Project value:
  **[1418.6614, 2127.9918] hours**. 0 necessarily critical, 61 possibly critical. This is
  the screen working as designed on a fixed count rather than a computed cost — a stated
  limitation (Chapter 7 Discussion) and future-work item (Chapter 11), not the earlier
  PSPLIB bug class (a crash after the split had started).
- **MaxScaling** (multiplicative mode; `mode="max_scaling"` in the request — the exact accepted
  token is the lowercase snake_case form, not the OpenAPI doc's display-style "MaxScaling"):
  the Baseline reliability edge probabilities used directly as the CPM multiplicative factors
  (node durations = 1.0, the multiplicative identity; `initial_time` = 1.0). Reports the most
  reliable supply route to each demand node: reservoir-adjacent nodes at or near 1.0; the least
  reliable route in the network reaches node 76 at 0.7515 — a real, non-trivial spread.

## 5. Timing convention

Wall-clock, single core, second call in a warm process (the thesis-wide convention, Appendix B).
Baseline, second-call warm timings: reliability 4.61 s, flow 2.33 s, schedule 2.08 s (first-call:
5.08 s, 2.47 s, 2.06 s respectively — schedule shows negligible JIT effect since an earlier call
this session had already warmed that code path).

## 6. Files delivered

- `net3.EDGES`, `net3-node-mapping.txt`, `net3_orientation_log.txt`, `net3_demand_by_sink.csv`,
  `Net3.inp` (the source file itself, for provenance) — in `dag_ntwrk_files/net3/`.
- `net3-scenarios/{Baseline,Degraded,Interval,MaxScaling}/` — the four input file types as
  applicable per scenario, plus `reliability_input_classification.csv` (per-edge class/value
  breakdown for the reliability inputs).
- `net3-scenarios/responses/` — every server request + response JSON, one pair per toolkit x
  scenario run (7 runs).
- `net3-scenarios/net3_scenarios_summary.csv` — the run summary.
- Generator scripts (repo root): `net3_to_ipf.py`, `net3_reliability_inputs.py`,
  `net3_capacity_inputs.py`, `net3_schedule_inputs.py`; `net3-scenarios/run_net3_scenarios.py`
  (the toolkit-run driver).
- Bib entries: `net3_bib_additions.bib` (EPANET manual, Barfuss 2023, Butts 2022, AWWA
  standards referenced).

## 7. Reproduction commands

```
python net3_to_ipf.py dag_ntwrk_files/net3/Net3.inp --outdir dag_ntwrk_files/net3
python net3_reliability_inputs.py --outdir dag_ntwrk_files/net3/net3-scenarios
python net3_capacity_inputs.py --outdir dag_ntwrk_files/net3/net3-scenarios
python net3_schedule_inputs.py --outdir dag_ntwrk_files/net3/net3-scenarios
python dag_ntwrk_files/net3/net3-scenarios/run_net3_scenarios.py
```
(net3_to_ipf.py needs WNTR: `pip install wntr` — install into a dedicated venv, not the global
environment; WNTR 1.5.0 pulls in numpy>=2.2.6, which breaks any matplotlib already compiled
against numpy 1.x. This was hit and reverted cleanly this session before switching to a venv.)
