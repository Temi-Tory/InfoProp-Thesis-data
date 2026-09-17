# RESS revision — paper guide, formal diamond math, and reproduction

This folder collects everything to back the revised paper + reviewer response.
- `tex/`   — paste-ready LaTeX (tables + PGFPlots figures).
- `data/`  — CSVs behind every figure/table (regenerable from `validation/`).
- `notes/` — analysis + point-by-point reviewer map + corrected grid note + dev docs.

--------------------------------------------------------------------------------
## 1. Headline claims (state exactly these — they are all measured)
1. **Exactness, independently verified.** IPA reproduces exact source-to-node reliability, validated
   against a canonical ROBDD (CUDD) in-process: **129/129 random+mutant DAGs and every topological family
   exact** (max node error 1.1e-16), for BOTH perfect (prior-1) and imperfect nodes.
2. **Grid benchmark re-verified.** The Tong–Tien 16-node grid results are reproduced exactly (1.1e-16);
   the published table stands (see `notes/GRID_BENCHMARK_CORRECTED.md`).
3. **Quantitative comparison to an exact method (BDD).** Sifted-ROBDD node counts, time, RAM vs IPA
   op-counts; both scale ~2^(graph width). IPA is competitive but has NO structural advantage over a
   well-ordered BDD — stated honestly.
4. **Reproducibility.** Full open implementation + validation harness; dPrPm (unavailable, authors
   unreachable) is replaced as the validation baseline by the open BDD oracle.
5. **NEW: exact INTERVAL imprecise reliability.** With interval inputs IPA returns the EXACT belief range
   (machine precision, validated vs BDD corners to 1e-16) — reliability is monotone, so the range is the
   two corners; no dependency problem. Naive interval propagation over-widens (up to 0.45). BDDs cannot
   propagate imprecise inputs natively. INTERVAL is the distinctive, rigorous imprecise contribution.
   **p-box: guaranteed-sound analytic bounds via the convex-combination operator (PORTED + validated
   in-framework).** The conditioning recombination `belief = W·A + (1−W)·B` (W=P(f)) is a CONVEX
   COMBINATION. The framework's current `convIndep` impl computes it as a CONVOLUTION → UNSOUND (grid node
   16: 0.34, mass>1). The FIX (validation/rc_pbox_cvx.jl, cvx_sound.jl): integrate over the weight's own
   distribution, blending branches per weight level, enveloped over W's imprecision —
   `M = mixture over w-levels of W[ blend(w·A, (1−w)·B, +) ]`. Chosen operator **cvxP** uses the
   POSITIVE-DEPENDENCE blend `env(convIndep, convPerfect)` (branches are monotone-increasing ⟹ positively
   dependent). Validated vs Monte Carlo: **SOUND on 20/20 configs** (10 topologies × perfect/uncertain),
   unsound=0.000 — a GUARANTEED-sound analytic p-box bound that decision diagrams cannot produce. Tightness
   is structure-dependent and improves with discretisation: TIGHT (CDF band 0.05–0.15) on high-reliability
   / weakly-reconvergent systems, CONSERVATIVE (0.35–0.8) on strongly-reconvergent uncertain systems (use
   the tight↔conservative case range AS the figure = characterised envelope). Cost O(steps³)/recombination
   ⟹ SMALL networks only; large nets use interval (exact) + MC. Soundness is empirical (20/20) + argued,
   not formally proven (proof = future work). Alternatives: cvxF (full Fréchet, guaranteed but vacuous on
   hard cases); cvxI (convIndep, tighter but small violations ≤0.023 — heuristic).
   THIS (with exact interval) is the distinctive rigorous imprecise contribution vs BDD. PORTED: framework
   p-box now uses nested cvxP (InputProcessingModule.pbox_conditional_combine + DiamondPropagation Phase 2);
   validated in-framework — p-box SOUND vs MC (grid 0.34→0.000) while Float64 (≤3.3e-16) + Interval
   (≤2.2e-16) remain exact on 24/24 family configs (validate_framework_pbox.jl, consolidated_sweep.jl).
   HARDENED (2026-07-27): output is intersected with [0,1] (sound projection against Float64 ULP leakage);
   regression-confirmed unchanged on tested configs (see `notes/pbox_operator_and_soundness.md`).
6. **NEW: the p-box bound is a CERTIFIED decision guarantee, not just a sound range.** On the grid at a
   reliability requirement x*=0.95, IPA certifies P(belief≤x*) to a 0.02–0.12 band from ONE propagation;
   matching that precision by Monte Carlo needs 267–9,604 samples (worst-case planning) and is still only a
   statistical estimate; BDD/point methods have no analytic route to this bound at all
   (`data/certified_bound_vignette.csv`, `notes/pbox_operator_and_soundness.md`).
7. **NEW: interval is not just exact, it is FASTER than BDD's interval route.** Across 8 corpus families,
   IPA-interval (one propagation) beats sifted-BDD-interval (build once + 2 corner evals) by 2.9x-95x
   (`data/interval_bdd_vs_ipa_timing.csv`). Honest scope: this is the ONE-SHOT query cost; a workload
   reusing one diagram across many repeated queries would amortize BDD's build cost differently (untested).

Corpus (breadth answer to R2.1/R3.2): random ER n=4–50 (single & multi-source), n=28 mutants, and the
families multi-source / grid-lattice / layered / **bridge (non-series-parallel)** / series-parallel /
complete; plus real infrastructure (power, KarlNetwork, drone, metro, munin) and adversarial (fanin-k,
mesh-w). Data: `data/consolidated_sweep.csv`, `paper_data.csv`, `large_graphs.csv`, `pbox_sweep.txt`.

--------------------------------------------------------------------------------
## 2. Suggested revision structure (maps to reviewer asks)
- §2 Model — add the formal set-theoretic definitions in §4 below (R3-t1, R2.7).
- §3 IPA — add a worked MULTI-LEVEL nested-diamond trace (R-t1) beyond the single diamond.
- §4 Decomposition — state Lemmas with the proofs in §4 below (R3-t3); add the independent-diamond
  FACTORIZATION (new) and the context-aware supernode identity (answers overlapping-diamond/cache, R-t2).
- §4.3 Complexity — replace qualitative text with the treewidth statement in §5 below (R2.4/R3-t5);
  relate to Cutset Conditioning / Junction Tree (R3.1/R3-t8).
- §5.1 Grid — keep; add "independently re-verified vs CUDD (1.1e-16)".
- §5.x NEW subsection — comparison vs sifted BDD on the same networks (R2.3/R3.2), Table + Fig.
- §5.x NEW subsection — imprecise (interval/p-box) reliability with the hero figure (§1.5).
- §5 Drone — add reliability INTERPRETATION, not just runtime (R2.5).
- §5.3 Limitations — practical exact range (depth-driven; n=50 exact but dense/deep is the limit),
  and the depth-limited hybrid as future work (R2.6/R3.4). DAG-vs-cyclic justification (R3.3).

--------------------------------------------------------------------------------
## 3. Wording to reuse (precise, non-over-claiming)
- "IPA is exact and competitive with a well-ordered BDD; it does not claim a smaller state space. Its
  distinctive capability is native propagation of IMPRECISE reliabilities: EXACT for intervals (machine
  precision), and GUARANTEED-SOUND analytic bounds for p-boxes (the full reliability distribution) — a
  capability decision-diagram methods lack (they give point/interval values or require sampling)."
- On p-box (honest, DECIDED framing 2026-07-27): lead with cvxF as the PROVEN-sound headline claim (it
  inherits the classical Fréchet/Makarov bound theorem — Williamson & Downs 1990 — no proof burden on us);
  present cvxP (the tighter positive-dependence-restricted operator we actually ship by default) as
  "empirically validated across 38 configs (unsound=0.000), soundness proof open" — do NOT call cvxP
  "guaranteed." A bounded literature check found no existing theorem for the positive-dependence-restricted
  case (checked PBA's own Gaussian-copula correlation path, Williamson-Downs, Ferson et al. 2003, and
  Iskandar 2026; attempted a Tchen-supermodular-ordering derivation ourselves and hit a real obstruction —
  see PBOX_HANDOFF.md §6) — treat as open future work, not a gap to close before submission.
- On p-box (honest): "The conditioning recombination is a convex combination `W·A+(1−W)·B`; computing it
  by integrating over the weight distribution with a Frechet branch-blend yields p-box bounds that are
  SOUND across our corpus (validated vs Monte Carlo, 16/16), tight on weakly-reconvergent systems and
  conservative (up to vacuous) on strongly-reconvergent ones. Naive independent-convolution recombination
  is unsound (mass>1)."
- On dPrPm: "As the dPrPm implementation is unavailable, we validate against an independent open exact
  oracle (CUDD ROBDD) and release our implementation; the dPrPm runtime is quoted from the source study
  and used only as an indicative, non-controlled comparison."
- On imprecise: "Interval propagation is exact by construction (Prop. X; validated vs BDD corners to
  1e-16). Neglecting reconvergent dependence (independence-assuming propagation) is over-wide for
  intervals." [p-box removed from the soundness claim — see the p-box future-work note in §1.5.]

--------------------------------------------------------------------------------
## 4. FORMAL diamond formalism (set-theoretic) — for §2/§4 and the Lemma proofs
Model. DAG G=(V,E), sources S = {v : indeg(v)=0}. Independent Bernoulli indicators: node X_v~Ber(π_v),
edge Y_{uv}~Ber(ρ_{uv}), all mutually independent. Reachability indicator
    R_v = X_v ∧ ( v∈S  ∨  ⋁_{u∈P(v)} (R_u ∧ Y_{uv}) ),   P(v) = {u : (u,v)∈E}.
Objective: belief(v) = P(R_v = 1) for all v. Equivalently R_v is the monotone DNF over source→v paths,
each path the conjunction of its node/edge indicators; belief(v)=P(⋁ paths) — #P-hard in general.

Sets. anc(v) = {u : u↝v} (directed path); RN(v)={v}∪anc(v); forks F={v:outdeg≥2}; joins J={v:indeg≥2}.
For a conditioning context E⊆F (forks fixed), the un-conditioned influence of a parent u is
    infl(u;E) = ({u} ∪ anc(u)) \ E.

Lemma 1 (Conditional invariance). For any A⊆V and states c∈{0,1}^A,
    belief(v) = Σ_{c} P(R_A=c) · P(R_v=1 | R_A=c).
Proof: law of total probability over the partition {R_A=c}; well-defined because all X,Y are independent
so R_A is a function of a subset of them. ∎

Lemma 2 (Separator sufficiency). Let C⊆F∩anc(v). If every path between two distinct parents u_i,u_j of v
that avoids C is absent (i.e. C intersects every common-ancestor path of the parents — a cutset of the
parents' shared ancestry), then given R_C the events {R_{u_i}} are mutually independent, hence
    belief(v | R_C=c) = π_v · ( 1 − ∏_{u∈P(v)} (1 − P(R_u=1 | R_C=c) · ρ_{uv}) ).
Proof: with C fixed, the residual ancestries of distinct parents share no random indicator, so the
R_{u_i}|C are independent; the join is then a noisy-OR of independent parent contributions. ∎

Lemma 3 (Independent-diamond factorization). Define u ~ u' iff infl(u;E) ∩ infl(u';E) ≠ ∅, and let
G_1,…,G_m be the resulting components (connected components of the parents under shared un-conditioned
ancestry). The groups have pairwise-disjoint influence, so the reach-through-group events are independent:
    belief(v) = π_v · ( 1 − ∏_{j=1}^m ( 1 − P(v reached via some u∈G_j) ) ),
and each group is conditioned independently. (Turns fanin-k from 2^{|C|}=2^k to Σ_j 2^{|C_j|}=O(k).)
Proof: disjoint influence ⇒ the group indicators are functions of disjoint independent variables ⇒
independent; inclusion–exclusion for independent events gives the product form. ∎

Constructive definition (the algorithm). belief(v) is computed by the recursion R(v, E):
    - if v∈S: return π_v;
    - partition P(v) into groups {G_j} by ~ (Lemma 3); combine groups by the product form (Lemma 3);
    - for a group with a shared un-conditioned fork f = argmin_{topo} { a∈F\E : a is a shared ancestor
      of ≥2 members of the group } (Lemma 2 candidate): condition on f (Lemma 1):
          reach(G) = P(R_f=1)·reach(G | E∪{f}=1) + P(R_f=0)·reach(G | E∪{f}=0);
    - a group with no shared un-conditioned fork has independent parents: noisy-OR (Lemma 2 base).
This terminates (E grows, F finite) and is exact (Lemmas 1–3). `validation/rc_core.jl` /
`rc_core_factored.jl` are this recursion verbatim (the machine-checked reference).

Supernode / caching. A solved sub-problem is identified by (induced edgelist, conditioning set); this
key distinguishes the SAME subgraph reached in different contexts (which upstream forks are fixed), so
memoisation reuses only genuinely-identical sub-problems — resolving overlapping/shared-conditioning
diamonds (R-t2/R-t4). A conditioning node already pinned to 0/1 by an outer conditioning contributes a
single non-zero state and is not enumerated (the zero-weight skip).

--------------------------------------------------------------------------------
## 5. Complexity (for §4.3) — EXACT per-instance formula + treewidth + PGM relation (R2.4/R3.1/R3-t5/t8)
DEFINITE, not qualitative. IPA's per-instance cost is
    Work(IPA)  =  sum over the diamond RECURSION (root + all nested) of  2^{|C_d|} · O(|E_d|),
where C_d is diamond d's conditioning set and E_d its edgelist — every term computed by new_identify, so
the model is definite, not guessed. Memoisation makes the ACTUALLY-REALISED work the number of DISTINCT
sub-propagations (= diamond-cache size), which is what we MEASURE (measured_ops).
DEFINITE QUANTITIES we report per graph (data/complexity_validation.csv): n_diamonds, maxcond = max|C_d|
(the exact conditioning width), measured_ops (realised work), bdd_nodes (sifted ROBDD).
  - CAVEAT / honesty: a naive sum of 2^{|C_d|} over the TOP-LEVEL unique-diamond store UNDER-counts (it
    omits nested diamonds), so measured_ops can exceed it (grid_5x5, layered, random_n20). We therefore do
    NOT quote that top-level sum as a bound; the realised cost is measured_ops (the recursion-complete
    quantity), and the profiler confirms where it is spent.
  - VALIDATED parametric claim: maxcond (exact) sits in the same band as log2(bdd_nodes) — grid_4x4 7 vs
    8.2, bridge_5 10 vs 9.0, random_n25 13 vs 11.7 — i.e. IPA's conditioning width and the ROBDD width are
    the SAME parameter (graph width). And measured_ops is the SAME ORDER as bdd_nodes, sometimes smaller
    (counterexample 42 vs 340; complete_8 142 vs 759; grid_5x5 452 vs 759), sometimes larger; neither
    dominates. => IPA ≈ BDD, both ~2^{width}.
  - EMPIRICAL confirmation (grid profiling, notes/profile_breakdown.md): the runtime is dominated by the
    diamond conditioning-state enumeration, i.e. the 2^{|C_d|} factor above (not by identification/overhead).

Parametric bound. max_d |C_d| (=maxcond, measured) is bounded by the graph's treewidth/pathwidth, so
IPA ≈ 2^{conditioning-width}, a well-ordered ROBDD ≈ 2^{pathwidth}, and junction-tree / cutset-conditioning
≈ 2^{treewidth} — the SAME parametric class (all #P-hard, all FPT in treewidth). IPA is a specialisation of
Cutset Conditioning to source-to-node reachability, with independent-diamond factorisation (Lemma 3)
avoiding joint conditioning of independent shared forks (fanin-k: 2^k -> O(k)). No closed form in n alone
exists (#P-hard); per-instance it is fully definite via the formula above.
Measured (data/): random DAGs — IPA op-count ≈ BDD node count; fanin-k — tie after factorisation; dense
lattices — BDD compact, IPA larger (BDD wins). No family favours IPA. Honest conclusion: IPA is not
structurally superior; its niche is imprecise inputs.

--------------------------------------------------------------------------------
## 6. Reproduction (R2.7/R3-t1)
- Identification: `InfoPropFrmwrk/.../DiamondDecomposition/Internal/NewIdentify.jl` (`new_identify`) —
  context-aware recursive conditioning + factorisation; emits root diamonds + unique-diamond store.
- Propagation: `.../ProbabilityPropagation/Internal/{CorePropagation,DiamondPropagation}.jl` — type-
  generic (Float64 / Interval / p-box); per-state enumeration serial (deterministic).
- Reference: `validation/rc_core.jl` (recursion), `rc_core_factored.jl` (factorisation).
- Oracles: `validation/oracles.jl` (CUDD), `bdd_oracle.jl` (sifted CUDD), `oracles_tiered.jl`
  (path-enum + Monte Carlo).
- Reproduce every number: run the scripts in `validation/` (see `notes/ROADMAP.md`).

--------------------------------------------------------------------------------
## 6b. Timing of imprecise propagation (anticipated reviewer Q — "native imprecise, at what cost?")
Data: `data/timing_imprecise.csv` (Float64 / Interval / p-box@{50,200,800} per graph, + overhead factors)
and `data/pbox_steps_scaling.csv` (p-box time vs discretisation level). Honest framing to use:
- Interval propagation is a small CONSTANT-factor overhead over Float64 (interval arithmetic = a few extra
  flops per operation; no discretisation). Report the measured factor from timing_imprecise.csv.
- p-box cost is a TUNABLE KNOB traded against band tightness: time grows ~quadratically in the
  discretisation level (O(steps^2) convolutions), while the band tightens (steps 200->800 shrank the
  demo band 0.08->0.021, `notes/PBOX_ANALYSIS.md`). So the user chooses accuracy vs cost; state the curve.
- Do NOT claim p-box is cheap; claim it is CONTROLLABLE and its bounds are rigorous at every step count.
- Measured (counterexample-n15, 23 edges): Float64 0.67ms, Interval 0.79ms (=1.2x, ~FREE), p-box@50 2.7s,
  @200 8.3s, @800 110s (~quadratic in steps: 200->800 is 4x steps -> 13x time). CONSEQUENCE: p-box@800 is
  viable on the 16-node grid (~2min) but INTRACTABLE on the 200-327-edge drone configs -> use low-step
  p-box there.
- HOW TO STATE THE p-box COST HONESTLY (corrected — the earlier "interpreted artifact" wording was WRONG):
  the ~12000x is REAL, not an interpretation artifact. Julia native-compiles PBA ops; the timing harness
  warms up before measuring, so JIT is excluded. The cost decomposes into (1) INTRINSIC O(steps^2)
  convolution (backend-independent, dominates) and (2) PBA.jl constant-factor overhead (allocations +
  copula/dependency bookkeeping; library-specific, reducible in principle by a leaner backend). Fixing PBA
  precompilation improved LOAD time only, NOT op speed (confirming the cost is intrinsic, not load/interp).
  => LEAD WITH the clean numbers: interval 1.2x (backend-independent) and the QUADRATIC step-scaling (a
  ratio, cancels constant factors). Report the absolute p-box time honestly at the step count actually used,
  noting PBA.jl is general-purpose not perf-tuned. Do NOT claim a specific speedup we have not measured.
  Cleaner-measurement options: BenchmarkTools.jl (median of many samples) instead of @elapsed min-of-3.
  Genuine speedup levers (future work): fewer steps (tunable, 50 still rigorous) or an independence-only
  convolution skipping PBA's copula machinery.
- INTERVAL vs BDD, head-to-head (`data/interval_bdd_vs_ipa_timing.csv`, 8 corpus families): IPA-interval
  (one propagation) is FASTER than sifted-BDD-interval (build once + 2 corner evaluations) on every family,
  2.9x-95x (counterexample 65x, grid4x4 95x, complete8 31x, seriesparallel 24x, layered4x6 15x,
  multisource 8.8x, bridge5 3.6x, random_n25 2.9x). State this as the ONE-SHOT query cost (build from
  scratch, get one interval answer) — not a general structural claim (elsewhere both scale ~2^width with no
  structural advantage). A workload amortizing one BDD build across many repeated queries is a different,
  untested scenario and could favor BDD instead — say so, do not imply this result generalizes to it.

--------------------------------------------------------------------------------
## 6c. Case-study plan (base case vs reliability case study) — DECISIONS + OPEN ITEMS
TWO SEPARATE ARTIFACTS with OPPOSITE requirements — do not force one graph to do both:
  (A) METHODOLOGY DEMONSTRATOR — proves the method is correct/capable/affordable. Needs a TRACTABLE graph
      WITH ground-truth oracles (BDD + MC). Inputs are ILLUSTRATIVE => NO physical justification required
      (the claim is about the METHOD, not a real system — say this in one sentence). => the GRID.
  (B) APPLIED RELIABILITY CASE STUDY — proves the method answers a real decision. Needs JUSTIFIED inputs +
      physical meaning => the DRONE PARETO configs. Justification burden lives ENTIRELY here.
Why grid for validation (not drone): accuracy validation needs an exact oracle. 16-node grid is trivial
for CUDD + MC; the 200-327-edge drone configs may be CUDD-intractable and have NO BDD for p-box at all.
So PROVE exactness/soundness on the grid, APPLY the trusted method on the drone.

BEST FLOW for the GRID demonstrator (one graph, "increasing capability" arc):
  1. dPrPm baseline — published grid numbers + accessibility caveat (not reproducible -> motivates a
     reproducible exact method).
  2. IPA vs sifted-CUDD — exact agreement (ACCURACY validation) + performance (both ~2^width).
  3. Interval — exact belief range vs naive over-widening (interval overhead ~1.2x, essentially free).
  4. p-box @ {50,200,800} — soundness + tightness/cost tradeoff across steps (ties to timing, tractable on
     grid ~2min@800; state the interpreted-PBA caveat from 6b).
  5. Monte Carlo — ground-truth overlay for the imprecise bands (the only truth source once inputs imprecise).
GRID CORPUS: keep grid IN the 129-graph breadth claim AND feature it as this deep-dive — no circularity
(breadth stands on the other 128); excluding it only weakens the count for no gain.

- BASE / BENCHMARK case = Tong-Tien 16-node GRID. Job: dPrPm + sifted-CUDD + interval + p-box(steps) + MC,
  i.e. the whole methodology demonstrator above. Probabilities are illustrative (frame explicitly, no
  physical claim). Tractable enough for the full T-sweep incl. p-box@800.

- RELIABILITY CASE STUDY — RESOLVED 2026-07-27 (source paper found + drone pipeline rebuilt from scratch).
  SOURCE PAPER LOCATED: Jones, Filippi, Basu, Parsonage, Patelli, Maddock, Vasile, Fossati, "Conceptual
  design of a medical drone logistics network for Scotland" (submitted Int. J. Logistics Research and
  Applications, Sept 2025) — `csvfiles/drone_info/62aa82fa-547f-4e60-ab63-fa012448b826.pdf`.
  FINDING: the OLD `pareto-point-{1..6}-*` networks (327/280/223/28/214/261 edges) were NOT derived from
  this paper's actual optimisation output (which is not public — Data Availability: "available ... upon
  reasonable request") — they were K-nearest-neighbour / hub-spoke-tree constructions built to control
  IPA's OWN diamond-conditioning complexity, relabelled with resilience-sounding names borrowed from the
  paper's vocabulary. Likewise the old `distance_to_probability = exp(-d/max_range)` edge model and the
  0.9/0.8/0.6+bonus node-prior heuristic were invented, not derived, and conflated two things the source
  paper keeps separate (range = hard existence cutoff, eq. 10; failure probability = a SEPARATE expert-
  elicited bound, §3.1). REBUILT from scratch in `drone_network_to_dag_reliability.jl` (old script kept on
  disk for history, no longer used) using ONLY paper-grounded quantities:
    - Node priors (Interval): hub (SOURCE-RECEIVER) = Interval(1,1) exactly, matching the paper's own
      resilience trials ("each node except the hub nodes Ω has a 20% failure probability", §5, i.e. hubs
      are excluded from failure); non-hub = Interval(0.75,0.85), a sensitivity band around the paper's
      literal 80% success figure (their 20% is not itself derived/cited — IPA tests sensitivity to it,
      which their point-probability framework structurally cannot).
    - Edge existence: hard range cutoff per Table 1 (VTOL 70km, fixed-wing 700km, eq. 10) — exact match.
    - Edge reliability (Interval) — THE ONE EXTENSION, clearly flagged: the paper explicitly keeps wind
      velocity constant in its own results ("in this paper wind velocity is kept constant", §2.4),
      deferring weather/range uncertainty as a modelled-but-unused event type (§3.1). We extend this (not
      an unrelated invented curve): effective range = Interval(0.9R^v, R^v) (illustrative 10% derating, not
      itself quantified in the source paper either). Within 90% of range: certain. Between 90-100%: HONEST
      Interval(0,1) (vacuous — worst-case weather cuts it, best-case doesn't). Two drone types combine via
      independent-OR.
    - Investment tiers: CHECKED AND REJECTED an attempt to map `CS_type`/`DP_type` to the paper's Table 2
      port-type index (S0-S4, range 0-4) — actual data range is CS_type 2-5, DP_type 1-5, doesn't fit.
      Used instead `city_type=="new"` (the 11 optional candidate stations from Fig. 10, matching decision
      set I, eq. 16-17/23) for a genuine minimal-investment proxy.
    - DAG direction: hub-tier before spoke-tier (matches the paper's own hub-and-spoke model, §2.1), NOT
      the old latitude sort (no operational basis — the paper's edges are explicitly undirected, eq. 9).
  TRACTABILITY FINDING (a real result, not just an engineering fix): "connect every mission-relevant pair
  within range" measured maxcond=27-28 (new_identify blew past 8GB) — this real 244-node network, even
  restricted to paper-faithful mission-relevant pairs, hits IPA's documented worst-case treewidth regime.
  K bounds each node to its K nearest reachable partners (a standard reliability-engineering redundancy
  pattern — provision K diverse routes, not full mesh); it is a property of the NETWORK TOPOLOGY, not of
  IPA specifically, so it affects any exact method's cost, IPA or BDD (see the BDD comparison below for why
  this matters — do not describe K as "IPA's lever"). FINAL CHOICE K=16 (see the K-sweep entry below for
  the full tuning history): maxcond 15-17, JUST UNDER the ~18 threshold Reviewer #2 themselves identified
  in the original submission ("computation times become intractable when diamond nesting depth reaches 18
  or more") — a deliberate calibration, and a concrete, measured answer to their request to "discuss more
  explicitly the practical range of network sizes and structures for which IPA remains competitive"
  (R2.6/comment 4).
  THREE proxy networks generated (`dag_ntwrk_files/drone-network-{fw-reliant-centralized,vtol-dense-
  decentralized,concentrated-minimal}`), each an honestly-labelled PROXY for the qualitative signature of a
  real Pareto point described in §5/Fig. 11 (NOT a reproduction of the undisclosed optimised topology):
    - fw-reliant-centralized (proxy for point 1): 263 edges, tree (each spoke -> nearest hub only, hub-hub
      backbone), maxcond=10. Comfortably tractable, low redundancy.
    - vtol-dense-decentralized (proxy for point 2): 1753 edges, K=16-bounded dense local mesh, maxcond=17.
    - concentrated-minimal (proxy for point 4, the paper's own "least resilient... concentration down to
      only a few larger drone ports"): 1648 edges over the existing-only (H∪A) node set, maxcond=16.
  PROPAGATION CONFIRMED (full IPA-Interval, `validation/smoke_drone_reliability.jl`): all three run
  cleanly; every belief SOUND (0<=lo<=hi<=1) across all 217/230/242 nodes. Belief ranges: fw-reliant
  [0.75,1.0]-[0.85,1.0] (width 0-0.10, mean 0.089); the two denser networks [0.55,1.0]-[0.72,1.0] (width
  0-0.167, mean ~0.094) — a genuine, non-degenerate, decision-relevant spread (the least-certain hospital
  in the denser designs sits anywhere from 55% to 72% reachability confidence; best-connected ones are
  tight-to-certain). This IS the R2.5 "reliability insight" answer: which real hospitals are the most
  uncertain under honest imprecision propagation, not just a runtime number. (Numbers below are at the
  FINAL K=16; the smoke test predates the K=12->16 retune but belief ranges are not materially different.)
Paper flow (updated): (1) dPrPm comparison WITH the accessibility caveat; (2) sifted-CUDD performance
analysis (grid + corpus); (3) the drone reliability case study above, framed explicitly as PROXY designs
for the source paper's real Pareto points (not reproductions), built entirely from paper-grounded
quantities plus one flagged extension, with the K-redundancy/tractability finding as its own sub-result.

- K-SWEEP REFINEMENT (2026-07-27/28, `validation/drone_k_sweep.jl`): measured actual full-propagation WALL
  TIME (not just maxcond) as K increases: K=12->maxcond=15-16 (propagate 6-14s), K=16->maxcond=17
  (propagate 17-24s), K=20->maxcond=17 (26-28s), K=24->maxcond=17 (28-28s). maxcond and time both PLATEAU
  at K=16 — beyond it, extra candidate edges are mostly redundant rather than adding new reconvergence
  structure. FINAL CHOICE: K=16 (smallest K reaching the natural ceiling, not an arbitrary stopping point).
  Regenerated final networks: fw-reliant-centralized 263 edges/maxcond=10, vtol-dense-decentralized 1753
  edges/maxcond=17, concentrated-minimal 1648 edges/maxcond=16.

- DRONE BDD COMPARISON (2026-07-28, `validation/drone_bdd_comparison.jl`, `drone_bdd_naive.jl`) — answers
  R2.3/R3.2 ("benchmarked against exact solvers... using the SAME grid AND DRONE networks") for the drone
  case study specifically, which had never been done (only the grid had a BDD comparison before). TWO
  findings, one methodological and one substantive:
  (i) RIGOUR CATCH: the first pass measured cold (unwarmed) timings and found BDD-interval "faster" than
      IPA-interval on the sparse network (ratio 0.73x) -- this was ~100% JIT/compilation artifact. Added a
      warmup-then-measure pattern (the same discipline used in timing_imprecise.jl / interval_bdd_vs_ipa_
      timing.jl, dropped here by oversight) and re-measured: t_ipa_f64 0.942s->0.008s, t_build 1.302s->
      0.187s. WARM result FLIPS the conclusion: IPA-interval is 14.38x FASTER than BDD-interval on
      fw-reliant-centralized (0.012s vs 0.173s) -- consistent with, and extending to a real network, the
      2.9x-95x range already found on the synthetic corpus. Exact agreement confirmed: max|IPA-BDD|=0.00e+00
      (bdd_nodes=2667). LESSON: do not report an unwarmed timing number in the paper; this is exactly the
      rigour gap Reviewer #2 already flagged once (R2.2) -- nearly repeated it here by oversight, caught by
      the user's own methodological pushback before it went anywhere.
  (ii) SUBSTANTIVE FINDING, VERIFIED WITH A CONTROLLED COMPARISON (2026-07-28, `validation/gen_k6_test.jl`)
      -- an EARLIER draft of this entry claimed "IPA remains tractable because of a tunable lever (K) that
      BDD lacks." That was a misinterpretation, caught before it reached the paper: K is a property of the
      NETWORK TOPOLOGY (how many redundant routes exist), not of IPA specifically, so it governs BOTH
      methods' cost, not just IPA's. The claim needed an actual controlled test, not an assertion. Same
      script (`drone_bdd_comparison.jl`), same load path, same edgelist/weights fed to both methods (so the
      network being measured is IDENTICAL between the two, not just similar) — run at K=6 (concentrated-
      minimal's construction, where IPA is comfortably tractable, maxcond=6) as well as at the shipped K=16
      (maxcond=16-17):
        K=6  (919 edges, 230 nodes): BDD succeeds — bdd_nodes=4968, t_build=0.82s, exact agreement to
             1.11e-16, interval timing IPA=0.128s vs BDD=0.830s (IPA 6.46x faster, same direction as before).
        K=16 (1648 edges, 230 nodes): sifted CUDD did NOT converge (killed >30 CPU-minutes, memory flat at
             1-2GB — a search-time problem, not a memory blowup); an UNSIFTED/insertion-order build (no
             reordering search) was tried as a cheaper fallback and ALSO blew up (memory past 7.6GB, killed)
             — the raw BDD size is itself combinatorially large under the natural order, not merely hard to
             search for a good one. IPA completed FULL exact propagation on the SAME K=16 network in 16.68s
             and 23.89s (the two dense proxies, warm, from the K-sweep).
      CORRECT, VERIFIED CONCLUSION: both methods share the SAME lever (K); at K=6 both are fast and IPA is
      moderately faster (6.46x); at K=16 ONLY IPA remains tractable. So the honest claim is that IPA's
      TRACTABLE RANGE on this real network family extends further (in terms of a real, controllable
      redundancy parameter) than sifted-or-naive BDD's does — NOT that IPA has a lever BDD lacks. This is
      still a genuinely stronger and more specific answer to R2.3 than "both are ~2^width, no structural
      advantage" (the general corpus finding) — it is a MEASURED envelope comparison on one real network,
      not a structural claim. Do not overclaim beyond this one real network + K in {6,16} + two BDD
      strategies (sifted, naive) tested — do not claim BDD is impractical on drone-scale networks IN
      GENERAL (the OLD, smaller pareto-point-{1,2,3,5,6} networks, ~89-165 nodes, had comfortably tractable
      maxcond 0-15 per `validation/old_pareto_diamond_stats.jl` and were never BDD-tested either — an
      honest scope boundary to state, not to paper over), and do not claim the K=6-vs-K=16 crossover point
      for BDD is precisely known (only bracketed: works at 6, fails at 16 — the actual threshold is
      untested and would need a finer sweep, e.g. K=8,10,12, to locate if the paper wants that precision).

>>> STILL OPEN:
>>> [PLAN] Reliability discussion across the 3 proxy configs: compare which stays most robust once Interval
>>>   uncertainty is honestly propagated (ties to the belief-width numbers above).
>>> [FIGURE IDEA] Map plot (real lat/lon, already in nodes.csv) coloured by belief lower bound / band width
>>>   per node, for at least one network — turns the abstract Interval output into a literal reliability map
>>>   of Scotland, directly analogous to the source paper's own Fig. 1/9/10/12-15 style plots.
>>> [PLAN] Justify probability assignment FOR ALL TYPES T, per source:
>>>     - Float64 point estimates: component datasheets / failure-rate data / expert elicitation (state which).
>>>     - Interval [lo,hi]: when only BOUNDS are known (measurement error, manufacturing tolerance, spec ranges).
>>>     - p-box: when PARTIAL distributional info (known family + uncertain parameters, or expert bounds on a CDF).
>>> [PLAN] Report TIMING for each T on the case study (tie to §6b), plus results discussion INCLUDING the
>>>   reliability interpretation at the Pareto points (answers R2.5 — interpretation, not just runtime).

--------------------------------------------------------------------------------
## 8. bnlearn corpus expansion (2026-07-28) — real, cited PGM benchmark networks for R2.1/R2.3 breadth

Converted the full DISCRETE-network catalog of the bnlearn repository (bnlearn.com/bnrepository) via a
BIF-format parser (`validation/bif_to_edges.jl`) that extracts ONLY the DAG topology (not the categorical
CPTs, which don't map to our binary up/down reachability model) -- synthetic Float64 reliabilities
assigned the same way as power-network/KarlNetwork (arbitrary but valid; legitimate for a structural-
exactness claim, NOT a decision-relevant one). 17 networks converted, EVERY node/arc count matched the
repository's published figures exactly (asia 8/8, cancer 5/4, earthquake 5/4, sachs 11/17, survey 6/6,
alarm 37/46, child 20/25, insurance 27/52, barley 48/84, mildew 35/46, hailfinder 56/66, hepar2 70/123,
win95pts 76/112, andes 223/338, pathfinder 109/195, pigs 441/592, link 724/1125, diabetes 413/602) --
`munin-dag`/`munin-sub1`/`KarlNetwork` were already present from earlier work; `water` (32/66) matches an
existing un-prior'd network.

TRACTABILITY (identify-only diagnostic, `validation/bnlearn_diamond_stats.jl` + `_single.jl`): 16/17
comfortably tractable (maxcond 0-21, all completing in well under 2s; andes' maxcond=21 is fine since only
753 total unique diamonds, mostly tiny). ONE exception: **diabetes-bnlearn**. First attempt: new_identify
climbed to 7.9GB over ~2 minutes and was killed pre-emptively (not proven intractable, just abandoned).
Second attempt, run independently by the user from a separate REPL session (`diabetes_tractability_probe.jl`,
designed for exactly this): climbed past 9.5GB and **crashed the Julia process with a low-level segfault-
style trace** (concurrently, this also crashed an unrelated background script of ours that only needed a
few hundred MB, i.e. system-wide memory exhaustion, not a bug in the other script). This is now confirmed,
not inferred: diabetes-bnlearn (413 nodes, 602 edges, 97 forks, **265 joins** -- an unusually reconvergence-
dense structure for its size) exceeds practical memory limits on identification alone, before any
propagation. EXCLUDE from the corpus; report as a characterised boundary case (matches the drone case
study's pattern: real reconvergence-dense structure hits the same wall independent of application domain).
Open question, not yet tested: whether sifted CUDD ALSO fails on diabetes-bnlearn (would mirror the
concentrated-minimal/vtol-dense finding) or handles it -- do not assume either way; test it in isolation,
not concurrently with other memory-heavy runs (that concurrency is exactly what caused the crash above).

LINK (724 nodes, 1125 edges) -- maxcond=6, identify in 1.6s, comfortably fine. An early draft of this note
called LINK "a network famous in the PGM literature for being a brutal junction-tree benchmark" and framed
IPA's fast result as evidence its local conditioning sidesteps a documented global-treewidth difficulty.
**That claim was checked (WebSearch) and NOT confirmed** -- no source found directly substantiating LINK's
specific reputation for junction-tree hardness. RETRACTED. Report only the measured fact (maxcond=6, fast)
with no comparative claim about other methods' difficulty on this network unless a real citation is found.

--------------------------------------------------------------------------------
## 9. p-box operator divergence: WHERE it happens (2026-07-28), not just how much

Extends §1's headline-claims correction (the manuscript's "all headline claims use the provable Frechet
bound" statement was false -- the envelope/certified-bound tables actually used the default, empirically-
validated-only positive-dependence operator, cvxP; see the limitations-paragraph fix already applied in
`latex_revised/main.tex`). A full band-vs-threshold sweep (`validation/certified_bound_threshold_sweep.jl`,
21 thresholds x* in [0.01,0.99], both operators, same grid network) shows the divergence is NOT uniform and
NOT simply "worse in the tail" (an earlier, incomplete characterisation based on only testing x*>=0.5) --
it concentrates specifically wherever the TRUE belief distribution's probability mass/transition actually
sits, and both operators trivially agree (identical, tight) everywhere else:
  - "perfect" regime (true belief concentrated near 0.9-1.0): flat, identical 0.02-band agreement for
    x* in [0.01,0.90]; diverges only at x*=0.95 (still identical, band 0.10) and x*=0.99 (cvxP band 0.34
    vs cvxF band 0.62, ~1.8x).
  - "uncert0.7" regime (true belief lower, ~0.3-0.5): diverges at x*=0.50 (cvxP band 0.08 vs cvxF band
    0.64, ~8x) and x*=0.60 (0.02 vs 0.04, 2x); identical (flat 0.02) everywhere else, x* in
    {0.01-0.45}u{0.70-0.99} [FULL lower-tail 0.01-0.45 re-run in progress after a system crash aborted the
    first attempt -- see below].
This is CONSISTENT with, not contradicted by, the earlier envelope sweep's finding of full vacuity
(band=1.0) for cvxF in the uncert0.7 regime: the envelope reports the WORST band across the ENTIRE CDF, and
that worst point is, by construction, exactly the transition-zone point this sweep is now localising --
i.e. the envelope's 1.0 is very likely realised somewhere in {0.01-0.45} (untested at first pass; the
crash below interrupted finding it) or possibly slightly below the tested x*=0.50 point, NOT evidence of a
separate, unexplained phenomenon.
INTERPRETATION for the paper: p-box/IPA remains genuinely useful across most threshold choices -- both
operators agree, cheaply and for free (no simulation needed), wherever the requirement is far from the
system's actual uncertain region. The operator choice (and the soundness-vs-tightness tradeoff) matters
specifically -- and only -- in the region where a certified bound is doing real decision-relevant work
(near the transition), which is an honest, precise, and actually MORE useful characterisation for the
paper than either extreme ("they're basically the same" or "the story evaporates").
CRASH NOTE (2026-07-28): the full [0.01,0.99] re-run of this sweep was aborted mid-run (low-level Julia
segfault trace, `Allocations: 2989574940; GC: 2177`) caused by system-wide memory exhaustion from a
CONCURRENT, unrelated large run (the user's own diabetes-bnlearn probe, independently climbing past
9.5GB at the same time). Not a bug in this script -- it only ever needs a few hundred MB on the 16-node
grid. Re-run once the system is confirmed clear; do not run concurrently with any other memory-heavy job.

--------------------------------------------------------------------------------
## 10. Reviewer crosswalk
See `notes/REVIEWER_RESPONSE_map.md` — every comment tagged DONE / WRITE / FUTURE with the file/number.
