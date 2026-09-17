# p-box conditioning: operator, soundness vs tightness, tightness envelope (paper material)

## The recombination operator (diamond conditioning, p-box)
The conditioning step `belief = W·A + (1−W)·B` (W = P(fork reachable), A = belief|fork-up,
B = belief|fork-down) is a CONVEX COMBINATION, not a convolution. The framework's old `convIndep`
weighted-sum computed a convolution ⇒ over-wide, mass>1, UNSOUND. Correct operator: integrate over W's
own distribution, blend the branches, envelope over W's imprecision.

Two branch-blends (toggle `PBOX_COND_BLEND[]`), trading PROVABILITY vs TIGHTNESS:

| operator | branch-dependency bound | soundness | tightness |
|---|---|---|---|
| **cvxF** | full Fréchet (all copulas) | **proven** (theorem, by construction) | conservative; can be vacuous |
| **cvxP** | positive-dependence only, `env(convIndep, convPerfect)` | **empirical 20/20 + argued** (proof pending) | tighter; never vacuous in practice |

- "Provable" = a theorem guarantees soundness for ANY input (no testing). "Empirical" = verified sound on
  many cases + argument, no complete theorem yet. Tighter is NOT inherently unprovable — we simply have a
  proof for the wide one and strong evidence for the tight one (a proven-tight operator is future work).
- Positive dependence justification: A and B are both MONOTONE-INCREASING in the shared upstream
  reliabilities ⇒ they move together ⇒ copula ∈ [independence Π, comonotone M]; negative dependence is
  physically impossible, so full Fréchet wastes half its width. cvxP restricts to the positive half.

## SOUND ≠ TIGHT (state this explicitly in the paper)
- SOUND = the p-box band CONTAINS the true CDF (correctness; never wrong). A vacuous [0,1] band is sound.
- TIGHT = the band is NARROW (precision). Band width = how well P(belief≤x) is pinned: 0.06 ⇒ ±3%,
  0.7 ⇒ ±35%, 1.0 ⇒ no information.
- Our result: SOUND on 20/20 configs (correct everywhere); TIGHTNESS varies (below). Do not conflate.

## Measured tightness (band = max CDF-bound width; steps=50, improves with more steps)
| network / regime | band | interpretation |
|---|---|---|
| grid config A (perfect nodes) | 0.18 | P(belief≤x) to ±9% |
| random_n15 (uncertain 0.7) | 0.06 | ±3% (excellent) |
| bridge5 (perfect) | 0.58 | ±29% (loose) |
| grid (uncertain 0.7) | 0.68 | ±34% (loose) |
Driver = reconvergence depth at target × input uncertainty (NOT simply perfect vs uncertain).
Tight: shallow-reconvergent / high-reliability. Loose: deep-reconvergent + fully-uncertain.

## Honest framing of the limitation (turn it into a characterised envelope, not a hidden weakness)
- Exact RANGE always (interval, machine precision) — you always know [min,max] of belief.
- p-box adds distribution SHAPE: tight (±3–9%) for realistic high-reliability systems; gracefully
  degrading but ALWAYS SOUND (±30–40% at worst) on adversarial strongly-reconvergent fully-uncertain cases.
- Tightens with (a) more discretisation steps, (b) higher component reliability. Small-network only
  (O(steps³)/recombination). BDD/point methods give NO analytic distributional bound at all.

## Validation status (all in-framework, ported)
- p-box SOUND vs Monte Carlo: grid config A 0.34→0.000, + grid-uncert/bridge5/random (validate_framework_pbox.jl).
- cvxP broad soundness: 20/20 configs (cvx_sound.jl). Float64 (≤3.3e-16) + Interval (≤2.2e-16) still EXACT
  on 24/24 families (consolidated_sweep.jl).

## TODO to strengthen for reviewers (tightness-envelope demonstration)
- Sweep {triangular, uniform, skewed} × {w=0.05,0.10,0.15} × topologies (+ small real nets) → band table/figure.
- Plot band vs reconvergence/reliability/width = the envelope figure (the honest limitation demonstration).
- (Optional) attempt a soundness PROOF for cvxP, or feature cvxF as the provable bound + cvxP as the tight one.

## [0,1] hardening (applied 2026-07-27)
`pbox_conditional_combine` now closes with `PBA.imp(PBA.env(Mu,Md), PBA.makepbox(PBA.interval(0.0,1.0)))` —
belief is a PROBABILITY (∈[0,1] by construction); PBA's quantile arithmetic is plain Float64 (no directed
rounding), so ULP-level leakage past 0/1 was possible in principle. Intersecting with the unit box is a
SOUND projection (can only tighten, never widen). Regression-checked after the change: framework p-box
still SOUND (grid config A unsound=0.000, band=0.18 — bit-for-bit unchanged from pre-hardening, confirming
no leakage was present in the tested configs; the fix is a no-op safety net here, not a correctness fix).
Note the unit box MUST be constructed fresh per call (tracks the CURRENT `PBA.setSteps()` level) — a
module-level cached constant broke every run at a non-default step count (DimensionMismatch), caught by
the regression before landing.

GUARDED, not silent (added after review pushback: "does the clamp just hide a problem?"). A clamp that
swallows an excursion of ANY size risks masking a REAL conditioning bug (the old convIndep-as-convolution
bug leaked mass by up to 0.34) behind an innocuous "SOUND" result. `pbox_conditional_combine` now measures
the pre-clamp excursion past [0,1] and `error()`s if it exceeds `EXCURSION_TOL=1e-6` — ~4 orders of
magnitude above genuine Float64 rounding noise (steps sequential ops ⇒ error ~steps·eps, <<1e-9 even at
steps=800) and ~4 orders of magnitude below anything resembling the old bug's magnitude. So: FP noise passes
silently (as intended); any real regression, even one 1000x smaller than the old bug, fails loudly instead
of being trimmed away. REGRESSION-CONFIRMED (2026-07-27): re-ran grid/grid-uncert/bridge5/random15 and the
18-config {tri,uni,skew}×{w}×{regime} envelope sweep post-guard — zero `error()` triggers, all bands
bit-for-bit identical to pre-hardening (grid 0.18, grid-uncert 0.68, bridge5 0.58, random15 0.06; envelope
matches the §6 table exactly), all still SOUND. The guard does not false-positive on real usage.

## Certified-bound decision vignette (paper-ready — answers "so what, concretely?")
The point: IPA's p-box gives a GUARANTEED analytic bound on a decision-relevant probability from ONE
propagation; Monte Carlo only ESTIMATES it (statistical, no guarantee, needs many samples for comparable
precision); BDD/point methods have no analytic route to this bound at all (would themselves fall back to
MC). Grid, target node 16, requirement threshold x*=0.95 (`validation/certified_bound_vignette.jl` →
`data/certified_bound_vignette.csv`):

| regime | width | IPA band (1 pass) | MC estimate (N=6000) | N needed to match IPA (worst-case planning, p=0.5) |
|---|---|---|---|---|
| perfect | 0.05 | [0.000,0.020] (0.02) | 0.000 | 9,604 |
| perfect | 0.10 | [0.000,0.100] (0.10) | 0.000 | 385 |
| perfect | 0.15 | [0.000,0.120] (0.12) | 0.014 | 267 |
| uncert 0.7 | 0.05/0.10/0.15 | [0.980,1.000] (0.02) | 1.000 | 9,604 (all three) |

Sentence for the paper: "IPA certifies P(belief≤x*) to within a 0.02–0.12 band from a single propagation;
matching that precision with Monte Carlo requires 267–9,604 samples under worst-case a-priori planning
(p unknown), and even then yields a statistical estimate rather than a guarantee; BDD and other point
methods have no analytic route to this bound and would themselves require the same Monte Carlo fallback."
CAVEAT (be honest, do not cherry-pick): the "N needed at the empirically-observed p̂" column collapses to
~0 whenever p̂ is near 0/1 (correct statistics — variance shrinks near the extremes — but only knowable in
hindsight). Report the WORST-CASE column (p=0.5, unknown a priori) as the real planning number; that is
what a practitioner would actually have to budget for before running the sampler.

## Interval-vs-BDD timing (the interval half of the imprecise story, for completeness here)
`validation/interval_bdd_vs_ipa_timing.jl` → `data/interval_bdd_vs_ipa_timing.csv`: IPA-interval (one
propagation) vs sifted-BDD-interval (build once + 2 corner evaluations), min-of-3, across the 8 named
corpus families. IPA-interval is FASTER on every family (2.9x–95x), not merely tied: counterexample 65x,
grid4x4 95x, complete8 31x, seriesparallel 24x, layered4x6 15x, multisource 8.8x, bridge5 3.6x, random_n25
2.9x. Honest framing: this is the ONE-SHOT query cost (build a diagram from scratch, get one interval
answer) — not a general "IPA beats BDD" claim (elsewhere both are ~2^width with no structural advantage).
A workload reusing the SAME diagram across many repeated queries would amortize BDD's build cost and could
favor BDD instead; that reuse scenario is untested / out of scope here.
