# p-box experiments — agent / session hand-off

Everything needed to continue the p-box (imprecise reliability) work: what it is, what's done, the exact
operator + code, how to run the validators, the open experiments, and the PBA-internals analysis. Pair
with [[pbox-conditioning-unsound]] (memory) and ../SESSION_WORK_LOG.md §8.

================================================================================================
## 1. Model & goal
Reliabilities (node/edge) are UNCERTAIN. Under INTERVAL inputs, belief(v)=P(v reachable) is an exact
range (monotone ⇒ range = corners). Under P-BOX inputs (distributions over the reliabilities), belief(v)
is itself a distribution (p-box). Goal: propagate a SOUND (and ideally tight) p-box of belief(v) through
the diamond recursion. This is NOVEL vs BDD (decision diagrams give point/interval values only; no
analytic distribution propagation).

================================================================================================
## 2. The core result (done)
The diamond conditioning step `belief = W·A + (1−W)·B` (W=P(fork reachable), A=belief|fork-up,
B=belief|fork-down) is a CONVEX COMBINATION, not a convolution. The framework originally used `convIndep`
(convolution) ⇒ over-wide, mass>1, UNSOUND. FIX (ported + validated): integrate over W's own distribution,
blend branches per weight level, envelope over W's imprecision:
    M = env_{W lower/upper} [ mixture over w-levels of  blend(w·A, (1−w)·B, +) ]
- blend = `env(convIndep, convPerfect)`  (cvxP, positive-dependence; DEFAULT) — tight, empirically sound.
- blend = `convFrechet`                  (cvxF; PBOX_COND_BLEND[]=:frechet) — provably sound, conservative.
Branches are monotone-increasing in shared reliabilities ⇒ positively dependent ⇒ copula ∈ [Π, M];
negative dependence impossible, so cvxP restricts to the positive half (tighter than full Frechet).

Framework implementation:
- `InfoPropFrmwrk/src/Algorithms/Shared/InputProcessingModule.jl`: `pbox_conditional_combine(W,A,B)` and
  `const PBOX_COND_BLEND = Ref(:positive)` (toggle :frechet). Exported.
- `ProbabilityPropagation/ProbabilityPropagationModule.jl`: imports both.
- `ProbabilityPropagation/Internal/DiamondPropagation.jl` Phase 2: p-box branch = NESTED 2-way convex
  combination over `conditioning_nodes_list` (one node at a time; m nested 2-way = the 2^m mixture).
  Float64 (flat weighted sum) and Interval (2^m corner enumeration with scalar weights) UNCHANGED/exact.

================================================================================================
## 3. Validation status (all vs Monte Carlo / BDD)
- Framework p-box SOUND: `validation/validate_framework_pbox.jl` — grid config A 0.34→0.000, +
  grid-uncert/bridge5/random all sound.
- cvxP broad soundness: `validation/cvx_sound.jl` — 20/20 configs (10 topologies × perfect/uncertain).
- Reference operator: `validation/rc_pbox_cvx.jl` (conv vs cvxI vs cvxF vs frechet on grid).
- cvxP tightness/vacuous behaviour: `validation/cvx_lean.jl`.
- Float64/Interval still exact after the port: `validation/consolidated_sweep.jl` (24/24).
Run pattern: `julia -t 1 validation/<script>.jl > /tmp/out.log 2>&1` (steps set via PBA.setSteps; PBA
prints benign "Disagreement between theoretical/observed mean/variance" warnings — wrap p-box calls in
`redirect_stdout(f, devnull)` to silence; they are NOT soundness failures).

================================================================================================
## 4. Open experiments (priority order)
1. TIGHTNESS ENVELOPE (grid only) — `validation/grid_envelope.jl` → data/grid_envelope.csv: band +
   soundness across {triangular, uniform, skewed} × {w=0.05,0.10,0.15} × {perfect, uncertain}. Produce the
   band-vs-(distribution,width,regime) figure = the honest "characterised limitation" plot.
   [RESULTS: see §6 below once the run completes.]
2. [CHECKED, DEPRIORITIZED — see §6] SOUNDNESS PROOF for cvxP (currently empirical 20/38 + argued). A
   bounded literature check (2026-07-27) found no off-the-shelf theorem; a from-scratch derivation attempt
   hit a real obstruction (see §6). DECISION: feature cvxF (provable) as the headline guarantee + cvxP
   (tight, empirically validated) as the pair — do not block the submission on this proof.
3. PBA PRECISION LOCKDOWN — confirm PBA's arithmetic is OUTWARD-rounded (sound). [See §5 below.]
4. Broader / real networks (tractability permitting; O(steps³)/recombination → small nets only). NOTE
   (user, 2026-07-27): drone case study is OUT OF SCOPE for now for p-box, but INTERVAL is cheap (~1.2x
   Float64 overhead, no discretisation) and could plausibly run on some drone Pareto configs even though
   p-box can't — worth a follow-up interval-only pass on the drone configs later, separate from p-box work.
5. Consider a provably-EXACT analytic p-box via COMPONENT-cutset conditioning (condition on components
   until residual is read-once → exact mixture with independent weights; exponential in treewidth). This
   would be a stronger (proven-exact) method for small nets — potential separate contribution.
6. [DONE — see §6] CERTIFIED-BOUND VIGNETTE (grid; HIGHEST reviewer-impact — converts the capability into a decision).
   The point: IPA's p-box gives a GUARANTEED analytic bound on a decision-relevant probability; MC only
   ESTIMATES it (statistical, no guarantee); BDD/point methods can't produce it analytically at all.
   Spec: on the grid at a target node, pick a reliability threshold x* (e.g. a requirement like 0.95).
   (a) IPA: `PBA.cdf(belief[target], x*)` → interval [a,b] on P(belief ≤ x*), from ONE propagation — a
       CERTIFIED bound (belief-CDF provably within [a,b]).
   (b) MC: to estimate P(belief ≤ x*) to a CI half-width matching (b-a)/2 needs N ≈ z²·p(1-p)/((b-a)/2)²
       samples (z=1.96), and even then yields a STATISTICAL estimate ± CI, NOT a guarantee. Report the N
       needed (often 10^3–10^5 for comparable width) + that it is not certified.
   (c) BDD: no analytic distributional bound; would itself fall back to MC (same as b).
   Deliverable: one table/sentence — "IPA certifies P(belief≤x*)∈[a,b] in 1 pass; MC needs ~N samples for
   comparable width and still no guarantee; BDD n/a analytically." This is the crisp "stronger vs BDD for
   imprecise" argument. Build as an add-on to grid_envelope.jl (reuse its IPA p-box + MC samples).
7. [DONE — see §6] INTERVAL BDD-vs-IPA TIMING (corpus) — confirm the interval story. Interval reliability
   is EXACT for BOTH (a tie on correctness): IPA via interval corner-enumeration in conditioning; BDD via 2
   corner evaluations (all-low / all-high) on one built diagram. Measure wall-time across the corpus
   families: IPA-interval (one propagation) vs BDD-interval (build once + 2 weighted sweeps). Purpose: show
   IPA is TIME-COMPETITIVE with BDD on interval, not just correct — closes the "interval = tie, but at what
   cost?" question.

================================================================================================
## 5. PBA (ProbabilityBoundsAnalysis.jl) source analysis  [from source-analysis agent, EMIDw/src/]
PBA implements Williamson & Downs (1990) discrete-quantile p-box arithmetic. Global params
(ProbabilityBoundsAnalysis.jl:67-78): steps=200, bOt=0.001, tOp=0.999, verbose=2. Setters setSteps/
setBOt/setTOp/setVerbose (:80-83). NO rounding-tolerance/epsilon; NO directed-rounding switch.

- pbox struct (pbox.jl:58-68): `u` = LEFT bound = UPPER cdf (quantile x-values, not probs); `d` = RIGHT
  bound = LOWER cdf; length `steps`. `u` sits on prob levels [0,1/n,…,(n-1)/n], `d` on [1/n,…,1]. `ml/mh`
  = mean interval bounds, `vl/vh` = variance bounds (computeMoments pbox.jl:425). Every constructed pbox
  is force-interpolated to `steps` points via linearInterpolation (pbox.jl:631) — LINEAR, not outward.
- convIndep (arithmetic.jl:47): independence; Cartesian product sorted, binned OUTWARD (extreme quantile
  per block) → SOUND at discretisation level. convFrechet (:156): unknown dependency, pointwise best
  Fréchet bounds → SOUND. convPerfect (:112): comonotone (+1). convOpposite (:135): counter (−1).
  DEFAULT +,-,*,/ on pboxes use corr=interval(−1,1) = Frechet (safe). env (distributions.jl:40): u=min,
  d=max → SOUND outer bound. mixture (pbox.jl:488): concatenate then RE-DISCRETISE to `steps` → fixed
  size, NO blow-up (the earlier slowness was compute, not blow-up). cdf(pbox,x) (pbox.jl:144): returns an
  Interval [lower,upper] on P(X≤x) (matches glo/ghi usage). left/right (special.jl:21) = support min/max.
  scalar*pbox (arithmetic.jl:493): exact affine map, no dependency issue.
- SOUNDNESS verdict: outer bounds hold (binning is outward) for convIndep/convFrechet/env/imp/mult/shift/
  complement/cdf/mixture, MODULO Float64 ULP round-off (quantile arithmetic uses plain +,-,*,/, no directed
  rounding). convPerfect/convOpposite are sound ONLY if that exact dependency truly holds.
- The "Disagreement between theoretical and observed mean/variance" warning: emitted in checkMoments
  (pbox.jl:453) when the analytic moment interval doesn't intersect the quantile-derived one; it RECONCILES
  by keeping the quantile-observed moment → BENIGN, NOT a soundness failure; means discretisation is
  coarse. Prints by default (verbose=2, guard 1<verbose). Silence cleanly with `PBA.setVerbose(1)` (better
  than redirect_stdout). Raise `steps` if frequent.

>>> TWO ACTIONABLE FINDINGS for locking down our p-box implementation:
>>> (A) [0,1] IS NOT ENFORCED. PBA quantiles can leave [0,1] (sums of prob-valued p-boxes exceed 1). Our
>>>     belief is a PROBABILITY, so CLAMP the operator output to [0,1] — sound projection (true belief∈[0,1]),
>>>     guards against FP leakage / residual mass>1, and can tighten. Add to pbox_conditional_combine:
>>>     `PBA.imp(result, PBA.makepbox(PBA.interval(0.0,1.0)))` (intersection with [0,1]); or clamp u/d to
>>>     [0,1]. RECOMMENDED hardening.
>>> (B) Use `PBA.setVerbose(1)` once at startup to silence the benign moment warnings (cleaner than the
>>>     redirect_stdout wrapper in the validators).
>>> Paper caveat to state: p-box bounds are sound at the discretisation level (outward binning) MODULO
>>> floating-point round-off (PBA uses plain Float64, no directed rounding) — standard for W&D arithmetic.

================================================================================================
## 6. Results log
- PBA analysis: DONE — see §5 (sound outward binning modulo Float64 ULP; mixture re-discretises no blow-up;
  warning benign; [0,1] not enforced but cvxP convex ⇒ stays in [0,1]; bounded inputs avoid tail truncation).
- grid_envelope.csv (framework cvxP vs MC, grid node 16, steps=50): 18/18 SOUND (unsound=0.000) across
  {tri,uni,skew} × w{0.05,0.10,0.15} × {perfect,uncert0.7}. Band (CDF-bound width):
    perfect: 0.18–0.44 (grows with w; tri 0.18/0.28/0.40, uni 0.24/0.26/0.38, skew 0.34/0.38/0.44)
    uncert : 0.60–0.70 (~flat in w; tri 0.68/0.68/0.66, uni 0.60/0.60/0.60, skew 0.62/0.68/0.70)
  => SOUND regardless of input distribution shape; tightness driven by REGIME (reconvergence) then WIDTH,
     distribution shape secondary. This is the "characterised envelope" figure (tight/conservative/sound).
- certified_bound_vignette.csv (item #6, grid node 16, x*=0.95, tri dist, steps=50) — DONE:
  `validation/certified_bound_vignette.jl`. IPA certifies P(belief≤0.95) in ONE pass:
    perfect  w=0.05/0.10/0.15 -> band 0.02/0.10/0.12 (N_MC-worst-case to match = 9604/385/267)
    uncert0.7 w=0.05/0.10/0.15 -> band 0.02 flat      (N_MC-worst-case to match = 9604 all three)
  MC phat (N=6000) landed near 0/1 in every scenario (x*=0.95 sits in the tail for both regimes at the
  grid), so the "N at phat" column is near-0 (hindsight-only, not a real planning number); report the
  WORST-CASE column (p=0.5 unknown a priori) as the honest N-needed — 267 to 9604 samples vs IPA's 1 pass.
  BDD: no analytic path, would fall back to the same MC estimate with no guarantee. Headline sentence:
  "IPA certifies P(belief≤x*) to within a 0.02–0.12 band from a single propagation; matching that
  precision with Monte Carlo requires 267–9,604 samples (worst-case planning), and even then yields a
  statistical estimate, not a guarantee; BDD/point methods have no analytic route to this bound at all."
- cvxP soundness-proof literature check (item #2, DEPRIORITIZED, 2026-07-27) — checked PBA's own source
  (its "known correlation" path uses a Gaussian-copula parametric assumption, not a distribution-free
  positive-dependence bound — no help), Williamson&Downs 1990 + Ferson et al. 2003 Sandia report (establish
  the FULLY-UNKNOWN Fréchet bound = cvxF, no distinct "known-positive-only" category), and Iskandar 2026
  (arXiv 2606.19086, "Probability Bound Analysis for Dependence Uncertainty," last month, exactly on-topic)
  — its framework is a TRICHOTOMY (independence / fully-specified copula / fully-unknown Fréchet), no
  partial-positive-dependence category either. Attempted own derivation via Tchen's supermodular-ordering
  theorem (the standard tool for "more concordant copula ⟹ ordered expectation"): does NOT cleanly apply —
  `1{X+Y≤z}` is neither globally supermodular nor submodular; concrete counterexample constructed
  (X,Y~Uniform(0,1)): the independent-sum and comonotonic-sum CDFs CROSS around the mean rather than one
  uniformly bounding the other, so "positive dependence sandwiches pointwise between Π and M" does not
  follow from a one-line citation and may need its own bespoke proof (or could be false as a general
  copula-class claim, even if true for our SPECIFIC functional structure — untested). VERDICT: this is a
  genuine open research question, not a lookup; deprioritized for this submission. Lead with cvxF
  (provable) as the guaranteed claim; present cvxP as empirically-validated-tighter (20/38, unsound=0.000).
- interval_bdd_vs_ipa_timing.csv (item #7, 8 corpus families: counterexample/multisource/grid4x4/
  layered4x6/bridge5/seriesparallel/complete8/random_n25) — DONE: `validation/interval_bdd_vs_ipa_timing.jl`.
  IPA-interval (one propagation) vs sifted-BDD-interval (build + 2 corner evals), min-of-3, ms:
    counterexample 0.81 vs 52.3 (65x)   multisource 22.0 vs 193.8 (8.8x)   grid4x4 0.58 vs 55.0 (95x)
    layered4x6 4.00 vs 58.4 (14.6x)     bridge5 13.3 vs 48.3 (3.6x)        seriesparallel 2.66 vs 64.1 (24x)
    complete8 1.58 vs 49.4 (31x)        random_n25 40.3 vs 117.2 (2.9x)
  RESULT STRONGER THAN EXPECTED: IPA-interval is FASTER than BDD-interval on every family (2.9x-95x), not
  merely competitive. Cause: BDD pays sifting/build cost per one-shot query; IPA's diamond conditioning
  already computes the interval range in the SAME pass as Float64 (no separate "build" phase). HONEST
  FRAMING (do not overclaim): this is the one-shot-query cost (build a diagram once, get one interval
  answer) — NOT a general "IPA beats BDD" claim (elsewhere: both are ~2^width, no structural advantage). A
  workload that reuses the SAME diagram for many repeated point/interval queries would amortize BDD's build
  cost across queries and could favor BDD; that amortized-reuse scenario is out of scope here (untested).

================================================================================================
## 7. Paper writing pointers
- ../PAPER_GUIDE.md §1.5 (imprecise claims), §3 (wording), §4 (diamond set theory), §5 (complexity).
- ./pbox_operator_and_soundness.md — operator table, sound≠tight, tightness numbers (paper-ready).
- Suggested new subsection "Imprecise / non-fixed probabilities"; lead interval (proven exact) then p-box
  (sound analytic bounds, novel vs BDD), disclose the tightness envelope as a figure. Do NOT claim p-box
  tightness where it's conservative; do NOT conflate sound with tight.
