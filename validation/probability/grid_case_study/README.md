# Grid case study — the methodology demonstrator (self-contained)

Purpose: on ONE featured graph (the paper's grid), show the method is CORRECT, CAPABLE, and its COST is
understood — as a single "increasing capability" arc. This is a METHOD demonstration, so inputs are
illustrative (the Float64 values match the paper/dPrPm; the imprecise extensions are ours). No physical
probability justification is owed here — that lives in the drone Pareto case study.

## Locked inputs (decided 2026-07-26)
Float64 = the paper grid values (to match dPrPm). Non-float extensions built AROUND those values:

| component                          | Float64      | Interval        | p-box                                   |
|------------------------------------|--------------|-----------------|-----------------------------------------|
| uncertain (links 0.9, interior nd) | paper `v`    | `[v-w, v+w]`    | triangular(min=`v-w`, mode=`v`, max=`v+w`) |
| perfect (1.0 sources/nodes)        | 1.0          | 1.0 (exact)     | 1.0 (degenerate, mode=1)                |

- Half-widths **w in {0.05, 0.10}** (run both), clamped to [0,1].
- Perfect nodes stay EXACTLY 1.0 in every T-type => Float64 is just the all-modes special case of the
  imprecise model; keeps MC + comparison figures clean (float sits centrally, no upper-edge pinning).
- p-box triangular is mode-centred at the paper value => point estimate = most-likely value.

## Oracles (validate each capability against an independent ground truth)
- Float64 exactness  -> sifted ROBDD (CUDD).                        [confirmed 1.1e-16]
- Interval exactness -> sifted ROBDD at the TWO corners (all-low / all-high; exact range by monotonicity).
                        [confirmed exact 1e-16; THIS is the imprecise contribution]
- p-box: SOUND (fixed 2026-07-27, re-confirmed via a clean CUDD-based rerun 2026-09-17). This line
  previously read "DO NOT CLAIM SOUND" — the conditioning recombination was unsound at that time
  (dependency problem; over-wide, mass>1 near belief=1); see [[pbox-conditioning-unsound]] and
  RESS_response/PAPER_GUIDE.md §1.5 for that historical finding. The cvxP/cvxF conditioning operator
  (ported ~2026-07-27) resolved it. Re-confirmed 2026-09-17 with a full accuracy rerun of this suite
  under CUDD (not the pure-Julia BDDjl substitute used in some earlier confirmation passes):
  `worst_unsound=0.000e+00` at both w=0.05 and w=0.10 — see `data/grid_accuracy.csv`. The p-box-vs-MC
  comparison now demonstrates soundness, not the historical unsoundness. Prototype fix-exploration
  script retained for record only: validation/rc_pbox_mixfix.jl.

## The "increasing capability" arc (paper section order)
1. dPrPm baseline: published grid numbers + accessibility caveat (not reproducible -> motivates reproducible exact method).
2. IPA vs sifted-CUDD: exact agreement (accuracy) + performance.
3. Interval: exact belief range vs naive over-widening (interval overhead ~1.2x).
4. p-box @ {50,200,800}: soundness vs MC + tightness/cost tradeoff.
5. Monte Carlo overlay: the only ground truth once inputs are imprecise.

## Run order & scripts (two separate concerns)
DATA / CORRECTNESS run (can use threads) -> `run_grid_data.jl`:
  produces the case-study TABLE: per-node Float64/Interval/p-box beliefs + BDD / BDD-corner / MC / naive
  comparisons + exactness & soundness columns. Output -> `data/`.
COST run (MUST run ALONE, single-thread, warmup FIRST) -> `bench_grid.jl`:
  (1) one warmup call per type (exclude JIT), THEN
  (2) the trio: @benchmark (median time + memory + allocs) ; sampling profiler (time %% PBA vs IPA vs
      other) ; allocation profiler (bytes PBA vs IPA vs other). Output -> `data/` + `notes/profile_breakdown.md`.
  Rationale for the split: the cost run measures wall-clock, so nothing else (incl. the data run) may
  compete with it. Always: kill other Julia -> warmup -> measure.

## Complexity validation (make the analysis DEFINITE, not qualitative)
IPA per-instance cost is EXACTLY  Work = sum over diamonds d of  2^|C_d| * O(|E_d|)  (|C_d| = conditioning
set size, computed by new_identify). Worst case max|C_d| <= treewidth. Validation table: measured `ipa_ops`
vs the formula prediction across the grid + corpus -> shows the model is exact, not a guess. (No closed
form in n alone: #P-hard.)

## TODO / open
- [VERIFY] PBA triangular constructor (probe bjvdpewu6). If PBA lacks it, build p-box from a triangular CDF;
  MC side uses Distributions.TriangularDist regardless.
- [DECISION MADE] perfect nodes exact 1.0 everywhere; w in {0.05,0.10}; triangular mode-centred p-box.
