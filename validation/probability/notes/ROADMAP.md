# IPA rewrite — roadmap (factorization → pbox/Interval → framework integration)

Priority order (user): **(1) independent-diamond factorization** (makes IPA *tie* a well-ordered BDD on
low-treewidth graphs), then **(2) pbox/Interval generalization** (IPA's genuine differentiator), then
**(3) framework integration**, each fully tested and documented, with threading notes.

## Baseline (where we are now — the thing being extended)
- **Producer:** `validation/new_identify.jl` — context-aware recursive conditioning. `conditioning_nodes =
  {f} ∪ (E ∩ relevant(edges))`; single fork per level; identity `= (edgelist, conditioning)`.
- **Propagation:** unchanged framework `update_beliefs_iterative` + `updateDiamondJoin`, PLUS one added
  optimization — the **zero-weight conditioning skip** in `DiamondPropagation.jl` (a conditioning node
  pinned to 0/1 is not enumerated). Float64 only.
- **Validated:** 114/114 exact vs sifted CUDD (worst |Δ| = 1.11e-16); power/grid/KarlNetwork exact.
- **Complexity finding (quantitative, corrected):** both methods are exponential in graph width. Sifted
  ROBDD ≈ 2^pathwidth (ordering-optimal); IPA ≈ 2^(conditioning-nesting) ≥ that, sometimes strictly worse.
  Measured: random DAGs — IPA ops ≈ BDD nodes (comparable); fanin-k — ties after factorization; mesh
  lattice — BDD (2621) ≪ IPA (3.9M): BDD wins. BDD ≥ IPA on every family tested; none favors IPA. Both are
  EXACT and PER-NODE (BDD builds a reach function per node), so per-node exactness is NOT an IPA edge.
  **IPA's sole genuine advantage is native interval / p-box propagation** (ROBDDs need discretization).
- **Threading:** propagation must run single-threaded (`julia -t 1`). The per-state `Threads.@spawn`
  path in `updateDiamondJoin` uses a small task stack that overflows on deep nesting; the main stack is
  fine. Decision pending: cap `@spawn` by nesting depth, or document `-t 1`.

Measurement scripts (reused by every comparison below):
- `validation/perf_compare.jl` (mode=ipa|cudd) → timing + peak RAM, one engine/process.
- `validation/cudd_intractable.jl` → naive vs sifted ROBDD node counts (guarded).
- `validation/measure_ops.jl` → IPA op-count (cache length) + per-graph |Δ| vs CUDD.
- `validation/make_merged.jl` → merges all into `validation/paper_data.csv`.
- `validation/make_structured.jl` → Table-1 rows for named networks.
- `validation/oracles_tiered.jl` → path-enum (exact) + Monte Carlo (±CI) beyond-BDD validation.
- Artifacts: `validation/paper_tables.tex`, `validation/paper_figures.tex`.

---

## STREAM 1 — Independent-diamond factorization  ✅ DONE (IPA ties BDD)

STATUS: implemented + validated. fanin-k op-count 2^k → **2k+1** (ties sifted BDD); full 129-graph corpus
**0 wrong (worst 1.11e-16)**; structured nets exact. Changes:
- `TypesAndCache.jl` + `CorePropagation.jl`: `diamond_structures` / `sub_diamond_structures` are now
  `Dict{Int64, Vector{DiamondsAtNode}}` — one diamond per INDEPENDENT conditioning group per join;
  groups combine by the existing inclusion-exclusion over `all_beliefs`.
- `validation/new_identify.jl`: group-aware builder — partition a join's parents by disjoint
  un-conditioned ancestry (union-find over influence sets), one `group_diamond` per correlated group,
  independent no-fork parents attached as `non_diamond_parents`. Single group ⇒ identical to before
  (corpus unchanged); fanin-k ⇒ k O(1) groups instead of 2^k.
- **Framework bug fixed** (`CorePropagation.jl`, non-diamond branch): `||` → `&&` in the sum-vs-IE guard.
  It was summing INDEPENDENT non-diamond parents instead of inclusion-exclusion; latent until
  factorization emitted multiple non-diamond parents (node-8 case: 0.1517 vs 0.1495). Now consistent
  with the regular-parent branch. (Likely also contributed to the OLD identification's wrongness.)
Reference: `validation/rc_core_factored.jl` (exact on 121 graphs, fanin-k O(k)) defined the target.

### (historical spec kept below)
### Independent-diamond factorization — design

**Idea.** At a join whose conditioning cutset partitions into groups with DISJOINT ancestor-cones
(given the current context), the parents' reach events are independent across groups, so
`belief(join) = prior · (1 − ∏_g (1 − P(group_g reaches)))`, conditioning WITHIN each group only.
Turns fanin-k from 2^k into O(k); in general takes IPA from 2^(cutset) toward 2^(max independent
sub-cutset) — the treewidth-optimal bound. Independence is CONTEXT-SENSITIVE (fixing a shared ancestor
can split a group), so the partition is recomputed given the already-conditioned set.

Steps (each ends with: run the regression gate, all graphs must stay exact):
1. **Spec + reference.** Extend `validation/rc_core.jl` (the proven-correct reference) with the same
   factorization and re-validate 114/114 vs CUDD — establishes the target answers before touching the
   framework path.
2. **Detect partitions.** In `new_identify` (or a post-pass), at each conditioning point compute connected
   components of the parents' in-context ancestor subgraph (union-find). Emit one diamond per component
   instead of one diamond over the union cutset.
3. **Combine in propagation.** The join must combine independent diamond groups by inclusion-exclusion
   (`1 − ∏(1 − P_g)`). Check whether `calculate_diamond_groups_belief` / `DiamondsAtNode` already supports
   MULTIPLE diamonds per join (the name suggests "groups"); if not, extend the per-join assembly to hold a
   vector of independent diamonds. This is the one propagation change and must be done carefully.
4. **Unit tests.** fanin-k (k=2..16): assert op-count drops from 2^k to O(k) AND belief matches
   path-enum/CUDD. Add mixed graphs (independent + shared forks) to test context-sensitive splitting.
5. **Regression.** Re-run `measure_ops.jl` + `new_validate` style gate on the full 129-graph corpus →
   must stay 0-wrong; record the new op-counts (expected: lower on graphs with independent structure).
6. **Threading.** Re-check `-t 1` vs auto after the structure changes (factorization reduces depth).

Comparison run (plugs into existing results):
- Re-run `measure_ops.jl` → new `ipa_ops` column; re-run `adversarial_scaling.jl` → fanin-k now O(k).
- `make_merged.jl` regenerates `paper_data.csv` (same schema) → Fig 2 (IPA cost vs BDD) and the
  adversarial crossover figure update automatically. Add a "IPA+factorization" series alongside "IPA".

---

## STREAM 2 — pbox / Interval generalization  (IPA's real differentiator)

STATUS: **Interval DONE — the paper's core result.** Generalized the zero-weight skip to Interval
(`DiamondPropagation.jl`: `T === Float64 || T === Interval`; pinned = degenerate [0,0]/[1,1]) — essential,
not just an optimization, else context-aware cond enumerates 2^|cond| for Interval. Result: on 112 corpus
graphs (interval half-width 0.3) IPA's interval output EQUALS the exact range [belief(lower),belief(upper)]
(monotone ⇒ corners are exact) to machine precision — **112/112 exact, worst over-width & unsound 2.2e-16**,
even at width 0.9. NAIVE interval propagation (no conditioning) over-widens: median 0.275, max 0.452,
111/112 loose by >0.1. ROBDDs can't do intervals natively. Artifact: `validation/paper_imprecise.tex`
(Table + figure) from `validation/interval_sweep.csv`; test `validation/interval_test.jl`.
REMAINING: pbox (skip doesn't generalize cleanly — one_value(pbox) is not a clean point mass; needs a
pbox is_pinned + a CDF-envelope oracle).

### (historical spec below)

**Idea.** The producer is already type-generic; propagation already handles `T ∈ {Float64, pbox,
Interval}`. The only Float64-specific piece is the zero-weight skip (`belief == 0/1`). Generalize the
"is this conditioning node fixed?" test for pbox/Interval, and validate imprecise propagation (which BDDs
cannot do natively).

Steps:
1. **Skip generalization.** Define `is_fixed(::Interval)` / `is_fixed(::pbox)` (degenerate to a point at
   0 or 1) so the skip fires safely; otherwise keep full enumeration (correct, slower). Guard by type.
2. **Interval oracle.** Validate interval outputs by bounding: for many Float64 samples drawn INSIDE each
   input interval, the scalar IPA/CUDD result must lie within the interval-IPA output bounds (soundness),
   and the bounds should be tight against the sample min/max (no gross over-widening).
3. **pbox oracle.** Similar: sample distributions within each p-box, check the output p-box contains the
   empirical CDF envelope.
4. **Corpus run.** Run interval + pbox propagation over the (small/medium) corpus; report bound width vs
   the exact scalar, and runtime overhead vs Float64. (Note: PBA precompile ~1 min; runs interpreted.)
5. **Tests.** Degenerate intervals [p,p] must equal the Float64 result exactly; monotonicity of bounds.

Comparison run (plugs into existing results):
- New table: "imprecise propagation" — per family, interval bound width, pbox summary, overhead ×.
- New figure: bound width vs graph size; BDDs absent (cannot do it) → this is the differentiator figure.

---

## STREAM 3 — Framework integration  ✅ DONE
- `new_identify` ported into the framework: `DiamondDecomposition/Internal/NewIdentify.jl`, included by
  `DiamondDecompositionModule`, exported (module + top-level `InfoPropFramework`). Single source of truth;
  `validation/new_identify.jl` is now a no-op stub (scripts get `new_identify` from the framework export).
- All three case-study callers switched to the single `new_identify` call
  (`run_ipa_casestudy.jl`, `run_ipa_vs_mc.jl`, `run_path_enum_vs_ipa.jl`); metrics updated for the
  `Vector{DiamondsAtNode}` per-join structure (nesting-depth walker iterates the vector).
- **Retired the buggy path**: `Pipeline_Rewrite.jl` no longer included; `identify_and_group_diamonds` /
  `build_unique_diamond_storage[_depth_first_parallel]` exports removed (now undefined). `Pipeline.jl` /
  `Pipeline_Rewrite.jl` kept on disk for history only.
- **Threading decision**: per-state enumeration now runs SERIALLY (`use_parallel = false` in
  `updateDiamondJoin`). The `Threads.@spawn` path had (1) a data race (concurrent writes to the shared
  diamond_cache Dict under auto threads) and (2) small-task-stack overflow on deep nesting. Factorization
  keeps num_states small so serial is sub-second, correct, and deterministic under ANY `-t` (verified with
  `-t auto`, 8 threads). Re-enabling needs a thread-safe cache + larger task stacks.
- Verified: framework loads without Pipeline_Rewrite; power/grid/KarlNetwork exact; run_ipa_casestudy
  runs end-to-end (metro) through new_identify; full 129-corpus regression via the framework export.

### (historical spec below)
## STREAM 3 (spec) — Framework integration

Move the validated producer + skip (+ factorization) from `validation/` INTO
`InfoPropFrmwrk/src/Algorithms/DiamondDecomposition/` replacing the buggy identification, documented
step-by-step and code-by-code, each step gated by the full test suite.

Steps:
1. **Inventory the seam.** `ipa_structure` (case studies / API) calls `identify_and_group_diamonds` +
   `build_unique_diamond_storage_...`. `new_identify` replaces BOTH (it emits roots + unique_diamonds
   directly). Map every caller.
2. **Port `new_identify`** into a framework module (type-generic already), wire it behind the existing
   API so `run_ipa_casestudy.jl` etc. use it unchanged.
3. **Keep the skip** in `DiamondPropagation.jl` (already there); document it as a permanent optimization.
4. **Retire** `perform_hybrid_diamond_lookup`, `perform_recursive_diamond_completeness`,
   `perform_subsource_analysis`, `Pipeline_Rewrite.jl` — the buggy paths.
5. **Regression at each step:** existing framework tests + the 129-graph gate + power/grid/KarlNetwork,
   all exact; case-study logs reproduce.
6. **Threading decision:** implement the chosen fix (cap `@spawn` depth OR document `-t 1`) and note it.
7. **Update** `PIPELINE_REWRITE_STATUS.md` to "integrated".

---

## Definition of done
- Framework uses `new_identify` (+ factorization + skip); buggy paths removed.
- 129-graph corpus + named networks: 0 wrong (Float64); interval/pbox sound & tight.
- fanin-k: O(k), IPA ties BDD; treewidth-tie documented.
- `paper_data.csv` + tables + figures regenerate from scripts and include IPA, IPA+factorization,
  naive-CUDD, sifted-CUDD, and the imprecise-propagation results.
