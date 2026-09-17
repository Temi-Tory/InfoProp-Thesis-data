# Corpus & optimization campaign — HANDBACK (2026-08-17)

**This document answers `CORPUS_AND_OPTIMIZATION_HANDOFF.md` (2026-08-16).** Every investigation
it posed (A–H, G2) was executed over 2026-08-16/17 under user-approved ground rules: nothing
paper-bound trusted without a fresh same-code artifact; numbers without a this-session artifact
DROPPED, not qualified (user policy); user's scripts/notes never modified without approval (two
approved framework fixes, both exactness-gated). The detailed running record with every result is
**`validation/fresh_20260816/MASTER_FINDINGS.md`** — this handback is the map; that file is the
territory.

## 0. Headline

All 17 headline §5 numbers of the revised manuscript are settled: 12 CONFIRMED fresh (several
digit-for-digit), 3 REFRESHED (fresh values, same or better direction), 2 CORRECTED (dropped or
replaced under the no-unprovable-numbers policy). A 10-row corrections ledger (MASTER_FINDINGS
§Corrections) holds every recommended manuscript/notes edit with its artifact. The paper's
three-tier positioning is now artifact-backed at every tier: Float64 comparable (measured both
ways), Interval faster one-shot (3.9–99.9×, corner-equivalent capability), p-box exclusive
(50/50 soundness, four network types).

## 1. Per-investigation closeout (mapping to the original handoff)

- **A (catalogue + corpus design):** 90 dirs (not 85); `paper_data.csv` = the literal 129-graph
  list (the "no such file" caveat was wrong); munin/water are bnlearn PGM nets mislabeled as
  infrastructure; generator name-collision resolved (families-last include order is load-bearing).
  Coverage matrix built; user decisions: Karl stays (+promoted), bnlearn promoted w/ interval,
  adversarial promoted to paper table, **mlgw-gas-network ADOPTED as real infrastructure**
  (provenance: Univ. Illinois IDEALS 5302, MLGW Shelby County gas network — user-supplied).
- **B (diabetes BDD):** ARTIFACT-GRADE. Sifted CUDD fails by SIFTING TIME concentrated in the
  final joins (node 410/413 alone: 62 min, diagram → 2.76M nodes; memory flat), witnessed with
  heartbeat telemetry (`diabetes_witnessed.log`); IPA fails the same net by MEMORY at
  identification. "Both exact methods fail, different resources, different stages."
- **C (real-infra benchmarks):** candidates table in MASTER_FINDINGS §C (water/EPANET strongest,
  FFORT caveated, telecom/power weak-DAG). mlgw adopted; **Net3 water feasibility check remains
  OPEN** (user decided corpus-tier inclusion pending identify-only check — never run).
- **D (adversarial quantification):** fresh timed sweep + fits (`adversarial_timed.csv`,
  `adversarial_fit_summary.txt`). fanin: ipa_ops=2k+1 EXACT, IPA ~1000× faster wall.
  mesh: crossover IN SECONDS at w=4/5 (op-units overstate: 1486× ops = 55× time at w=8);
  maxcond saturation confirmed (fixed L=8); NEW memory wall between w=8/9 (×37 time for ×1.39
  ops; heap-hint REFUTED — 10.6h WORSE). Square w×w sweep added: both methods exponential, BDD
  smaller exponent (`square_mesh.csv`). Interval columns: EXACT through mesh_7
  (`adversarial_interval.csv`; timing columns of big rows polluted — exactness valid).
- **E (Karl p-box):** stale "timed out" claim DISPROVEN — completes steps=50 in 546s
  (`karl_pbox_test.log`). Karl PROMOTED into p-box evidence per user decision. Correct BOTH
  copies of PBOX_ANALYSIS.md (notes/ AND validation/).
- **F (soundness counts):** "16/16" source located (corpus_cvx.jl, the sweep the 14-count missed)
  AND re-verified fresh; all four sweeps confirmed: 16/16, 20/20, 4/4, 10/10 = 50 configs, zero
  violations, logs persisted (`*_fresh.log`).
- **G (drone p-box boundary):** step-1 diagnostics QUANTIFIED the boundary — total conditioning
  states (Σ2^|C|), not maxcond, drives p-box cost: K=6 1,330 states (~270s) → K=8 7,758 (over
  budget) → K=16 654k (~37h) → vtol 2.75M (~150h) (`identify_diagnostics.log`,
  `vtol_identify_only.log`). Boundary sits between K=6 and K=8. **K=8 silent-exit MECHANISM
  remains OPEN** (boundary explained; the clean-exit oddity not reproduced/diagnosed).
  drone-full identification fails by memory (25.5GB demanded/16GB machine) → §5.4.3's "27–28"
  figure DROPPED per user policy, replaced by the measured memory statement.
- **G2 (BDD K-sweep):** boundary MEASURED — BDD ok through K=12 (123k nodes, 45s), timeout from
  K=14; official K=16 non-completion reproduced under documented 1800s budget; IPA flat ~5s
  across K=8..14 (`g2_ksweep.log`). Specials reproduced: bdd_nodes 2,667/4,968 exact; one-shot
  interval ratios fresh 56×/15× (`g2_special_rows.log`).
- **H (threading/optimization):** identification parallelizable in principle (root-join level,
  publish-after-build memo) but NOT worth it (fails are memory-bound; identify ≤0.5s when
  tractable). LIFO module = viable prior template for propagation threading (pre-solved both
  documented failure modes), orphaned not invalidated; actual path at
  `src/Network-flow-algos/src/Active_Work_Algos/ReachabilityModuleLIFO.jl` (handoff's path was
  stale). Accuracy-preserving optimization ideas from old DiamondProcessingModule catalogued
  (cached set-ops; storage dedup/laziness attacks the real memory ceiling). H2 experiment: parked
  as future work by design.

## 2. Discoveries BEYOND the original scope (the important ones)

1. **Historical steps-scaling measurement bug**: `timing_imprecise.jl` builds p-box inputs once
   and only flips `setSteps` between legs — the paper's "2.7/8.3/110s, quadratic" row never
   measured true 200/800-level propagation. Faithful curve: 1.23/5.98/39.2/275.7s at steps
   25/50/100/200, exponent →≈2.8 (the operator's analytic O(steps³)). steps=800 impractical —
   do not claim. The script needs an inputs-per-leg fix (not applied — user's script).
2. **Interval "memory wall" was a convention artifact**: widening structural certainties
   (prior exactly 0/1) into uncertainties silently changes the problem class (link: 184 certain
   nodes became conditionable → 24GB OOM; corrected convention → 0.574s EXACT).
   **Degeneracy-preserving widening is now the rule** (drone hub [1,1] semantics) and needs a
   methods sentence in the paper. andes is genuinely propagation-intractable in ANY mode
   (maxcond≈21 + 134 real uncertainties); bnlearn propagation coverage = 16/17.
3. **Two exactness-gated framework fixes landed** (user-approved):
   `LEAN_DIAMOND_CACHE` (TypesAndCache.jl + DiamondPropagation.jl; default OFF; join-only cache
   entries ~100× smaller; 11/11 off-vs-on exact gate incl. pbox) and the keyed unit-box clamp
   cache (InputProcessingModule.jl; bitwise-identical gate). Neither changes any default-path
   result.
4. **Resource-symmetry narrative for §5.5**: diabetes (IPA memory / BDD time), mesh w-9 (IPA
   memory wall, heap tuning refuted / BDD fine), fanin (IPA outright), square mesh (both
   exponential). "Every exact method pays; we measured which resource and where."
5. **Cost-model vindication**: every boundary/anomaly this campaign was explained by diamond/
   conditioning statistics measured on the inputs actually run. Procedural rule: any input change
   → identify-only stats probe first. (W-predictor: the no-dedup instance bound is valid but
   loose — realized 1–5% of bound; §4.3 wording should say "sound a-priori upper bound".)

## 3. Where everything lives

- **`validation/fresh_20260816/`** — the campaign home: `MASTER_FINDINGS.md` (full record,
  ledger, corrections), ~20 scripts (all rerunnable, headers document usage/budgets), ~25
  logs/CSVs (every artifact cited above), `old_baseline/` (pre-refresh copies of the five
  `RESS_response/data/` CSVs that the fresh runs overwrote).
- **`RESS_response/data/` refreshed**: `interval_bdd_vs_ipa_timing.csv`,
  `certified_bound_vignette.csv`, `grid_envelope.csv` (fresh values);
  `timing_imprecise.csv` RESTORED to the historical copy (fresh run invalid — see §2.1; the
  faithful replacement curve lives in the campaign folder).
- **Framework changes (2 files + 1 shared-path edit)**: `TypesAndCache.jl`,
  `DiamondPropagation.jl`, `InputProcessingModule.jl` — all three edits documented in-code with
  the gate evidence named.
- **Git**: everything since the user's `safety commit` (97de174, 2026-08-16 10:29) is
  uncommitted, INCLUDING the framework fixes and the whole campaign folder. **Recommended first
  action: a closing commit.**

## 4. Open items (complete list)

1. **Wave-4 writing** (the substantive one): apply the 10-row corrections ledger to `main.tex`
   (in `RESS_response/newress.zip` — `latex_revised/` no longer exists), add the adversarial
   table/figure + corpus×mode coverage table + §5.3/§5.5 replacement passages + methods sentence
   + real-infra justification paragraph; sync REVIEWER_RESPONSES_draft values. User prefers the
   RESS_edit_proposals.md quote→replacement→rationale format.
2. Net3 water feasibility (identify-only, ~30 min, user-approved pending).
3. K=8 silent-exit mechanism (optional, ~30 min).
4. `timing_imprecise.jl` inputs-per-leg fix + PBOX_ANALYSIS.md stale-claim retirement (both
   copies) + CORPUS_INVENTORY/PAPER_GUIDE corrections — all flagged for the user, per rules.
5. Author-side manuscript TODOs from July (unchanged): affiliations, dPrPm bound columns in
   tab:grid_accuracy, references (Williamson–Downs, Ferson 2003, broken jones_drone cite).
6. H2 threading experiment — future work unless explicitly wanted.

## 5. Hard-won operational rules (do not relearn these)

- Fresh-or-it-didn't-happen; numbers without artifacts get dropped, not qualified.
- Identify-only stats probe BEFORE any expensive run on new/changed inputs.
- Degeneracy-preserving widening for all synthetic uncertainty.
- One timing measurement per fresh process; after any in-process timeout, exit the process
  (abandoned tasks poison everything after them).
- Budget every long run (the unbudgeted heap-hint run ate a night proving a negative).
- The 16GB machine is the binding constraint behind every boundary number here — restate budgets
  if hardware changes.
- PBA's "Disagreement between theoretical and observed mean/variance" warnings are benign
  operator noise; filter logs before archiving (one raw log was 121MB of them).
