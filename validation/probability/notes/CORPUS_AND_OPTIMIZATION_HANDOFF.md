# Corpus, benchmarks & optimization investigation — handoff (2026-08-16)

## Purpose and how to use this document

This is a briefing for a **fresh investigation pass**, deliberately written to pose open questions
rather than hand over conclusions. `notes/CORPUS_INVENTORY.md` (written earlier the same day) already
contains one pass at cataloguing the existing corpus, but it was assembled from prior session notes
that turned out to contain at least one **stale, contradicted claim** (p-box "timed out" on grid —
see Investigation E) — so treat everything cited from existing notes/data below as "this is what's on
record," NOT as "this is confirmed current truth." Re-derive/re-verify before relying on any number
here for the paper. Do not anchor on prior conclusions merely because they're already written down.

Nine independent investigation threads follow (A-H, plus G2 sitting alongside G). They don't need to
be done in order, and several (C, D, E, F, G, G2) are naturally parallelizable across sessions/agents
since they touch different code paths and don't share state.

---

## Investigation A — Catalogue the corpus AND the generators; design the final paper corpus

Two related but distinct tasks:

1. **Catalogue what already exists** (start from `notes/CORPUS_INVENTORY.md` but re-verify — see the
   framing note above). That document lists ~185 networks across 7 groups (core 129-graph regression
   set, 6 named topological families, adversarial fanin-k/mesh-w, real infrastructure, bnlearn corpus,
   p-box soundness sweep, drone case study), with size/density/diamond/maxcond ranges and Float64/
   Interval/p-box/BDD coverage per group. It also flags ~60 directories in `dag_ntwrk_files/` that are
   leftover files from earlier project phases with zero references anywhere — confirm that classification
   still holds before excluding them.

2. **Catalogue the generators**, not just their past output — the actual paper corpus may need
   regenerating cleanly rather than reusing old runs. Known generator functions:
   - `validation/graph_gen.jl`: `gen_nested`, `gen_overlap`, `gen_asym`, `gen_multisource`,
     `gen_layered`, `gen_grid`, `gen_random_dag`, `gen_mutate`, `gen_fixed_height`.
   - `validation/graph_families.jl`: `gen_multisource`, `gen_grid`, `gen_layered`, `gen_bridge`,
     `gen_series_parallel`, `gen_complete` — note some names overlap with `graph_gen.jl` but may have
     different signatures/behaviour; check which one each existing script actually imports before
     assuming they're identical.
   - Real-network sources: bnlearn BIF converter (`validation/bif_to_edges.jl`), the drone case study
     generator (`drone_network_to_dag_reliability.jl`, functions `build_fw_reliant_centralized`,
     `build_vtol_dense_decentralized`, `build_concentrated_minimal`), and whatever produced
     power-network/KarlNetwork/metro/munin/water (provenance not re-traced this pass — worth doing).

3. **The actual design goal**: a clean, deliberate, paper-ready corpus definition where Float64,
   Interval, p-box, AND sifted-BDD comparison are run **consistently** across the same set of networks
   — not the current patchwork where different subsets got different treatments opportunistically over
   many sessions (e.g. bnlearn has zero Interval/p-box coverage; the adversarial families have zero
   p-box; the p-box soundness sweep uses different networks than the deep divergence-characterization
   work). Decide what the minimum consistent corpus looks like for the paper's headline tables, and
   what's reasonable to leave as supplementary/best-effort coverage.

---

## Investigation B — bnlearn corpus + diabetes-bnlearn BDD tractability (concrete, ready to run)

Not really open-ended — this is a specific, ready-to-execute action item.

- 17 bnlearn networks converted (asia through link, 8/8 to 724/1125 nodes/edges), Float64 only, no
  Interval/p-box run on any of them (see Investigation A's corpus design — should this change?).
- **diabetes-bnlearn (413 nodes, 602 edges, 97 forks, 265 joins)** is excluded from the IPA corpus:
  confirmed intractable for `new_identify` via two independent crashes (memory exhaustion, not proven
  algorithmic — just exceeds practical RAM before finishing identification).
- **Open question, ready to answer**: does sifted CUDD ALSO fail on diabetes-bnlearn (mirroring the
  drone case study's vtol-dense-decentralized p-box finding — real reconvergence-dense structure
  defeating a different exact method too), or does it handle it fine where IPA can't?
- `validation/diabetes_bdd_probe.jl` exists and was fixed this session (it had a real bug: run as a
  plain `julia file.jl` script rather than `include()`d in an interactive REPL, it would silently exit
  right after spawning the background build task, before the task finished — no error, no result, just
  looked like nothing happened). The fix adds an `isinteractive()` guard so plain-script execution now
  blocks until the build finishes. **Not confirmed run to completion since the fix** — this is a clean,
  bounded task: run it, get a real answer, document it.
- Discipline note carried over from earlier crashes: do not run this concurrently with any other
  memory-heavy job (that concurrency is exactly what caused the original crashes).

---

## Investigation C — Web search: other real-world DAG reliability benchmarks (civil-infrastructure style)

bnlearn is a real, cited, legitimate PGM benchmark repository, but it's general-purpose Bayesian
network structure (medical diagnosis, genetics, etc.), not specifically civil/critical infrastructure —
the RESS paper's own flagship case study (drone medical delivery) IS civil infrastructure, so a second
real-network category in that same spirit would strengthen the "real infrastructure" corpus group
beyond the current power-network/KarlNetwork/metro/munin/water set (whose provenance/citability hasn't
been re-checked recently either — worth doing as part of this same pass).

**Task**: web-search for publicly available DAG-structured (or convertible-to-DAG) reliability/
network-flow benchmark datasets in domains like: power transmission/distribution networks, water
distribution networks, transportation/logistics networks, telecom backbone topologies, supply chain
networks — the kind of thing a RESS reviewer would recognize as "real civil infrastructure," similar in
spirit to how bnlearn networks are recognized as "real PGM benchmarks." Look for:
- Named, citable sources (a paper, a public repository, a standard test-case collection — e.g. the kind
  of thing IEEE test systems are for power engineering, if a DAG-reliability equivalent exists).
- Verify each candidate is genuinely a DAG (or has a legitimate, defensible DAG-ification) before
  adding it — don't force a cyclic network into the corpus.
- Cross-check size/scale against what's already covered (the corpus already has plenty of small-to-
  medium synthetic networks; a benchmark that's either genuinely large-scale or carries strong domain
  legitimacy would add the most value).

This is exploratory — report candidates found with enough detail (citation, size, structure, DAG-ness)
for a follow-up decision on whether to actually convert and add one, rather than converting anything
unilaterally.

---

## Investigation D — Quantify the adversarial fanin-k / mesh-w BDD-win finding more rigorously

Currently reported (from `data/adversarial_factored.csv`) as: mesh-w at w=8 gives bdd_nodes=2621 vs
IPA ops=3,895,252 — BDD wins by orders of magnitude, and this is presented qualitatively as "BDD ≥ IPA
on every family tested." That's honest but under-quantified for a paper table. Worth doing properly:

- **Fit/characterize the actual growth rates**, not just endpoint numbers. mesh-w rows go w=2..8 with
  V, E, ipa_ops, ipa_uniq (unique diamonds), ipa_maxcond, bdd_nodes all recorded — enough data points to
  fit or at least clearly characterize IPA's growth (is it exactly `2^maxcond`-shaped? does unique-
  diamond count matter independently of maxcond?) against BDD's growth (sub-exponential? what's driving
  its much slower growth on this specific family — is it the mesh structure's specific reconvergence
  pattern being unusually favourable for variable ordering?).
- **Find the crossover point precisely** — at what w (or interpolated maxcond) does BDD overtake IPA?
  Currently only 7 integer w values are sampled; is the crossover already visible in the existing data,
  or does it need finer sampling / earlier w values than currently tested?
- **Do the same for fanin-k** for completeness — currently fanin-k shows both methods scaling
  ~linearly (maxcond stays at 1 throughout, by construction — single wide fork, not nested), so the
  interesting comparison there is different in kind, not just degree; make sure the paper's story
  correctly distinguishes "fanin-k: both scale gracefully, roughly comparable" from "mesh-w: BDD clearly
  better, here's the quantified rate" rather than conflating the two adversarial families.
- Consider whether extending mesh-w beyond w=8 (currently the top of the swept range) would make the
  crossover/growth-rate story clearer, weighing that against IPA's cost at higher w (3.9M ops already
  at w=8 — check timing, not just op-count, before deciding whether higher w is worth attempting).

---

## Investigation E — p-box status on grid and KarlNetwork: CORRECT A LIKELY-STALE CLAIM

**This is the one open item where I'm confident the existing note is simply wrong, not just
unverified.** `notes/PBOX_ANALYSIS.md` states "p-box propagation is SLOW (PBA interpreted);
grid/KarlNetwork p-box timed out." But earlier in this same session (see `notes/CORPUS_INVENTORY.md`
§7 and the underlying scripts `validation/certified_bound_threshold_sweep.jl`,
`validation/threshold_sweep_extended.jl`, `validation/certified_bound_threshold_sweep_steps200.jl`),
p-box ran successfully on grid **repeatedly**, at both steps=50 and steps=200, across many scenarios
(perfect/uncert0.7 regimes, both cvxP and cvxF operators, full 21-point threshold sweeps) — taking
seconds, not timing out.

**Most likely explanation**: `PBOX_ANALYSIS.md` reads like an early design-analysis note (opens with
"Goal: extend IPA's exact/tight imprecise reliability from Interval... to p-box" as if p-box didn't
exist yet) and does not mention `new_identify` or context-aware conditioning anywhere — it very likely
predates the diamond-decomposition rewrite (`InfoPropFrmwrk/src/Algorithms/DiamondDecomposition/
Internal/NewIdentify.jl`) that fixed multiple other p-box correctness bugs this project went through
(see `notes/pbox-conditioning-unsound.md`-style history). If so, the "grid p-box times out" claim is
simply obsolete and should be corrected wherever it's repeated, not carried into the paper.

**What needs to happen**:
1. Confirm the timeline (when was `PBOX_ANALYSIS.md` written vs. when was the `new_identify` rewrite
   landed) to establish this isn't a coincidence/different bottleneck.
2. **Re-test KarlNetwork specifically** — grid's fine-ness is now well-established this session, but
   KarlNetwork has NOT been re-attempted with the current implementation. Don't assume it's also fixed;
   test it fresh, with a timeout guard (see Investigation G for the timeout-guard pattern already built
   this session in `validation/drone_pbox_k_sweep.jl` — reuse that approach rather than risking another
   open-ended stall). Becuse Karl network was a generated network by my colegue karl im not so sold on using 
   it as a benchmartk for pbox and decsion making advanbatge i think a real infratsructure network would be better.
   
3. Update `notes/PBOX_ANALYSIS.md` (or retire the stale claim explicitly) once re-verified, so this
   doesn't get miscited again.

---

## Investigation F — Reconcile the p-box soundness sweep count (14 vs 16)

`PAPER_GUIDE.md` cites "16/16" configs validated sound for p-box in a couple of places. Direct
verification this session only turned up 14 configs across two sources:
- `data/pbox_sweep.txt`: 10 networks (bridge3, seriesparallel3, grid3x4, layered4x3, multisrc_n12,
  random_n12_s1/s2/s3, random_n15_s1, cex_n15).
- `validation/validate_framework_pbox.jl`: 4 configs (grid perfect, grid uncert0.7, bridge_5 perfect,
  random_n15 uncert0.7).

**Task**: find the missing 2 (or confirm "16" was simply a miscount/stale figure and correct it to 14,
or to whatever the true re-verified number is). Check for other pbox-soundness-flavoured scripts/logs
not yet found — search broadly (script names containing "pbox", "soundness", "unsound" beyond the ones
already identified; check git history / older commits if the file was since deleted or renamed; check
`notes/pbox_operator_and_soundness.md` and `notes/PBOX_DILEMMA_SUMMARY.md` for any additional sweep
results quoted inline that might not correspond to a saved script/CSV). Don't just split the difference
or assume — find the actual source or correct the citation.

---

## Investigation G — Drone p-box tractability boundary: proper investigation, not blind reruns

Current state (this session, `notes/CORPUS_INVENTORY.md` §7): p-box tractable and twice-confirmed on
the K=6 concentrated-minimal variant (~270s, 36 diamonds, maxcond=6, 919 edges). Two further attempts
both failed, but in different and unexplained ways:
- **vtol-dense-decentralized** (K=16-equivalent redundancy, maxcond=17, 1753 edges): didn't even
  finish a steps=10 warmup within a 1-hour wall-clock budget (killed manually). CPU usage was
  confirmed continuously active throughout (not deadlocked/hung), so it was doing *something* the whole
  time, just not finishing.
- **concentrated-minimal at K=8** (intermediate step in a planned K-sweep): the process exited cleanly
  (exit code 0) partway through, with NO timeout message (hadn't hit the 900s budget), NO error/
  exception printed, and no crash trace in Windows Event Log. It just silently stopped. No system-level
  memory pressure or errors were found around that time either.

**This has NOT been properly root-caused** — it was reported honestly as an open anomaly, not
diagnosed. A real investigation should:
1. **Profile before running**: `new_identify`-only (identification, no propagation) is cheap even on
   large networks — get diamond count, maxcond, and the *distribution* of conditioning-set sizes across
   ALL diamonds (not just the max) for K=6, 8, 10, 12, 16 BEFORE attempting any p-box propagation. The
   working hypothesis (stated in `CORPUS_INVENTORY.md`, NOT verified) is that p-box cost compounds
   across a network's *total* diamond count/conditioning-state count, not just its single widest
   diamond (unlike Float64/Interval, where per-diamond cost is cheap regardless of how many diamonds
   exist) — this is testable directly from identification output alone, cheaply, without ever running
   a full p-box propagation. Do this first; it may fully explain both failures without needing to run
   anything expensive at all.
2. **Isolate the K=8 anomaly specifically** — rerun ONLY K=8 (not a multi-K sweep) with tighter
   instrumentation: log memory every few seconds (not just every 15s), check for Julia-level warnings/
   deprecations that might indicate silent early termination, consider running under conditions that
   would surface a segfault more visibly (e.g. checking `$LASTEXITCODE`/exact process exit semantics on
   Windows, or running via a wrapper that captures core dumps if available).
3. **Only after 1-2 are done**, if warranted, attempt a properly time-boxed K-sweep with per-diamond
   cost prediction guiding which K values are even worth attempting, rather than the blind
   escalating-K approach used this session (`validation/drone_pbox_k_sweep.jl` — reusable as a
   starting point, but extend the diagnostic-first logic above onto it rather than just re-running it
   as-is).
4. Report a real, root-caused boundary (or a clearly-characterized "still don't know why, here's what
   we ruled out" if root-causing genuinely isn't feasible) — not just "K=6 works, K=8+ doesn't, cause
   unknown," which is where this session left off.

---

## Investigation G2 — Where does sifted BDD actually fail on the drone K-generator family? (Float64/Interval mode, NOT p-box — distinct from G)

The existing BDD comparison on the drone corpus only checked two fixed points: K=6 (controlled test,
confirming BDD ALSO succeeds there, correcting an earlier "IPA has a lever BDD lacks" overclaim) and
K=16 (the official shipped network, drone_bdd_comparison.jl). **Nowhere has BDD actually been swept
across intermediate K values to find where it starts failing.** Meanwhile `validation/drone_k_sweep.jl`
already sweeps IPA (Float64/Interval, NOT p-box — don't conflate with Investigation G) across
K=12,16,20,24 for both `concentrated-minimal` and `vtol-dense-decentralized`, and IPA stays comfortably
tractable (maxcond plateaus at 17, propagate times 6-28s) across that entire range with no failures
recorded.

**The open question**: does sifted-BDD's own tractability actually break down somewhere in that same
K range, or does it also stay comfortably tractable throughout the whole thing (in which case IPA has
no interval/point-mode tractability advantage over BDD on this network family, only the already-
established p-box-native-propagation advantage)? There's an unverified recollection that IPA might
remain tractable up to around K=15 in some sense — confirm or correct this precisely rather than relying
on memory.

**What needs to happen**:
1. Build a genuine sifted-BDD K-sweep, analogous in structure to `validation/drone_k_sweep.jl` but
   measuring sifted-CUDD build time/node count instead of (or alongside) IPA — reuse
   `validation/drone_bdd_comparison.jl`'s CUDD-build machinery (`cudd_build_sifted`) as the building
   block, and `validation/gen_k6_test.jl`'s pattern for generating a network at an arbitrary K in-memory
   (no disk I/O needed per K, matching `drone_k_sweep.jl`'s own approach).
2. Sweep a fine-enough range of K (e.g. every integer or every 2, not just 6/12/16/20/24) on at least
   `concentrated-minimal` (the family both existing sweeps already use) to actually locate the point
   where BDD's node count explodes or build time blows past a reasonable budget, using the SAME kind of
   hard per-K timeout guard already built this session (`validation/drone_pbox_k_sweep.jl`'s
   `Threads.@spawn` + polling pattern) so a bad K can't stall indefinitely.
3. Report the precise crossover, if one exists: "BDD tractable up to K=X, fails at K=Y; IPA (Float64/
   Interval) tractable throughout K=6..24 on the same family" — with real numbers, not a qualitative
   claim. If BDD turns out to ALSO stay tractable throughout, that's an equally important (if less
   flattering) honest finding — report it either way rather than only if it favours IPA.
4. This is a genuinely different result from Investigation G: G is about p-box's OWN tractability wall
   (compared against nothing — p-box just fails on its own terms past some K), while this is a
   head-to-head IPA-vs-BDD comparison in the mode (Interval/Float64) where both methods are otherwise
   exact and comparable. Keep the two findings clearly separated in whatever they get written up as —
   don't let "IPA beats BDD at high K" (if true) and "p-box fails at high K" (already true) get
   conflated into a single muddled claim.

---

## Investigation H — Threading/optimization for the diamond IDENTIFICATION module (not propagation)

Current, confirmed constraint (from `notes/ROADMAP.md`): **propagation** (`update_beliefs_iterative` /
`updateDiamondJoin`) must run single-threaded (`julia -t 1`). The per-state `Threads.@spawn` path there
uses a small task stack that overflows on deep diamond nesting. This is a known, understood limitation
on the propagation side specifically.

**Open question** (not investigated, this session or apparently ever, based on
`InfoPropFrmwrk/src/Algorithms/DiamondDecomposition/Internal/NewIdentify.jl` containing zero `Threads`
usage): does the same constraint apply to **diamond identification/decomposition** (`new_identify`
itself — the `_subgraph_structure`, `components`, `shared_fork`, `group_diamond`, `build` functions),
or is that phase structurally different enough to parallelize safely?

Reasoning to test, not assume: identification is a graph-decomposition/discovery pass (finding which
subsets of nodes form diamonds and their conditioning sets), which is conceptually a different
recursion pattern from propagation (which recursively evaluates probability mass through nested
diamonds, where a stack frame's numeric result depends on its children's results in a way that seems to
be where the current stack-depth problem specifically bites). It's plausible independent diamonds/forks
could be identified concurrently (e.g. `components`/`shared_fork` calls for structurally disjoint parts
of the graph have no data dependency on each other), which propagation fundamentally can't do the same
way since diamond N's belief computation needs diamond N-1's resolved sub-belief. But this is a
hypothesis to verify by actually reading `NewIdentify.jl`'s recursion structure carefully and
reasoning about (or empirically testing) where true data dependencies exist, not something to assume
true just because it sounds plausible.

**Separately, worth reviewing**: `src/Network-flow-algos/src/Active_Work_Algos/ReachabilityModuleLIFO.jl`
— an older, apparently-abandoned "LIFO work-stealing" variant, whose own docstring says it exists
specifically to "eliminate recursive task spawning overhead" by pushing work items to a LIFO queue
worked by `Threads.nthreads()` workers instead of recursively spawning a task per state. This reads
like it may have been a **direct prior attempt to solve exactly the stack-overflow problem that later
forced propagation back to single-threaded** — worth understanding (a) what it actually did, (b) why it
isn't in use today (never finished? found to be unsound? just superseded by unrelated refactoring and
never revisited?), and (c) whether its core idea (explicit work-stealing queue instead of naive
recursive spawning) is applicable to either propagation (retrying the same problem with a different
threading strategy) or identification (the open question above) or both. This is old code in a
different part of the repo (`src/Network-flow-algos/`, not `InfoPropFrmwrk/`) — confirm it's even
compatible with/relevant to the current framework before investing much time, since the codebase has
clearly moved on structurally since it was written.

---

## What NOT to do

- Don't treat any number in `notes/CORPUS_INVENTORY.md`, `PAPER_GUIDE.md`, or any other prior-session
  note as ground truth without re-deriving it — Investigation E is the concrete proof this matters.
- Don't run multiple memory-heavy investigations concurrently (this crashed real work at least twice
  already this project — see the diabetes-bnlearn crash history).
- Don't force a web-search-discovered "real infrastructure" candidate (Investigation C) into the corpus
  without confirming genuine DAG structure and a defensible citation.
- Don't extend the K-sweep (Investigation G) blindly upward again without the diagnostic-first approach
  — that's exactly what produced two unexplained failures this session.
