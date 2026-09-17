# p-box generalization — design analysis (READ before implementing)

Goal: extend IPA's exact/tight imprecise reliability from Interval (done, machine-exact) to p-box,
**maintaining exactness** as far as it is theoretically possible. p-boxes are harder than intervals; this
note records what "exact" can and cannot mean here, grounded in PBA.jl and the framework.

## How p-boxes work in this stack (PBA.jl `EMIDw`)
- A `pbox` is a DISCRETISED pair of bounding CDFs (`.u` upper, `.d` lower, `.n` steps ≈ `parametersPBA.steps`,
  default ~200), plus mean/variance bounds. Every result is **outward-rounded** → rigorous (sound) enclosure.
- Arithmetic is a discretised convolution with an explicit DEPENDENCY assumption:
  - `convIndep(x,y;op)` — assumes x⊥y. **All framework ops use this** (`add_values`, `multiply_values`,
    `complement_value = convIndep(1, a, -)`, …).
  - `convPerfect` / `convFrechet` — perfect / unknown-dependency (Fréchet) bounds. `convFrechet` is
    rigorous for ANY dependency but LOOSE.
  - `mixture(xs::Vector{pbox}, w::Vector{<:Real})` — mixture with **scalar** weights.
- Consequence: **p-box tightness is capped by discretisation** — machine-exactness (as achieved for
  Interval) is not attainable; the right bar is "rigorous + as tight as the discretisation and the
  dependency handling allow."

## Why conditioning is CORRECTNESS (not just tightness) for p-boxes
`convIndep` is only valid when operands are independent. At a correlated join, the parents are dependent,
so a naive p-box propagation (`convIndep` over correlated parents) is **unsound/incorrect**, not merely
loose. IPA's diamond conditioning fixes the shared forks → given the conditioning, parents ARE
independent → `convIndep` is valid. So the same mechanism that gave interval-exactness gives p-box
*correctness*. (This is a stronger motivation than the interval case.)

## The hard part: the state-combination dependency
For a conditioning node `c`, IPA combines states as
    belief(join) = belief(c) · R₁ + (1 − belief(c)) · R₀,      R₁ = R(join | c up), R₀ = R(join | c down).
Two dependencies make `convIndep` WRONG here:
1. `belief(c)` appears in BOTH weights (`w` and `1−w`).
2. `R₁` and `R₀` are computed from the SAME downstream structure at different `c` → correlated.
The framework currently does `add_values(multiply_values(R_s, P_s))` = `convIndep` throughout → it ignores
both dependencies. Expected effect: **over-wide, possibly unsound** p-box at every conditioning join.
(The Interval branch avoids this by enumerating the CORNERS of `belief(c)`; there is no p-box analogue in
the current code.)

## What "exact" could mean for p-boxes, and the options
- **Discretised-exact / tight:** the tightest p-box the discretisation allows, with dependencies handled
  correctly. This is the honest target.
- Options for the state combination:
  (A) **Fréchet on the shared parts** — `convFrechet` where dependency is unknown → rigorous (SOUND) but
      loose. Safe, easy, but weakens the "tight" claim.
  (B) **Monotonicity structure** — reliability is monotone in `c`, so `R₁ ≥ R₀` and
      `belief = R₀ + w·(R₁−R₀)` is monotone increasing in `w=belief(c)`. A p-box `w` then maps through a
      monotone function; if `w ⊥ (R₁,R₀)` (true when `c`'s subtree is disjoint from the other parents,
      which conditioning enforces) this can be evaluated tightly by combining the CDF bounds of `w` with
      those of `(R₁−R₀)` — needs care because `R₁,R₀` share downstream variables (their DIFFERENCE is what
      enters, so their correlation partly cancels). This is the route to genuine tightness; it is the
      research sub-problem.
  (C) **Sample-the-box validation only:** treat the framework's p-box as-is and just MEASURE soundness
      /tightness vs Monte-Carlo envelopes, then decide (A) or (B).

## Landmines to fix regardless
- `one_value(pbox)` is defined twice: `makepbox(interval(1,1))` (InputProcessingModule) vs
  `makepbox(interval(1,1.1))` (DiamondDecomposition/UtilityFunctions). The `[1,1.1]` version is NOT a clean
  point mass at 1 → breaks any `is_pinned` test and pollutes conditioning. Must reconcile before the skip
  can be generalised to p-box.
- Skip generalisation: `is_pinned(pbox)` = degenerate point mass at exactly 0 or 1 (both `.u` and `.d`
  step functions collapsed to the point). Only then is dropping the enumerated state exact.

## Recommended sequencing (do NOT skip the measurement)
1. **Reconcile `one_value(pbox)`** to a clean point mass `[1,1]`; check nothing depended on `[1,1.1]`.
2. **Empirical soundness/tightness test FIRST** (option C): tiny graph, p-box inputs; compare IPA p-box
   output vs a Monte-Carlo envelope of belief CDFs from distributions sampled inside the input p-boxes.
   This tells us whether the current `convIndep` combination is unsound, over-wide, or already OK.
3. Based on (2): if unsound/loose, implement the correct state combination — start with (A) Fréchet
   (rigorous, get soundness first), then pursue (B) monotonicity for tightness.
4. Only claim "exact/tight p-box" if the measurement supports it; otherwise claim "rigorous (sound)
   p-box enclosures", which is still a real contribution BDDs cannot provide.

## FIRST MEASUREMENT (validation/pbox_test.jl, single diamond 1->2,1->3,2->4,3->4)
Precise uniform input distributions; belief(4) CDF vs Monte-Carlo (40k). Result:
- **IPA (conditioning): SOUND (unsound=0.0) and TIGHT (band width 0.04 = the ~200-step discretisation
  floor, not dependency over-widening).** Empirical CDF lies inside IPA's band at every x.
- **NAIVE (no conditioning): UNSOUND** — deviates by 0.078; true CDF falls OUTSIDE the naive band.
  Confirms convIndep on correlated parents is wrong; conditioning is what makes p-box correct.
- No belief mass >1 here (support <=0.32) so the [1,1.1] bug was not stressed.
SURPRISE: the state-combination dependency did NOT visibly over-widen IPA on this ONE-conditioning-level
case. CAVEAT: this is a single small graph. The worry was that the dependency COMPOUNDS with DEEPER /
MULTIPLE conditioning levels — must retest on multi-level graphs (grid/KarlNetwork) and near-1 beliefs
(to stress [1,1.1]) before concluding "tight in general". Do NOT generalise the tightness claim yet.

## NEXT p-box checks (before any claim)
1. Fix one_value(pbox) [1,1.1] -> [1,1]; re-run near-1-belief cases; confirm no mass>1.
2. Retest soundness/tightness on multi-conditioning graphs (grid, KarlNetwork) and wider inputs.
3. If still tight -> claim "rigorous + discretisation-tight p-box via conditioning". If it over-widens
   with depth -> the state-combination (option B monotonicity) work is needed for tightness; soundness
   (option A / current) is the fallback claim.

## SECOND MEASUREMENT (post one_value fix; validation/pbox_test2.jl)
- one_value(pbox) fixed [1,1.1] -> [1,1] in UtilityFunctions.jl.
- diamond, NEAR-1 beliefs (MC [0.690,0.973]): IPA sound=0, width=0.035, **mass>1 = 0** (fix works); naive unsound 0.418.
- MULTI-LEVEL (node 6 needs 2-fork conditioning; MC [0.027,0.215]): IPA sound=0, width=0.08, mass>1=0; naive unsound 0.271.
CONCLUSION: IPA p-box is **SOUND and (discretisation-)TIGHT** on single- and multi-level conditioning;
the band widens modestly with depth (~0.035/level = discretisation accumulation, NOT dependency
over-widening) and stays sound. Naive p-box (no conditioning) is badly UNSOUND (0.27-0.42). The
state-combination dependency worry did NOT materialise in these tests. Honest claim supported:
**rigorous + discretisation-tight p-box reliability via conditioning** (tightness improves with PBA steps).
LIMITATION: p-box propagation is SLOW (PBA interpreted); grid/KarlNetwork p-box timed out. Corpus-wide
p-box is computationally heavy — validated on representative small single/multi-level graphs, not the full
corpus. EFFICIENCY TODO: generalise the zero-weight skip to p-box (is_pinned = degenerate point mass at
0/1) so context-extra conditioning nodes aren't enumerated (needed to make p-box tractable on bigger
graphs); correctness does not require it (full enumeration is correct, just 2^|cond|).

## THIRD: efficiency skip + depth/steps study (DONE)
- Generalised the zero-weight skip to p-box (`_pinned01(::pbox)` = point mass at 0/1 via mean bounds
  ml==mh==0 or ==1), module-scoped in `DiamondPropagation.jl`. Result: grid-graph p-box is now TRACTABLE
  (237s; previously timed out) — the skip stops the context-extra conditioning nodes from being enumerated.
- Float64/Interval unaffected (grid/power/KarlNetwork still exact after the refactor).
- Soundness holds at every depth (unsound=0, mass>1=0): diamond, multilevel, grid.
- Band width grows with depth but is DISCRETISATION-limited and TUNABLE: multilevel band 0.0800 at
  steps=200 → 0.0212 at steps=800 (~∝ 1/steps). So the looseness is discretisation accumulation, NOT a
  fundamental dependency over-widening (else more steps wouldn't help). Default steps = 200.

## STATUS UPDATE (2026-08-17) — retiring the stale "grid/KarlNetwork p-box timed out" claim (line ~100)

That line was already half-superseded within this same document (see THIRD, above: grid became
TRACTABLE at 237s once the zero-weight skip was generalised to p-box) but was never edited to say so,
and KarlNetwork was never retested after that fix — so the original sentence has been silently wrong
for both networks, in different ways, for some time:
- **grid**: confirmed fine repeatedly in the 2026-07/08 sessions (steps=50 AND steps=200, many
  scenarios/operators, seconds not a timeout) — the THIRD section's own 237s result already showed
  this; the line 100 sentence just never got corrected to match.
- **KarlNetwork**: freshly re-tested 2026-08-16/17 (`validation/fresh_20260816/karl_pbox_test.log`) —
  **completes steps=50 in 546s**. Also stale, now corrected. KarlNetwork has since been promoted into
  the p-box evidence corpus on the strength of this result.
Do not cite "p-box times out on grid/KarlNetwork" anywhere else this may have propagated (checked:
`notes/pbox_operator_and_soundness.md`, `PAPER_GUIDE.md`, `notes/CORPUS_INVENTORY.md` — corrected
alongside this file).
Separately, a fresh faithful re-measurement of the steps-scaling curve (`timing_imprecise.jl` had an
inputs-per-leg bug — fixed 2026-08-17, see the script) found the true cost exponent is closer to
**O(steps^2.8)**, not O(steps^2) as stated at line 120/126 below — steps=800 is impractical (extrapolates
to hours per graph). Treat "O(steps^2)" in this document as an early, uncorrected estimate.

## FINAL p-box conclusion (defensible claims)
1. IPA p-box reliability is **SOUND (rigorous)** at all tested depths; NAIVE (no conditioning) is UNSOUND
   (0.12–0.42). Conditioning is what makes p-box propagation correct (all ops assume independence).
2. Tightness is **discretisation-limited and tunable** via `PBA.setSteps` (band ∝ 1/steps): tight on
   shallow graphs at default 200, looser on deep graphs unless steps are raised (compute cost O(steps^2)).
3. `one_value(pbox)` fixed [1,1.1]→[1,1]; no belief mass > 1.
So: "IPA gives rigorous, discretisation-tight (tunable) p-box network reliability via conditioning" —
honest, and BDDs cannot do it. NOT machine-exact (intervals are; p-boxes cannot be, by construction).

## Honest expectation
Interval → machine-exact (proven). p-box → at best discretised-tight, and only if the state-combination
dependency is handled (options B). The safe, defensible near-term claim is **rigorous (sound) p-box
reliability via conditioning**; "tight/exact" requires the monotonicity work and must be earned by
measurement, not asserted.
