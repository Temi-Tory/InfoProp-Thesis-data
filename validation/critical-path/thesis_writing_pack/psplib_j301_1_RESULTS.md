# psplib-j301_1 — analysis run, 2026-08-30

Source: PSPLIB single-mode instance `j301_1.sm` (the `j30` set — 30 real
activities + 2 dummy start/end nodes, 32 total), converted with
`psplib_to_ipf.py` at the repo root. Resource requirements/capacities in the
`.sm` file are read past and ignored — this is the precedence-only schedule,
edge transfer delays all 0 (PSPLIB has no edge durations). Run against the
real server (`POST /critical-path-analysis`, `POST /network-structure`), not
a mock — full JSON responses are in `_analysis-results/`. The server was
restarted partway through this run to pick up the interval-split fix below;
every result in this file (including the float-mode ones taken before the
restart) reflects the current, fixed code — the fix doesn't touch the float
code path at all, so those numbers are unaffected either way.

**Timing methodology**: the per-pass "computed in X.XXs" figures originally
in this file were each the FIRST call of that mode/tier against a freshly
(re)started server — Julia JIT-compiles a method specialization the first
time it's called with a given concrete type signature, and that cost is not
disk-cached (no PackageCompiler sysimage here), so it's paid again on every
process restart. Re-timed directly against `CriticalPathV2Module` (no HTTP —
`time_psplib_modes.jl` at the repo root), warm-up call discarded, SECOND call
timed — the same "two runs, report the second" convention already used
elsewhere in this repo's own validation harness
(`validation/cpm_v2/case_studies.jl`'s "Warm runtimes" section). The gap is
large for the float passes and small for the interval split, and that
difference is itself informative — see each section below.

## Network structure

32 nodes, 48 edges, 1 source (node 1), 1 sink (node 32), 12 fork nodes, 12
join nodes, 11 topological layers.

## Time pass — LongestPath mode (classical CPM), `float/`

Deterministic durations, taken straight from the `.sm` file.

- **method**: `exact_scalar`
- **project value (makespan)**: **38.0** — matches PSPLIB's own published
  MPM-Time for this instance exactly (see the `.sm` file's header:
  `duedate 38  MPM-Time 38`)
- **critical path**: nodes `1, 3, 8, 12, 14, 17, 22, 23, 24, 30, 32` (11 of 32)
- **near-critical** (slack < 10% of project value): nodes `4, 10, 16`
- computed in 3.77s over HTTP on first call; **0.00011s warm, direct-framework,
  second call** — the 3.77s was almost entirely first-call JIT compilation,
  not algorithm cost (a 32-node longest-path pass is genuinely sub-millisecond
  work)

## Time pass — LongestPath mode, `interval/` (durations ±20%)

Each real activity's duration widened to `[d×0.8, d×1.2]`; dummy nodes stay
`[0, 0]`.

**Tier 1 — the live server, before the fix below** (`method:
conservative_enclosure`): message *"exact interval floats are intractable
for this instance (30 interval inputs with reconvergence — NP-hard in
general); returning a sound conservative enclosure"*. Project value range
**[30.4, 45.6]**; necessarily critical: none; possibly critical: 26 of 32 —
`1, 2, 3, 4, 8, 9, 10, 11, 12, 13, 14, 16, 17, 18, 20, 21, 22, 23, 24, 25, 26,
27, 28, 30, 31, 32`. Computed in 3.28s over HTTP (this tier is two crisp
scalar passes plus a conservative margin bound — genuinely cheap; the 3.28s
here is first-call JIT too, not shown separately since this tier is
superseded by tier 2 below on this instance anyway).

**That message was wrong for this instance**, discovered by checking the
split's own cost independently before trusting it (`_closure_sets`/
`_bypass_sets`, node by node): max bypass-set 13, mean 6.78, total run count
**50,524** — comfortably under the routing threshold (`kvar=30<=60`,
`LONGEST_PATH`) and the server's own `max_runs=2,000,000`. Calling
`interval_analyze_split` directly reproduced the real failure instead:
`ArgumentError: interval bounds out of order: [7.105427357601002e-15, 0.0]`,
isolated to node 1 (the dummy start, duration `[0,0]`) and nothing else. The
split computes each node's margin from two INDEPENDENTLY swept corner
configurations; node 1's margin is analytically exactly 0 in both, but the
two sweeps sum a different arrangement of the same Float64 durations to get
there, and landed a few ULPs apart. `ValueInterval`'s constructor
(`IntervalScheme.jl`) has a strict `lo <= hi` check with no tolerance, threw,
and the handler's blanket `catch e; e isa ArgumentError || rethrow(); end`
silently relabelled it as the NP-hard case — a cause unrelated to what
actually happened.

**Fixed, 2026-08-30** (`InfoPropFrmwrk/src/Algorithms/CriticalPathV2/`):
1. `DominationSplit.jl` — the two sweeps' `fminus`/`fplus` are snapped to
   `0.0` when within `atol` of it (and to each other, if they still cross by
   less than `atol`) before `ValueInterval` sees them. `ValueInterval` itself
   stays strict — the fix is that the value is honestly zero before it gets
   there, not that the check stopped looking. The same snap was added to
   tier 2's `mlo`/`mhi` (`IntervalScheme.jl`) as a precaution, though that
   tier tracks min/max of a single value stream and is provably safe from
   this specific failure by construction, unlike the split's two independent
   sweeps.
2. A new `SplitDeclined` exception (`DominationSplit.jl`, exported from
   `CriticalPathV2Module`) is now thrown ONLY when the split's own run-count
   budget is genuinely exceeded. The handler (`AnalysisCommon.jl`) catches
   *that* specifically — not a blanket `ArgumentError` — and reports the real
   run counts in its message when it does decline; every other exception now
   propagates instead of being silently relabelled.

Re-run against the existing oracle-based regression suite
(`validation/cpm_v2/run_interval_validation.jl`) after the fix: **ALL PASS**,
unchanged from before (including on `water-8var`, which shows the identical
~7.1e-15-scale floating-point noise in its own tier2-vs-oracle comparison,
already within that check's tolerance — the magnitude here is a known
characteristic of the method, not something novel to this instance).

**Tier 2 (exact) — after the fix**, confirmed both by calling
`interval_analyze_split` directly AND against the restarted live server
(`POST /critical-path-analysis`, same request as tier 1 — the routing and
the message are automatic, nothing new to ask for): `method:
exact_domination_split`, `corner_count: 50524`.
- **necessarily critical**: `1, 23, 24, 30, 32` (5 of 32) — the two dummies
  plus the last three real activities of the deterministic critical chain
- **possibly critical**: `1, 2, 3, 4, 8, 10, 11, 12, 13, 14, 16, 17, 18, 20,
  22, 23, 24, 30, 32` (19 of 32)

Internally consistent with tier 1: every tier-2 possibly-critical node is a
tier-1 possibly-critical node (19 ⊂ 26 exactly, no exceptions), and tier 1's
empty necessarily-critical set is a subset of tier 2's 5 — a conservative
enclosure widening margins in both directions can only ever lose certainty
and gain false candidates relative to the exact method, never the reverse,
and that's exactly the shape here.

**Timing, warm second call, direct framework**: **4.158s** — unlike the
float passes above, this number is real, not a JIT artifact (it's the SECOND
call in an already-warm process). It maps directly onto the run count:
50,524 corners × ~82µs/corner ≈ 4.15s, each corner being one full scalar
`analyze` pass with its own dictionary allocation overhead. This is the
genuine cost the conditioning-width argument is about: the split turned a
`2^30`-scale problem into a linear-in-the-run-count one, and that run count
is what the wall clock now actually tracks.

## Time pass — ShortestPath mode, `float/`

Same deterministic durations, `mode: "shortest_path"` in the request.

- **method**: `exact_scalar`
- **project value**: **18.0**
- **critical (optimal chain)**: `1, 2, 4, 6, 10, 25, 30, 32` — shares only
  node 30 with the LongestPath critical path; every other node on this chain
  is a different route through the network entirely
- computed in 1.31s over HTTP on first call; **0.00016s warm, direct-framework**

## Time pass — Accumulation mode, `float/`

Same deterministic durations, `mode: "accumulation"` — sums every route to
the target (node 32) rather than finding one extremal chain; reports each
activity's multiplicity (route count) and contribution (value × multiplicity).

- **total accumulated at the target**: **362.0**
- activity 3: duration 4, multiplicity 9 (nine distinct routes reach it) →
  **contribution 36**
- activity 4: duration 6, multiplicity 6 → contribution 36 (same total as
  activity 3, by coincidence of duration × route-count, not a repeated
  figure — two different activities)
- activity 16: duration 10, multiplicity 2 → **contribution 20**
- computed in 3.78s over HTTP on first call; **0.00002s warm, direct-framework**
  — the cheapest of the four passes once JIT is out of the way, consistent
  with accumulation being one forward fold with no combinatorial branching

## Reading this for the thesis discussion

**Report warm, direct-framework timings, not the HTTP first-call numbers.**
Three of the four passes here (LongestPath, ShortestPath, Accumulation) run
in tens of microseconds once JIT compilation is out of the way — the
seconds-scale figures a first HTTP call reports are compilation noise, not
algorithm cost, and would badly overstate this method's expense if cited as
performance data. The fourth (the interval domination split) does NOT
collapse the same way: 4.158s warm, because it is 50,524 real scalar passes,
not one — the run count IS the cost here, at a measured ~82µs/corner, and
that number is genuine.

The real story is sharper than either the raw server output or the first
(wrong) framing of this section: against tier 1's 0 certainties / 26
candidates, the exact split recovers **3 certainties tier 1 cannot see**
(nodes 23, 24, 30 — tier 1 already had 1 and 32 as trivial dummy endpoints,
which the split confirms rather than newly discovers) and **removes 7 false
candidates** (9, 21, 25, 26, 27, 28, 31 — flagged as possibly critical by the
enclosure, ruled out exactly by the split). That contrast, on a published
benchmark, is a genuinely stronger empirical point than "the fallback fired"
would have been — and it only stands because the fallback's own diagnostic
message was checked against the algorithm's real behaviour rather than taken
at face value. A published claim that this instance demonstrates the
NP-hard fallback would have been straightforwardly wrong.

## Reproducing / extending

```bash
python psplib_to_ipf.py <path-to>.sm --halfwidth 0.2 --outdir dag_ntwrk_files/<name>

# independent check of the split's real cost + outcome, bypassing the HTTP
# handler's own (sometimes misleading) fallback message entirely — also
# reports its own warm (2nd-call) timing:
julia --project=InfoPropFrmwrk verify_interval_split.jl \
  dag_ntwrk_files/psplib-j301_1 interval/j301_1-cpm-inputs.json

# warm (2nd-call) timing for all four passes reported in this file, direct
# framework calls, no HTTP:
julia --project=InfoPropFrmwrk time_psplib_modes.jl
```

`psplib_to_ipf.py` (repo root) converts a PSPLIB `.sm` file (j30/j60/j90/j120
sets, downloadable from https://www.om-db.wi.tum.de/psplib/) into a network
folder in this exact shape: `<name>.EDGES` at the root, `float/` and
`interval/` scenario folders each holding a `*-cpm-inputs.json` in the
server's real wire contract (`time_analysis.node_durations`/`edge_delays`,
NOT the flat `node_values`/`edge_values` shape an earlier draft of the
script used — that shape doesn't match what `CriticalPathHandlers.jl`
actually parses and would 400 against the real server).
