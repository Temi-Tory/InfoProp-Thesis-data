# The p-box dilemma, in one page

## The problem
At every diamond join, IPA recombines by conditioning:

    belief = W·A + (1−W)·B

where W = P(fork reachable), A = belief given fork up, B = belief given fork down. With p-box inputs,
W, A, B are all uncertain distributions — and A and B are **dependent** (both are functions of the same
shared upstream reliabilities). This is a **convex combination of dependent quantities**, not an
independent sum.

## The original bug (fixed)
The first implementation computed the recombination as an **independent convolution**. That is unsound
for this operation: it leaked probability mass outside [0,1] (worst measured excursion 0.34 on the grid
benchmark's target node). Fix: integrate over W's own distribution, blending the branch distributions at
each weight level, enveloped over W's imprecision. After the fix: unsoundness 0.000 on every
configuration tested, while Float64 and Interval propagation remain exact (~1e-16).

## The remaining dilemma: provable vs tight
The blend needs a bound on the A–B dependence. Two operators exist, trading provability against
tightness:

| operator | dependence assumption | soundness | tightness |
|---|---|---|---|
| **cvxF** | none (full Fréchet–Hoeffding) | **proven** — inherits the classical theorem (Williamson & Downs 1990) | conservative, can go vacuous |
| **cvxP** | non-negative dependence only | **empirical** — zero violations across all configs vs Monte Carlo; no theorem | tighter, never vacuous in practice |

cvxP's justification: A and B are both monotone-increasing in the shared upstream reliabilities, so they
cannot be negatively dependent — full Fréchet wastes the negative half of the dependence range.

Why no proof yet: the literature offers a strict trichotomy (independence / fully specified dependence /
fully unknown dependence) with **nothing** for "positive-but-otherwise-unspecified". An attempted
derivation via supermodular (Tchen) ordering hits a real obstruction: the relevant comparison function is
not uniformly ordered, and a concrete counterexample (independent vs comonotone uniforms) shows the
combined distributions *cross*. Genuinely open — not a missed citation.

## Paper stance (decided)
- **Lead with cvxF** for every guaranteed claim ("guaranteed distributional bounds via the
  Fréchet–Hoeffding inequalities" — no proof burden on us).
- Present **cvxP** as the tighter, empirically-validated alternative; soundness proof = future work.
- Never call cvxP "guaranteed" or "proven".

## Numerical hardening (both operators)
Floating-point arithmetic is not outward-rounded, so the result is intersected with [0,1] — a projection
that can only tighten a probability bound, never invalidate it. The projection is **guarded**: if the
pre-clamp excursion beyond [0,1] exceeds 1e-6 (≈4 orders of magnitude above genuine FP noise, ≈4 below
the old bug's magnitude), it raises an error instead of silently clamping — so a real soundness
regression can never hide as "rounding". Regression-confirmed: zero triggers, bands bit-identical.

## What the bounds look like (soundness ≠ tightness)
Sound in **every** regime; tightness varies with structure:
- High-reliability / weakly reconvergent: band ≈ 0.18–0.44 of the unit range (useful).
- Fully uncertain / strongly reconvergent: band ≈ 0.60–0.70 (conservative, still sound).
- Driver = reconvergence depth × input uncertainty; input distribution *shape* is secondary.
  (Envelope figure: `latex_revised/figures/envelope.pdf`, data `data/grid_envelope.csv`.)

## Cost
Quadratic in the discretisation level: 2.7 s @ 50 levels, 8.3 s @ 200, 110 s @ 800 on the 15-node
reference network (vs 0.79 ms interval, which is ~1.2× Float64). So: full p-box on modest networks only;
large networks use exact interval + sampling. Frame as a controllable precision/cost dial, never "cheap".

## The payoff (why we tolerate all this)
From one propagation, the p-box certifies P(belief ≤ requirement) to a 0.02–0.12 band on the benchmark —
matching that precision by Monte Carlo needs 267–9,604 samples (worst-case planning) and still yields
only an estimate, not a guarantee. Decision diagrams have **no analytic route** to this bound at all.

cvxF (Fréchet–Hoeffding, provably sound via Williamson & Downs, but conservative) versus cvxP (positive-dependence-only, 
tighter, zero violations empirically, but no theorem exists — the literature genuinely has nothing for "positive-but-unspecified" 
dependence, and the natural supermodular-ordering proof attempt hits a real counterexample).

t means the precision degrades honestly with how hard the problem is, and in the worst regime the generic answer gets loose, 
but the specific decision question often stays sharp. 

The p-box output is two CDF curves bounding the true distribution of the node's reliability. 
The band is the worst vertical gap between them — i.e., for a question of
 the form "what is P(node reliability ≤ x)?", the band is the width of the interval your answer 
 lands in, at the worst possible choice of x.

Band 0.18 → any such question is answered to within an interval of width 0.18 (≈ ±9%). 
"The probability this node misses its target is between 2% and 20%." Genuinely useful.

Band 0.68 → at the worst threshold, the answer is only "somewhere between, say,
 25% and 93%" (≈ ±34%). For that threshold, yes — close to uninformative. Sound, never wrong, but not decision-grade.

The band is the worst-case gap over all thresholds — most thresholds are much tighter. 
This is exactly what the certified-bound vignette shows: in the same fully-uncertain regime where
 the overall band is 0.68, the certified answer at the specific requirement x* = 0.95 
 was [0.98, 1.00] — a band of 0.02. 
 The curves are far apart in the middle of the distribution but pinched together at the ends, and 
real decision questions ("does it meet the 0.95 requirement?") usually live where the curves pinch.

You never lose the exact interval. Whatever the p-box band does, interval propagation separately 
gives you the exact machine-precision [min, max] of the reliability. 
The p-box only ever adds distributional information on top of that floor.

The loose regime is deliberately adversarial. Band 0.60–0.70 arises when every
 component is fully uncertain (a wide band around 0.7) and the structure is strongly 
 reconvergent — a stress test, not a typical system. 
 Realistic high-reliability systems sit in the 0.18–0.44 regime. And tightness is a dial: 
more discretisation steps and narrower input uncertainty both shrink it.

The comparison that matters: the alternatives give you less. A decision diagram
 gives no distributional bound at all; 
Monte Carlo gives a point estimate with statistical error and no guarantee. 
Even the conservative 0.68 band is information no competitor produces analytically 
— and it's guaranteed to contain the truth.

Practical reading for a decision-maker: if the certified band at your requirement threshold is 
narrow enough to act on (e.g. "violation probability ≤ 12%"), you're done, from one propagation. 
If it's too wide, the method has told you precisely that your input knowledge is insufficient for
 that question — the fix is better component data or more discretisation, not a different algorithm.
  That's why the paper frames it as a "characterised envelope" rather than a defect: soundness never 
  varies, and you always know which regime you're in.

This is also exactly why the manuscript (§5.3.3) leads with the certified-bound vignette 
rather than the raw band numbers — the vignette is the fair picture of practical utility.