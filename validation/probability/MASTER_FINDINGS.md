# Findings — probability-propagation corpus and case studies

Distilled findings from validating the corpus (129-graph exactness set, named/structured
networks, drone designs, bnlearn benchmarks, adversarial families) and the p-box/interval
propagation machinery against fresh runs of the current codebase. Organised by topic. See
`CORPUS_PROVENANCE.md` for per-network provenance and `INDEX.md` for the verification-run
index, scripts and logs.

## Corpus exactness (129-graph corpus)

- All 129 graphs (120 `random_nX_pY_sZ` + 8 `mutant_rand28_sN` + 1 `counterexample-n15`) verify
  exact against a BDD oracle: Float64 worst deviation 1.11e-16, Interval worst over-width
  2.22e-16 / worst unsound-direction deviation 2.78e-16 — all machine precision, zero failures.
- An earlier interval-mode sweep reported only 113/129 rows. Root cause: it used a naive
  (non-sifted) BDD oracle that silently failed to build on the ~16 densest graphs (a bare
  `catch` dropped them) — the oracle was intractable there, not IPA. Switching the oracle to a
  sifted CUDD build closes the gap: 129/129, 0 failures.
- The naive interval-widening baseline over-widens by up to 0.4522 across the corpus, versus
  IPA's corner-exact result.
- Generator note: `gen_multisource`, `gen_grid`, `gen_layered` are defined in both
  `graph_gen.jl` and `graph_families.jl`. Any script including both files must include
  `graph_families.jl` last to reproduce the corpus exactly (its versions are the ones used
  everywhere the corpus was generated).

## Structured / named networks

- `power-network`, `grid-graph`, `KarlNetwork`, `counterexample-n15` all reproduce exactly
  against the BDD oracle (power 8.3e-17, grid 1.1e-16, Karl 5.6e-17).
- Grid case study: paper-scenario beliefs match to printed precision; BDD-vs-IPA delta exactly
  1.110e-16 (bdd_nodes 290). Runtime is machine-dependent — measured 0.928 ms / 1.72 MB on one
  machine versus 2.378 ms / 4.94 MB reported elsewhere; treat timing as machine-specific.
- ASCE grid reproduction (sources {1,3,13}) against the published Tables 2/3 "Exact" columns:
  worst |diff| 4.750e-6 (R_l=0.9) and 4.294e-6 (R_l=0.1) — within the ~5e-6 rounding noise of a
  table printed to 5 decimal places, i.e. agreement within the paper's own precision.
- ASCE power-network reproduction (sources {1,7,18}, sink 23) against published Table 5: the
  27-edge corpus graph (not the 28-edge candidate edge (17,22)) matches best at all three R_l
  points (0.9/0.99/0.3) — the 27-vs-28-edge question is closed, no file change needed. A small
  residual remains at R_l=0.9 and R_l=0.3 (order 1e-3, too large to be print-rounding); BDD and
  IPA agree with each other to machine precision at all three points, so it is not a computation
  bug on this side — likely a small modelling or input-transcription difference from the
  published paper. Left open.
- Cosmetic refresh on re-run (all still exact): uniq-diamond counts grid 41→39, Karl 147→145;
  counterexample-n15 exactness delta 5.6e-17→8.3e-17.

## Drone networks

Per-design degree stats (`.EDGES` files):

| design | nodes | edges | mean out | max out | mean in | max in |
|---|---|---|---|---|---|---|
| fw-reliant-centralized | 217 | 263 | 1.21 | 27 | 1.21 | 10 |
| vtol-dense-decentralized | 242 | 1753 | 7.24 | 104 | 7.24 | 17 |
| concentrated-minimal | 230 | 1648 | 7.17 | 104 | 7.17 | 16 |

Max in-degree equals each design's widest conditioning set (|C|max).

Diamond stats by K for concentrated-minimal, plus vtol and mlgw-gas (current `is_det`-fixed
identification — see below):

| network | V | E | maxcond | uniq diamonds |
|---|---|---|---|---|
| concentrated-minimal K=10 | 230 | 1359 | 14 | 465 |
| concentrated-minimal K=12 | 230 | 1510 | 15 | 691 |
| concentrated-minimal K=16 (official) | 230 | 1648 | 16 | 1005 |
| vtol-dense-decentralized | 242 | 1753 | 16 | 1486 |
| mlgw-gas-network | 37 | 40 | 4 | 7 |

`vtol-dense-decentralized`'s maxcond is 16, not the previously recorded 17 — see the `is_det`
fix below for why.

- The larger, unrestricted 289-node/6,166-edge `drone-network-full` variant does not complete
  identification within a practical memory budget: it demanded >25GB on a 16GB machine within
  15 minutes. A previously reported conditioning figure of "27–28" for an unrestricted-
  connectivity drone network rests on a single historical run against a different, ambiguous
  build and has no reproducible artifact — the citable finding is the qualitative one
  (unrestricted connectivity is well beyond the practical range; identification itself exhausts
  memory), not that specific number.
- p-box tractability boundary on concentrated-minimal sits between K=6 (measured tractable,
  ~270s) and K=8 (measured intractable — exceeds a 1-hour direct timeout). Total conditioning
  states (Σ 2^|C| across diamonds) explains the boundary better than the single widest diamond
  (maxcond) does, but it is not a reliable runtime predictor: a linear extrapolation from the
  K=6 point under- and over-shot on two later cross-checks (KarlNetwork, K=8) in opposite
  directions. Treat it as a monotone difficulty ordering, not a clock.
- `mlgw-gas-network` p-box: sound and fast (steps=50, propagate 10.2s; worst soundness violation
  0.0057 vs a 3,000-sample Float64 Monte Carlo across all 37 nodes × 21 thresholds).
- `KarlNetwork` p-box completes in 545.9s at steps=50 (900s budget). A previous note claiming
  grid/KarlNetwork p-box "timed out" does not hold on the current codebase — both complete.
- Drone belief bounds reproduce historical values to ≤4.4e-11; worst facility node (195) band
  [0.562, 0.722] exact, fw-reliant worst-facility band [0.750, 0.850] exact.
- BDD-vs-IPA on the official K-sweep: BDD completes through K≤12 (123k nodes, ~45s) but times
  out from K=14 under a documented 1800s budget; IPA stays flat at ~5s throughout K=8..14.
  Interval-over-float timing ratios on this family run 15–56×.

## p-box soundness

| Sweep | Level / operator | Result |
|---|---|---|
| `corpus_cvx.jl` | operator-ref, cvxF vs MC, steps=50 | 16/16 sound (unsoundness 0.000 all) |
| `cvx_sound.jl` | operator-ref, cvxP, steps=20 | 20/20 sound (unsoundness 0.000 all) |
| `validate_framework_pbox.jl` | framework, cvxP, vs 8000-sample MC | 4/4 sound (unsoundness 0.000) |
| `pbox_sweep.jl` | framework | 10/10 sound (naive baseline unsound up to 0.652 by comparison) |

All 50 configurations across these four sweeps are sound with zero violations — the paper's
"dozens of configurations" phrasing is backed at this level. Grid tightness band 0.18 → 0.70
(matches the quoted envelope range). Certified-bound vignette bands [0,0.02] / [0,0.10] /
[0,0.12] / [0.98,1.00] with Monte Carlo counts 9,604 / 385 / 267 / 9,604 reproduce
digit-for-digit.

**p-box cost vs discretisation ("steps"):** the true scaling is closer to O(steps^2.8) than
quadratic. An earlier measurement reporting 2.7s/8.3s/110s at steps 50/200/800 built its p-box
inputs once and only varied `PBA.setSteps` between legs, so the higher "steps" levels were
never actually propagated at that discretisation — an artifact of the measurement script, not a
performance regression. A faithful re-measurement (inputs rebuilt per level) gives ~6.7s @50 and
~314s @200 on the counterexample network; steps=800 is impractical (on the order of hours) and
should not be used as a benchmark point. A practical range for this workload is roughly
steps ≈ 25–100. (Cross-check on `power-network`: 3.05s / 7.76s / 52.37s / 407.23s at
steps 25/50/100/200 — the same superlinear shape.)

## Adversarial fan-in / mesh families

- Fan-in family: `ipa_ops = 2k+1` exactly for every measured k (2..16), confirming the
  factorisation result. IPA is roughly 1000× faster than a one-shot BDD build on this family
  (≤1ms vs ~1–2s).
- Fixed-height mesh family, wall-time crossover: IPA is faster through w=4 (0.37s vs 1.19s);
  BDD leads from w=5 (3.9s vs 1.2s), reaching 55× at w=8. State the gap in seconds — the
  corresponding 1486× op-count ratio at w=8 overstates the real wall-time gap.
- Memory wall in the fixed-height mesh family between w=8 and w=9: op count grows only ×1.39 but
  wall time grows ×37 (159.5s → 5,924.7s) as throughput collapses. IPA's practical limit on this
  family is set by the sub-problem cache's memory footprint crossing available RAM, not by
  op-count growth. Increasing the JIT heap-size hint does not rescue this — it made w=9 slower
  (10.6h vs 5,924.7s / 99min no-hint) by letting OS-level memory pressure grow further; ~99
  minutes stands as the practical boundary.
- Square w×w mesh (growing both dimensions) shows genuine unbounded separation: IPA ops grow
  ~×20/step, BDD nodes ~×3–7/step (w=4..7); both exponential, but BDD's exponent is smaller.
  This is the true asymptotic-separation experiment; the fixed-height family instead saturates.
- Realised sub-problem counts exceed the naive per-unique-diamond estimate Σ_d 2^|C_d| by a
  factor rising from 0.33 to ~48 on deep-mesh instances, because the same diamond structure is
  re-evaluated under many outer contexts. The cost expression W = Σ 2^|C|·O(|E|) is a valid
  a-priori bound only when the sum ranges over context-instances, not unique diamonds. A
  no-dedup context-instance-weighted bound is valid but loose in practice — realised cost is
  1–5% of the bound; cache dedup is worth 20–100×.
- Interval coverage on this family is exact (0.0 corner difference) for every measured fan-in k
  and mesh w=2..7.

## bnlearn networks

- All 17 bnlearn structural benchmarks identify in under 2s each.
- Propagation completes in both Float64 and Interval for 16 of the 17 networks (15 directly,
  plus `link` once the widening-convention fix below was applied). `andes` does not complete
  propagation in any value type within a 16GB budget (maxcond ≈21, 134 genuinely-uncertain
  nodes) — a real intractable case, not a convention artifact.
- `diabetes`: both known exact methods fail, by different resources. IPA's identification
  exhausts memory (~9.5GB) before completing. An instrumented sifted-BDD build reached
  2,763,625+ nodes at 76 minutes wall clock (memory flat, ~2.2GB free throughout) without
  completing — time-bound in reordering, not memory-bound, with growth concentrated in the
  final few reconvergence-dense joins. Citable statement: sifted-BDD construction does not
  complete within a practical time budget while IPA's identification exhausts memory — the two
  exact methods fail on this network by different resources.
- `link` (724 nodes) interval propagation initially appeared to fail by memory (a
  `ReadOnlyMemoryError` from a Dict allocation inside `updateDiamondJoin`), but this traced to a
  synthetic-uncertainty convention artifact, not an intrinsic interval-arithmetic limit — see
  below. With the corrected convention, `link` propagates natively in 0.574s, exact.

## Interval memory wall: root cause and the widening convention

- Root cause: interval-valued contextual beliefs defeat sub-problem cache dedup, so
  cache-context multiplicity — not interval arithmetic itself — drives memory blowup on some
  networks (e.g. `barley`: 606,975 interval cache entries vs 22,656 Float64 entries for the same
  network, a 26.8× factor).
- Framework fix `LEAN_DIAMOND_CACHE` (opt-in flag, default off = byte-identical legacy
  behaviour): stores only the join-node belief per cache entry (~100× smaller). Validated exact
  against the legacy cache on an 11-configuration gate (5 networks × Float64/Interval, plus a
  KarlNetwork p-box run) with identical per-node beliefs and entry counts.
- Deeper cause: widening a prior that is exactly 0.0 or 1.0 (a structural certainty) into a
  synthetic uncertainty interval (e.g. [0.95, 1.0]) makes that node conditionable when it
  otherwise wouldn't be, produces a deeper/larger diamond structure, and defeats a zero-weight
  skip that only fires on exact 0/1 values. Comparing that widened network's interval run
  against the unwidened Float64 run therefore compares two different problems. Confirmed on
  `link`: 184 of 724 nodes have prior exactly 1.0; widening all of them explains the extreme
  blowup (24GB / 63+ minutes), while preserving them as degenerate and only widening genuine
  uncertainties runs the same network in 0.574s.
- **Methodological rule for building synthetic interval/p-box test inputs**: widen only
  genuinely uncertain priors; preserve exact 0.0/1.0 (structural-certainty) priors as
  degenerate. The drone-network interval inputs already follow this convention (hub certainties
  kept at [1,1]), which is why the 242-node vtol network's interval propagation runs in seconds.
- This does not revise the underlying cost model: IPA's propagation cost is governed by
  diamond/conditioning statistics, and every case above (`barley`, `link`, `andes`, the mesh w=9
  wall, the drone K-boundary) is explained by those statistics once measured on the inputs
  actually run. The general lesson: any change to input convention should be checked with a
  cheap identify-only diamond-stats probe before drawing conclusions from a full run.

## `is_det` fix (identification correctness for Interval / p-box)

- `NewIdentify.jl`'s `is_det` check (excludes an already-degenerate source node from
  conditioning) was previously guarded for Float64 only; Interval and p-box priors were never
  excluded, so networks with degenerate (exactly 0/1) non-source-hub priors saw an inflated
  diamond count/maxcond under Interval/p-box, without any change to final belief values.
- Fixed by generalising `is_det` with type-dispatched zero/one checks (mirroring an existing
  pattern in `DiamondPropagation.jl`). This is answer-preserving — excluding an
  already-degenerate node from conditioning cannot change the result (conditional invariance) —
  not a new approximation.
- Verified two ways: (1) K=8 concentrated-minimal re-measured post-fix at 284 diamonds/maxcond
  9, an exact match to the Float64-diagnosed value (down from 687/maxcond 10 pre-fix); (2) a
  full exactness gate (24 Float64+Interval configs vs BDD; 4 p-box configs vs Monte Carlo)
  reran clean and bit-for-bit identical to pre-fix results — the fix changes diamond-counting
  statistics, not correctness.
- Practical effect: `vtol-dense-decentralized`'s maxcond changed from 17 (pre-fix) to 16
  (post-fix, confirmed) — a real, expected change, not measurement noise. The 129-graph
  exactness corpus is unaffected: its priors are drawn from [0.3, 0.99), never exactly 0/1, so
  it never triggers this code path.

## Threading / parallelisation

- Identification (`new_identify`) could in principle be parallelised at the root join-node
  level — the only shared mutable state is a memo dict, and a safe design would need a
  lock-protected memo with publish-after-build rather than the current insert-before-fill order
  (a latent correctness hazard for any future concurrency work). Not implemented, and not
  warranted here: identification is already fast everywhere it's tractable, and where it fails
  (`diabetes`) it fails by memory, which parallelism would aggravate rather than help.
- A separate, older propagation implementation (`ReachabilityModuleLIFO.jl`, Float64-only, on
  the retired `DiamondProcessingModule` pipeline) already solved the two failure modes that
  later forced current propagation single-threaded: per-worker LIFO queues instead of recursive
  per-state spawning, and a locked shared diamond cache. It was orphaned by the
  DiamondDecomposition rewrite rather than shown unsound, and would be a viable template if
  propagation threading is revisited — out of scope for this work.
- The real ceiling on identification at scale is materialised per-context subgraph storage
  (each unique (edgelist, conditioning) context stores O(|E|) edges), not computation time — a
  storage-representation question. Three accuracy-preserving optimisation directions, in
  priority order: (1) lazy/deduplicated sub-structure storage — attacks the actual memory
  ceiling seen in the `diabetes` failure, highest value; (2) memoised set operations
  (intersection/setdiff/ancestor-intersection) in the hot identification paths — deterministic,
  zero accuracy risk; (3) an algorithmic variant of the `components` step using
  fork→reachable-parent indexing instead of pairwise set intersection (same result, better
  complexity). None of these were implemented in this pass.

## Real-infrastructure network provenance corrections

- The corpus's `munin`/`water` networks are bnlearn Bayesian-network benchmarks
  (medical/agricultural PGMs), not civil infrastructure, despite naming — see
  `CORPUS_PROVENANCE.md` for the full per-network table. `power-network` and
  `metro_directed_dag_for_ipm` are plain source/destination edge lists documented only to the
  extent recorded there.
- The on-disk network directory holds additional generated/orphaned variants (e.g.
  scaled-power-network-*, pareto-point directories) not used by any reported result; only the
  networks listed in `CORPUS_PROVENANCE.md` and referenced from the chapter/table map in
  `README.md` are part of the reported results.
