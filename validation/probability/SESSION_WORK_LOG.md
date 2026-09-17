# IPA / RESS revision — complete work record (validation, fixes, p-box)

A chronological record of everything investigated, fixed, and validated across the whole effort
(including work predating context compaction, reconstructed from the session summary + memory). Purpose:
a single reference of what was done and why, and the state of every claim.

================================================================================================
## 0. Overarching goal
Validate, harden, and (imprecise-)generalise the Information Propagation Algorithm (IPA) for exact
source-to-node network-reliability on DAGs, and assemble evidence to answer RESS reviewers. Reliability
model: belief(v) = P(v operational AND reachable from a source); every path works iff all its nodes AND
edges are up; monotone in every probability.

================================================================================================
## 1. Validation harness & exact oracles (pre-compaction)
- Built an in-process validation harness under `validation/`, backed by CUDD (ROBDD) as an independent
  EXACT oracle: `validation/oracles.jl` (CUDD build/eval), `validation/bdd_oracle.jl`
  (`bdd_reliability`, naive + sifted via CUDD_REORDER_SIFT; returns beliefs + node count),
  `validation/oracles_tiered.jl` (path-enum + tiered Monte Carlo). Graph generators: `graph_gen.jl`,
  `graph_families.jl` (multisource / grid / layered / bridge / series-parallel / complete).
- Decision: dPrPm (the prior method) is NOT reproducible (implementation unavailable, authors
  unreachable) → CUDD ROBDD is adopted as the reproducible exact validation baseline; dPrPm runtimes are
  quoted only as indicative/non-controlled.

================================================================================================
## 2. Exactness: bugs found and fixed (pre-compaction) — IPA is now exact on general DAGs
Historically IPA had TWO correctness bugs on general (reconvergent) DAGs (see memory
[[ipa-exactness-counterexample]]):
- BUG #1 hybrid-reuse: cross-context reuse of cached diamond structures dropped parents. 
- BUG #2 core completeness: partial cutsets left residual dependence.
RESOLUTION: recursive conditioning done right — at a correlated join, condition on ONE shared fork at a
time via EXACT total probability, recurse until parents are conditionally independent, then inclusion-
exclusion; memoise per (node, conditioning∩ancestors). Reference: `validation/rc_core.jl` (RCCore).
Ported into the framework as `new_identify` (NewIdentify.jl), replacing the buggy Pipeline_Rewrite path.
- `is_det` correction: only prior-0 (dead) and prior-1 SOURCES are deterministic/non-conditionable; a
  prior-1 NON-source fork has uncertain reachability and must stay conditionable. (A regression here once
  gave 0 diamonds on the all-1.0 grid → wrong; fixed.)
- Independent-diamond FACTORISATION: partition a join's parents into groups with disjoint un-conditioned
  ancestry (union-find); one diamond per correlated group; independent groups combine by inclusion-
  exclusion. Turns fan-in-k from 2^k to O(k).
- Framework `||`→`&&` fix in the non-diamond-parents branch (was summing independent parents instead of
  IE). `one_value(pbox)` fixed from [1,1.1] (mean>1 bug) to [1,1].
VALIDATION: counterexample-n15 under its ORIGINAL triggering priors now matches CUDD to 1.11e-16
(`validation/cex_triggering_check.jl`); full corpus 129/129 exact; consolidated sweep 24/24 families ×
perfect/imperfect exact for Float64 AND Interval. IPA IS now a general exact reliability method on DAGs.

================================================================================================
## 3. Consolidated "widest" sweep (post-compaction)
`validation/consolidated_sweep.jl` → `data/consolidated_sweep.csv`: every family + random n15/20/25 under
PERFECT (nodes 1.0, links 0.9) and IMPERFECT (random) regimes, Float64 AND Interval vs sifted BDD.
Result: 24/24 "ok" — Float64 ≤3.3e-16, Interval ≤2.2e-16. (Re-run after the p-box port: still all ok.)

================================================================================================
## 4. Paper guide + set-theoretic diamond formalism (post-compaction)
`PAPER_GUIDE.md`: headline claims, revision structure mapped to reviewer concerns, reuse-ready wording,
reproduction pointers, reviewer crosswalk. §4 gives a SET-THEORETIC formalism of the diamond method:
model + reachability DNF, influence sets infl(u;E), and three lemmas with proofs — Conditional
Invariance (total probability), Separator Sufficiency (noisy-OR base), Independent-Diamond Factorisation
(2^k→O(k)) — plus the constructive recursion R(v,E) that rc_core/new_identify implement.

================================================================================================
## 5. Complexity — made DEFINITE (post-compaction)
Per-instance cost = sum over the diamond recursion of 2^|C_d|·O(|E_d|) (C_d = conditioning set). Definite,
computed by new_identify. `validation/complexity_validate.jl` → `data/complexity_validation.csv`: reports
n_diamonds, maxcond (exact conditioning width), measured_ops, bdd_nodes. Honest finding: a naive TOP-LEVEL
sum of 2^|C_d| UNDER-counts (misses nested diamonds), so we report measured_ops (realised work) and the
parametric claim maxcond ≈ log2(bdd_nodes) (same width parameter; IPA ≈ BDD, both ~2^width, neither
dominates). §5 of the guide states the exact formula + this honest caveat.

================================================================================================
## 6. Timing & profiling (post-compaction)
`validation/timing_imprecise.jl`, `grid_case_study/bench_grid.jl` → cost per type. Findings:
- Interval overhead ≈ 1.2–1.6× Float64 (essentially free; backend-independent).
- p-box cost ~quadratic in discretisation steps (O(steps²) convolutions); large absolute multipliers.
  Honest note: these are REAL (not an interpreted-mode artifact — corrected an earlier wrong caveat);
  p-box@800 impractical on big graphs.
- Profiling (`notes/profile_breakdown.md`): for p-box, 98% of time and 100% of allocations are in PBA
  (the discretised convolution), ~0% in IPA's own logic → IPA's algorithmic overhead is the Interval
  figure; the p-box cost is entirely the p-box arithmetic backend.

================================================================================================
## 7. Grid case study (post-compaction)
- Grid Float64 config IDENTIFIED = paper/dPrPm's: all nodes 1.0, links 0.9 ("main scenario - dt")
  (`validation/grid_identify.jl`: config A matches the paper table to 5-dp rounding; vs CUDD full
  precision 1.11e-16 — the 4.75e-6 was the paper's rounding, not IPA error).
- Role split (README): grid = METHODOLOGY demonstrator (exact validation + BDD perf + the T-ladder);
  drone PARETO configs = APPLIED reliability case study (deferred Pareto methodology to a separate chat).
- Locked case-study inputs: Float64 = paper values; Interval [v-w,v+w]; p-box triangular(mode v, ±w);
  perfect nodes exact 1.0 in every T; w∈{0.05,0.10}. Oracles: Float64→sifted BDD; Interval→BDD corners;
  p-box→Monte Carlo (+ naive baseline).

================================================================================================
## 8. p-box: the big arc — UNSOUND → diagnosed → fixed → ported → validated (post-compaction)
See memory [[pbox-conditioning-unsound]]. This is the most consequential thread.
1. DISCOVERY: the grid case study exposed the FRAMEWORK's p-box output as UNSOUND (grid config A node 16:
   0.34 error, probability mass >1), while Float64/Interval were exact. Corpus `pbox_sweep` had only
   looked sound because it checks soundness (not tightness) on shallow/mid-range targets.
2. RULED OUT false leads: NOT the Frechet-suppression edit (corpus passed after it; that line was dead
   code; `convFrechet` intact — timing proved it). convIndep was ON, not off.
3. DIAGNOSIS: the conditioning recombination belief = W·A + (1−W)·B (W=P(fork)) is a CONVEX COMBINATION,
   but the framework computed it with convIndep = a CONVOLUTION (sum of independent RVs) → over-wide,
   mass>1, worsening with reconvergence depth; unsound once mass crosses the 1.0 ceiling (belief near 1,
   e.g. perfect nodes). (`validation/pbox_diag.jl` localised it: not triangular construction; the
   conditioning; CDF dump showed mass>1.)
4. FIX (correct math): integrate over the weight W's OWN distribution, blend the branches per weight
   level, envelope over W's imprecision: `M = mixture over w-levels of W[ blend(w·A,(1−w)·B,+) ]`.
   `validation/rc_pbox_cvx.jl`: the naive PBA.mixture (stochastic pick) and convIndep-convolution both
   fail; the convex-combination operator works.
5. OPERATOR CHOICE (provability vs tightness):
   - cvxF = full-Frechet branch blend → PROVABLY sound (bounds all copulas), conservative/vacuous on hard cases.
   - cvxP = env(convIndep, convPerfect) = POSITIVE-DEPENDENCE bound (branches monotone ⇒ positively
     dependent) → tighter, empirically sound. CHOSEN operator.
   Broad soundness `validation/cvx_sound.jl`: cvxP SOUND on 20/20 configs (10 topologies × perfect/uncertain).
   Tightness `validation/cvx_lean.jl`: tightens vacuous cases 1.0→0.7–0.8 but stays wide on strongly-
   reconvergent uncertain; tight (0.05–0.18) on high-reliability. Scalability: O(steps³)/recombination,
   SMALL networks only.
6. FRAMEWORK PORT (done + validated): `pbox_conditional_combine` + `PBOX_COND_BLEND` Ref(:positive|:frechet)
   in `InputProcessingModule.jl`; explicit import in `ProbabilityPropagationModule.jl`; DiamondPropagation.jl
   Phase 2 p-box branch replaced with NESTED 2-way convex combination (one conditioning node at a time),
   Float64 (flat sum) and Interval (corner enumeration) branches UNTOUCHED. Validation
   `validation/validate_framework_pbox.jl`: framework p-box SOUND vs MC (grid 0.34→0.000; grid-uncert /
   bridge5 / random all sound); `consolidated_sweep` confirms Float64 (≤3.3e-16) + Interval (≤2.2e-16)
   still exact. Toggle PBOX_COND_BLEND[]=:frechet for the provable-conservative bound.

SOUND ≠ TIGHT (stated in `notes/pbox_operator_and_soundness.md`): sound = contains truth (correctness);
tight = narrow (precision). All configs sound; tightness varies (band ±3% to ±34%) with reconvergence
depth × input uncertainty; range (interval) is exact even where the p-box shape is loose.

================================================================================================
## 9. Settled paper position (imprecise)
- Float64: exact. Interval: EXACT (machine precision; monotone corners; = BDD corners). PROVEN.
- p-box: GUARANTEED-sound analytic bounds via the convex-combination operator — NOVEL vs BDD (no analytic
  distributional propagation exists for decision diagrams). Tight in the high-reliability regime,
  conservative-but-sound on adversarial reconvergent-uncertain, small-network only. Rigor is layered:
  interval = theorem; p-box cvxF = provable-sound; p-box cvxP = tight empirically-validated refinement.
- Complexity: IPA ≈ BDD (both ~2^width), neither dominates; IPA's niche is native imprecise propagation.
- Suggested new paper subsection: "Imprecise / non-fixed probabilities" (justifies the case-study emphasis).

================================================================================================
## 10. Key files
Framework edits: InputProcessingModule.jl (pbox_conditional_combine, PBOX_COND_BLEND),
ProbabilityPropagationModule.jl (import), DiamondPropagation.jl (Phase 2 pbox nested combine),
NewIdentify.jl (recursive-conditioning producer), + earlier CorePropagation/TypesAndCache edits.
Reference/validation: rc_core.jl, rc_pbox_cvx.jl, cvx_sound.jl, cvx_lean.jl, corpus_cvx*.jl,
validate_framework_pbox.jl, pbox_diag.jl, consolidated_sweep.jl, complexity_validate.jl, grid_identify.jl,
grid_envelope.jl, bench_grid.jl, timing_imprecise.jl.
Paper: PAPER_GUIDE.md (+ §4 set theory, §5 complexity, §1.5 imprecise), notes/pbox_operator_and_soundness.md,
notes/profile_breakdown.md, this file, data/*.csv.

================================================================================================
## 10b. Tightness envelope + PBA precision (post-compaction, DONE)
- `validation/grid_envelope.jl` → `data/grid_envelope.csv`: framework cvxP vs MC on the grid across
  {triangular,uniform,skewed} × w{0.05,0.10,0.15} × {perfect,uncertain}. 18/18 SOUND (unsound=0.000).
  Band: perfect 0.18–0.44 (grows with w), uncertain 0.60–0.70 (~flat). => sound regardless of input
  DISTRIBUTION shape; tightness driven by regime (reconvergence) then width. The characterised-envelope figure.
- PBA source analysis (notes/PBOX_HANDOFF.md §5): PBA arithmetic is OUTWARD-binned ⇒ SOUND modulo Float64
  ULP round-off (no directed rounding — standard W&D caveat). mixture re-discretises (no blow-up). The
  "Disagreement" warning is a benign moment heuristic (silence: PBA.setVerbose(1)). [0,1] not enforced by
  PBA, but cvxP is a convex combination ⇒ stays in [0,1] by construction. Bounded inputs avoid tail
  truncation. We use SOUND primitives correctly; main tightness lever = steps.

## 11. Open items
- CERTIFIED-BOUND vignette (grid): IPA certifies P(belief≤x*)∈[a,b] in 1 pass vs MC ~N samples (no
  guarantee) vs BDD n/a analytically — the decision-relevant "stronger vs BDD" argument (spec: HANDOFF §4.6).
- INTERVAL BDD-vs-IPA timing (corpus): confirm IPA-interval time-competitive with BDD 2-corner route
  (spec: HANDOFF §4.7).
- (Optional) soundness PROOF for cvxP; or feature cvxF (provable) + cvxP (tight). Component-cutset exact
  p-box as a stretch (HANDOFF §4.5). Optional [0,1] clamp + setVerbose(1) hardening.
- (Optional) soundness PROOF for cvxP, or feature cvxF as provable + cvxP as tight.
- Drone Pareto case-study reliability discussion (separate chat; needs the source paper).
- Broader/real-network p-box (tractability permitting).
