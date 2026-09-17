# MASTER FINDINGS — corpus & optimization campaign (fresh-first), started 2026-08-16

Claude's findings document per the approved plan (`~/.claude/plans/declarative-spinning-chipmunk.md`).
Rules: every paper-bound number re-derived fresh on current code with a persisted artifact in this
directory; the user's established notes are NEVER edited from here — §Corrections collects
recommended edits for the user to apply/approve. Safety anchor: commit `97de174` ("safety commit",
2026-08-16 10:29, branch `ui`).

Verdict tags used throughout: **CONFIRMED** (fresh run agrees with prior note/artifact),
**CORRECTED** (fresh run contradicts it — old value quoted alongside), **NEW** (no prior claim).

## 0. Paper-data watchlist (Investigation P) — done 2026-08-16

Sources read: verbatim reviewer comments (extracted from `Reviewer_Comments_Response_Tracker.docx` →
scratchpad `docx/tracker.txt`), revised manuscript `newress.zip::main.tex` (§5 complete, lines
933–1424; NOTE: the `latex_revised/` dir in older notes no longer exists — the manuscript lives in
`RESS_response/newress.zip`, built 2026-07-28), drafted responses `notes/REVIEWER_RESPONSES_draft.md`.

### 0.1 What the reviewers actually asked (data-relevant distillation)

- **R1.1 + R2.2 — corpus breadth & same-network exact comparison** (the round-1 core criticism):
  varying sizes/topologies, exact-method comparison on the SAME grid + drone networks. The revision's
  answer is the 129-graph corpus + structured/real networks + drone §5.4.3. → A1.5 must guarantee
  the corpus story holds up fresh; any network dropped/added changes tab:structured/tab:corpus.
- **R1.2 — timing rigor**: all timing claims now rest on controlled same-environment comparisons,
  measured warm (discarded warm-up, minimum of repeats, idle hardware — §5 preamble, lines 939–942).
  **Every fresh timing run in this campaign MUST follow that protocol or it cannot back the paper.**
- **R1.4 + R3.5 + R1.6 + R2.4 — quantitative complexity & practical range**: per-instance cost
  W = Σ_d 2^{|C_d|}·O(|E_d|) (§4.3), width-tracks-treewidth claim + width_correlation figure,
  explicit practical boundary (drone: cond 27–28 unrestricted vs 15–17 at K=16; ~18 ceiling).
  → D's growth fits + G1's conditioning-set distributions + G2's BDD boundary all feed here.
- **R1.5 — reliability insights, not runtimes, on drone**: worst-facility bounds, map figure,
  redundancy-vs-verifiability trade-off. → drone belief re-verification + G/G2.
- **R3.6 — drone transparency**: per-design structure stats tabulated. → A1 stats should cover the
  drone configs (in/out-degree stats are promised in the response but NOT in the current tab:drone!).
- **R3.8 — broader applicability (Bayesian networks)**: currently answered by TEXT only (§1.1/§4.3
  positioning). bnlearn corpus + diabetes probe = unused evidence that could back it empirically.

### 0.2 Headline §5 numbers the campaign must back fresh (the checklist)

| # | Paper claim (§, line) | Current source artifact | Fresh re-check via |
|---|----------------------|------------------------|--------------------|
| 1 | Grid beliefs table (node16=0.98538853…) + BDD 1.1e-16 (§5.1) | grid case study scripts | Wave-2 regression |
| 2 | Grid IPA runtime 2.378 ms / 4.94 MB (§5.1) | bench_grid | Wave-2 timed re-run |
| 3 | 129-graph corpus, worst Δ 1.1e-16, both regimes (§5.2) | consolidated corpus sweep | Wave-2 regression (NOTE: older memory says "114/114" — count must be pinned fresh) |
| 4 | tab:structured — power 23/27 Δ8.3e-17; grid 41 uniq; Karl 26/74/147/max|C|11/ROBDD1921; cex-n15 (§5.2) | paper_tables.tex ← make_structured.jl? (A1 to confirm) | Wave-2 regression |
| 5 | Sub-problem-vs-node counts: 42 vs 340 (cex), 142 vs 759 (complete-8), 1961 vs 1043 (layered) (§5.2) | corpus sweep | Wave-2 |
| 6 | Interval corner-exactness ~1e-16 corpus-wide; naive over-widens up to 0.45 (§5.3) | interval sweep | Wave-2 |
| 7 | tab:interval_timing — 8 families, ratios 2.9–95.1, exact ms values (§5.3) | interval_bdd_vs_ipa_timing.jl | Wave-2 timed re-run (warm protocol) |
| 8 | p-box soundness "dozens of configs" vs MC, 0 violations (§5.3) | corpus_cvx (16) + cvx_sound (20) + grid_envelope (18) | **F** |
| 9 | Tightness band ~0.18 → ~0.70 + envelope figure (§5.3) | grid_envelope.csv / envelope scripts | **F/Wave-2** |
| 10 | p-box cost 2.7/8.3/110 s at steps 50/200/800; interval ×1.2 (0.67 vs 0.79 ms) on cex-n15 (§5.3) | timing_imprecise.csv | Wave-2 timed re-run |
| 11 | tab:certified — bands [0,0.02]/[0,0.10]/[0,0.12]/[0.98,1]; MC 267–9,604 (§5.3) | certified_bound_vignette.jl | Wave-2 |
| 12 | Drone configs 217/263, 242/1753, 230/1648; cond 10/17/16 (§5.4) | drone build + belief CSVs | Wave-2/G2 |
| 13 | Cond 27–28 unrestricted vs 15–17 at K=16; saturation beyond K=16 (§5.4.3) | drone_k_sweep.jl | **G1** (identification-only, fresh) |
| 14 | Drone timings: dense <25 s; sparse ≪1 s; 14× (0.012 vs 0.173 s, 2667 nodes); 6× at K=6 (0.128 vs 0.830 s, 4968 nodes); BDD non-completion at K=16 under 2 orderings (§5.4.3) | drone_bdd_comparison.jl | **G2** (K-sweep supersedes point checks) |
| 15 | tab:drone bands (0.089/0.100, 0.094/0.161, 0.093/0.161); Islay Hospital [0.562,0.722] (§5.4.4) | drone belief CSVs | Wave-2 |
| 16 | Fan-in 2^k → 2k factorisation claim (§4.2/§4.3/conclusions) | adversarial_factored.csv (fanin rows: ops=2k+1 exactly) | **D** |
| 17 | "No family favours IPA for exact point values" + width-tracks-treewidth (§5.2/§5.5) | adversarial_factored.csv + width_correlation | **D** (mesh growth fits) |

### 0.2b Fresh-status per watchlist row (Wave-4 ledger, updated 2026-08-16 21:05)

| # | Claim | Status |
|---|---|---|
| 1 | Grid beliefs + BDD 1.1e-16 | **CONFIRMED** (paper-scenario inputs: table matches to printed precision; BDD Δ exactly 1.110e-16; bdd_nodes 290). NOTE: on-disk grid float/ jsons encode a DIFFERENT scenario — first check mismatched until inputs constructed explicitly |
| 2 | Grid 2.378 ms / 4.94 MB | **REFRESHED**: 0.928 ms / 1.72 MB allocated on current machine — update or annotate as machine-specific |
| 3 | 129-corpus ≤1.1e-16 both regimes | **CONFIRMED CLOSED** — full_regression_sifted fresh: 129/129, Float64 worst 1.11e-16 wrong=0, Interval 2.78e-16/2.22e-16 wrong=0 |
| 4 | tab:structured rows | **CONFIRMED** (power 8.3e-17, grid 1.1e-16, Karl 5.6e-17 all exact; maxcond/rootD/ROBDD counts match) with cosmetic drift: uniq-diamond counts 41→39 (grid), 147→145 (Karl), cex Δ 5.6e-17→8.3e-17 — refresh table values (→ Corrections) |
| 5 | Sub-problem-vs-node counts | Effectively covered by fresh corpus + structured runs; specific 42/340, 142/759, 1961/1043 exemplars can be read from fresh logs at drafting time |
| 6 | Interval corner-exactness + naive 0.45 | **CONFIRMED** (129/129 exact; naive 0.4522) |
| 7 | tab:interval_timing 2.9–95× | **CONFIRMED**, fresh 3.9–99.9× — update table values |
| 8 | p-box soundness "dozens" | **CONFIRMED 50/50** (16+20+4+10) |
| 9 | Envelope 0.18→0.70 | **CONFIRMED 18/18 sound**, bands 0.180→0.70 |
| 10 | p-box cost 2.7/8.3/110 s + "quadratic" | **CORRECTED with fresh curve**: historical row mismeasured (fixed-inputs bug); faithful curve 1.23/5.98/39.2/275.7 s at steps 25/50/100/200, exponent →≈2.8 (analytic O(steps³)); steps=800 impractical (~4h extrapolated) — do not claim. ×1.2 interval-over-float leg unaffected | probe + curve logs |
| 11 | tab:certified bands + MC 267–9,604 | **CONFIRMED digit-for-digit** |
| 12 | Drone configs V/E/cond | **CONFIRMED** via G1 (+ degree stats new); belief-CSV re-derivation pending |
| 13 | Cond 27–28 unrestricted | **DROPPED per user policy** — replaced by fresh memory-exhaustion statement |
| 14 | Drone timings 14×/6×/<25s/BDD-fail | **CONFIRMED + REFRESHED + UPGRADED**: bdd_nodes exact (2,667 / 4,968), agreement 0.0 / 1.11e-16; interval ratios fresh 56× / 15× (update values); official-K16 non-completion REPRODUCED under documented 1800s budget; NEW measured boundary — BDD ok K≤12 (123k nodes, 45s), timeout from K=14; IPA flat ~5s throughout K=8..14 | `g2_ksweep.log`, `g2_special_rows.log` |
| 15 | tab:drone bands + Islay [0.562,0.722] | **CONFIRMED** — beliefs reproduce historical CSVs to ≤4.4e-11; worst facility node 195 [0.562,0.722] exact; fw worst [0.750,0.850]; mean-band microdiffs definitional (node-set), flag at drafting | `drone_beliefs_check.log` |
| 16 | Fanin 2k+1 | **CONFIRMED exactly**, all k |
| 17 | "No family favours IPA" + width-correlation | **REFRAMED by fresh data**: state crossover in seconds (IPA faster ≤w=4), saturation caveat, resource-symmetry narrative |

### 0.3 Evidence currently WITHOUT a home in the manuscript (A1.5 decisions)

- **bnlearn (17 networks) + diabetes-bnlearn probe (B)**: zero mentions in main.tex. Candidate
  empirical backing for R3.8; needs Interval coverage decision at minimum if promoted.
- **Adversarial fanin/mesh sweep**: not tabulated in main.tex (supports §4.3/§5.5 only
  qualitatively). Candidate table/figure for the complexity story (R1.4/R3.5) once D's fresh
  fits exist.
- **KarlNetwork**: IS in tab:structured. User leans toward replacing it (colleague-generated, weak
  provenance) with a real-infrastructure network from C → would change tab:structured + §5.2 text.
- Author-note TODO in tab:grid_accuracy: dPrPm bound columns still to be carried over (user task).

## B. Diabetes-bnlearn sifted-BDD probe (Wave 0) — DONE 2026-08-16 (terminated, finding recorded)

**RESULT (NEW): sifted CUDD did NOT complete on diabetes-bnlearn within a practical budget —
so BOTH exact methods fail on this network, by different resources.** IPA's `new_identify` fails
by MEMORY (9.5GB exhaustion before identification completes; two independent prior crashes);
the sifted-BDD build fails by TIME (CPU-bound sifting, modest memory). This mirrors the drone
vtol/K=16 finding (real reconvergence-dense structure defeating an independent exact method too)
and is the honest boundary statement for the R3.8/bnlearn mention.

Evidence (`julia -t 2 validation/diabetes_bdd_probe.jl`, PID 39284, launched 10:17:20, terminated
11:48:20 with user approval):
- Wall 1h 31m; CPU 5,348s ≈ **89 CPU-min** at ~98% of one core throughout (continuously computing,
  not hung). Calibration: the drone K=16 sifted build was declared non-converging at >30 CPU-min —
  diabetes got ~3× that.
- Memory: settled 0.46GB, **peak 3.06GB** — nowhere near IPA's 9.5GB exhaustion. Not memory-bound.
- Network: 413 nodes / 602 edges → 1,015 BDD variables; 97 forks / 265 joins.
- Caveats to state wherever cited: single ordering strategy (dynamic sifting), single run, no
  node-count-at-kill (stdout was buffered and lost at termination — the script only flushes on
  completion; power-network warmup historically builds in <1s, so ≥85 of the 89 CPU-min were in
  the diabetes build with near-certainty). Wording should mirror §5.4.3: "did not complete within
  a practical computational budget", no stronger.
- **Evidence grade + upgrade path** (user challenge, 2026-08-16): the current record is OS-level
  process accounting sampled during the run (lab-notebook grade — real but not reproducible from
  an artifact, and phase attribution is inferential). An artifact-grade rerun is prepared:
  `diabetes_bdd_probe_instrumented.jl` — in-loop 30s heartbeat (elapsed, live `Cudd_ReadNodeCount`,
  node i/N progress, memory, all flushed) + explicit 45-min wall budget with a final flushed status
  line, so the log itself is the citable "did not complete within budget" witness. Scheduled for
  the Wave-3 slot (needs an uncontended machine for the budget claim to be fair). Until it runs,
  cite the finding as provisional.

**WITNESSED RERUN COMPLETE (2026-08-17, `diabetes_witnessed.log`) — finding upgraded from
provisional to ARTIFACT-GRADE, and sharpened:** the construction reached node 409/413 in ~14 min,
then node 410 ALONE ran 62 minutes (heartbeat gap 860s→4,582s) while the diagram exploded 1.2M →
2,763,625 nodes with dynamic sifting unable to compress; the 45-min budget line then fired
(overshoot documented: the budget is checked between nodes and node 410 was a single
uninterruptible stretch). Memory flat (gc 0.07GB, sys_free 2.2GB) — **time-bound in reordering,
not memory-bound**, localized to the final reconvergence-dense joins. Cite as: "sifted-BDD
construction did not complete within a practical budget (2.76M+ nodes at 76 min, growth
concentrated in the last nodes), while IPA's identification exhausts memory — the two exact
methods fail on this network by different resources at different stages."

Environment note: an unrelated Julia process from 2026-08-10 (PID 16420, ~0.7GB) is still alive
on the machine — flagged to user.

## C. Real-infrastructure DAG benchmark candidates (Wave 1) — done 2026-08-16

Goal: a second real-infrastructure corpus group (beyond the drone study) that a RESS reviewer
recognizes, with a *defensible* DAG reading — feeding both R1.1 (corpus breadth) and the possible
replacement of KarlNetwork's slot. **No conversion done — user decision at A1.5.**

| Candidate | What it is | Size range | DAG-ness | Verdict |
|---|---|---|---|---|
| **Water distribution benchmarks** — ASCE WDSRD (40+ real systems), Exeter CWS benchmarks, classics: Hanoi (32n/34p), Net3 (~97n), C-Town (~400n), L-Town (782 junctions) | Real civil water networks, EPANET .inp format, heavily cited in RESS-adjacent literature | small → genuinely large | Looped as drawn, but a **natural source→demand direction exists** (reservoir/tank supply logic — the same hub-outward defense §5.4.1 already makes for the drone network, which reviewers' R2.3 concern was answered with) | **STRONGEST**. Reservoir-to-node reachability under pipe failure is a real, studied WDN reliability question. Moderate conversion effort (.inp parse + orientation rule). |
| **FFORT fault-tree forest** (Twente, Ruijters et al. ESREL 2019; dftbenchmarks.utwente.nl) | 202 REAL industrial fault trees w/ failure rates + reference results, Galileo format | wide | Genuinely DAGs — but semantics are AND/OR structure functions, **not** source-to-node reachability; only a subset (OR-dominant in the success domain) could map to IPA's problem class | Strong domain legitimacy, weak problem-class match. Only worth it after a feasibility check on the mapping; do NOT force (handoff's own warning). |
| **Telecom backbones** — Topology Zoo (140+ operator-provided maps; original site dead since 2024, preserved in TopoHub), SNDlib (26 topologies) | Real backbone topologies, citable | 10s–100s nodes | Undirected mesh; NO natural flow direction → DAG-ification would be arbitrary (exactly what R2.3 pushed on) | Weak DAG defense. Precedent for *directed* comm reliability exists (Tanguy 2008, arXiv:0807.0629) but with no reusable instance set. |
| **Power test systems** — IEEE RTS-79/96, RBTS | THE canonical power reliability benchmarks | 24–73 buses | Meshed/cyclic; generation→load orientation possible but contestable | Medium. Note corpus already has a "power-network" (23/27) of unverified provenance — A1 must trace it before adding more power data. |

Recommendation (for A1.5): adopt ONE water network at moderate size (e.g. Net3 or C-Town; Hanoi too
small to add coverage) as the real-infrastructure p-box/decision-vignette candidate replacing
KarlNetwork's narrative role, IF the coverage matrix shows the gap matters. FFORT only after a
mapping feasibility check. Skip telecom/power for this revision.

Sources: [FFORT (UTwente)](https://research.utwente.nl/en/publications/ffort-a-benchmark-suite-for-fault-tree-analysis/),
[DFT Benchmarks site](https://dftbenchmarks.utwente.nl/), [FFORT paper PDF](https://doina.net/pubs/ESREL19-Ruijters.pdf),
[Exeter CWS benchmarks](https://www.exeter.ac.uk/research/centres/cws/resources/benchmarks/),
[WDSRD via ResearchGate summary](https://www.researchgate.net/publication/376218356_Reliability_Analysis_of_Benchmark_Water_Distribution_System),
[TopoHub](https://github.com/piotrjurkiewicz/topohub), [SNDlib](https://www.researchgate.net/publication/227628108_SNDlib_10-Survivable_Network_Design_Library),
[Tanguy 2008 directed-network reliability](https://arxiv.org/abs/0807.0629),
[directed two-terminal FPRAS 2026](https://arxiv.org/abs/2608.02523).

## A1. Corpus catalogue verification + per-network stats (Wave 1) — done 2026-08-16

**Census — CORRECTED**: `dag_ntwrk_files/` holds **90** directories, not the inventory's 85. The
~60-orphan classification broadly holds (Scotland-phase dirs, pareto-point-1..6,
scaled-power-network-*, misc), with two NON-orphan surprises:
- `drone-network-full` — **NEW on disk (289 nodes / 6,166 edges)**, added this phase; almost
  certainly the §5.4.3 "unrestricted connectivity → conditioning 27–28" network. That paper claim
  is currently backed by no persisted artifact → fresh identify-only check added to G1 (cheap).
- `mlgw-gas-network` (39 edges) — unreferenced anywhere, origin unknown. If it's a real gas
  network with traceable provenance it's interesting; otherwise orphan. **Asked user.**

**The "129" figure — CONFIRMED and file-backed**: `data/paper_data.csv` = exactly 129 data rows,
one per graph, with V/E/density/nroots/nuniq/maxcond/timings/worst_delta/naive+sift BDD columns.
(24×{n10,n12,n15,n20,n25} random + 8 mutant-n28 + 1 counterexample = 129 — matches tab:corpus.)
CORRECTS the inventory's two claims that the row count was 131 and that "no single file lists all
129". Assembled by `validation/make_merged.jl` (merge semantics to confirm when re-run).
**Count mismatch to pin fresh**: `interval_sweep.csv` has 113 data rows, but the inventory claims
"Interval 129/129 exact" — either 16 graphs lack interval rows or the sweep set differs. Wave 2.

**CSV duplication**: the 5 CSVs duplicated between `validation/` and `RESS_response/data/` are
byte-identical today (no drift). Authoritative set = `RESS_response/data/` (21 files).

**Generator collision — CONFIRMED, with a resolution rule**: `gen_multisource`, `gen_grid`,
`gen_layered` are defined in BOTH `graph_gen.jl` and `graph_families.jl`. 13 scripts include both
files, and every one checked includes `graph_families.jl` LAST → the families versions win in all
dual-include scripts. Any regeneration must preserve this include order or graphs silently change.

**Provenance — the "real infrastructure" group is on shaky ground**:
- `water`/`water-highvdemo` (67 lines each) and `munin-dag`/`munin-sub1` are **bnlearn Bayesian
  networks** (water, munin), NOT civil infrastructure — converted via an older pipeline before the
  `-bnlearn` naming convention. §5.2's text phrase "several real infrastructure networks" is at
  risk; tab:structured itself only cites power/grid/Karl/cex, so the tables are safe.
- `power-network` (23/27) and `metro_directed_dag_for_ipm` (351 lines): plain source,destination
  CSVs, no README, no origin note anywhere in repo notes/scripts. Untraced.
- `KarlNetwork`: colleague-generated (Sep 2025), user already flags weak benchmark legitimacy.
- Net: the corpus has exactly ONE cited real-infrastructure family — the drone study.

**Drone per-design degree stats (R3.6's ask, computed fresh from .EDGES):**

| design | nodes | edges | mean out | max out | mean in | max in |
|---|---|---|---|---|---|---|
| fw-reliant-centralized | 217 | 263 | 1.21 | 27 | 1.21 | **10** |
| vtol-dense-decentralized | 242 | 1753 | 7.24 | 104 | 7.24 | **17** |
| concentrated-minimal | 230 | 1648 | 7.17 | 104 | 7.17 | **16** |

Max in-degree equals tab:drone's |C|max per design (10/17/16) — the conditioning requirement is
exactly the widest join. Candidate one-line addition to §5.4 (answers R3.6's degree-stats ask).

## A1.5 Coverage adequacy matrix → user checkpoint (Wave 1 gate) — matrix done, checkpoint OPEN

Recorded coverage (pre-fresh; ✓ = artifact exists, — = never run):

| Group | #nets | Float64 | Interval | p-box | BDD compare | Timing |
|---|---|---|---|---|---|---|
| random+mutant corpus | 129 | ✓ ≤1.1e-16 | 113-row artifact (mismatch, see A1) | — | ✓ naive+sift | ✓ cols in paper_data |
| named families | 8–12 | ✓ 24/24 | ✓ | partial (grid deep; bridge_5, random_n15) | ✓ | ✓ 2.9–95× |
| adversarial fanin/mesh | 15 | ✓ | — | — | ✓ | **none (D adds)** |
| power / grid / Karl | 3 | ✓ | ✓ | Karl stale-claim (E retests); grid deep | ✓ | partial |
| metro / munin / water | 4 | ✓ | ✓ | — | **unconfirmed** | — |
| bnlearn | 17 | ✓ | — | — | diabetes probe in flight | identify-times only |
| drone official | 3 (+full) | ✓ | ✓ | fw ✓, cm-K6 ✓; cm-K16 ✗, vtol ✗ | K6/K16 points (G2 sweeps) | ✓ |

**Verdict vs the reviewer watchlist (§0):** for the EXACT-computation claims (R1.1/R2.2) coverage
is genuinely broad — sizes 5→724 nodes, densities 0.14–0.42, maxcond 1→21, synthetic + real, and
same-network BDD comparison on grid AND drone as R2.2 demanded. The real gaps are narrative, not
volume: (1) the "real infrastructure" label mostly doesn't survive provenance checks; (2) the
p-box/decision-support story rests on the 16-node grid plus a benchmark the user distrusts
(Karl); (3) bnlearn — the corpus's best breadth asset for R3.8 — is invisible in the manuscript;
(4) the complexity narrative (R1.4/R3.5) has no timing data behind the adversarial families.

**CHECKPOINT DECISIONS (user, 2026-08-16):**
1. **KarlNetwork**: keep in tab:structured; PROMOTE into the p-box evidence if E's re-test
   completes in budget.
2. **bnlearn**: add an Interval sweep across the 16 tractable networks + a brief manuscript
   mention backing R3.8; the diabetes exclusion (and B's probe outcome) stated as an honest
   boundary.
3. **Adversarial**: promote D's fresh timed data to a paper table/figure (R1.4/R3.5).
4. **Real infrastructure**: middle path (user-directed) — no new headline case study; corpus-tier
   additions with an explicit justification passage where real-infrastructure + BN benchmarks are
   discussed:
   - **mlgw-gas-network ADOPTED**: user supplied provenance — "Matrix-based System Reliability
     Analysis of Urban Infrastructure Networks: A Case Study of MLGW Natural Gas Network"
     (Univ. of Illinois IDEALS, https://www.ideals.illinois.edu/items/5302; Mid-America Earthquake
     Center / MAEviz context) — a REAL urban gas network from a citable system-reliability study,
     already converted on disk (39 edges). Needs: orientation-justification note (pressure-driven
     source→demand, same class as drone/water), stats + fresh Float64/Interval/BDD runs like other
     structured networks.
   - **EPANET water (Net3)**: include at corpus tier only, identify-only feasibility check first;
     carries the safe-side lower-bound orientation caveat explicitly.
   - Phrasing correction stands: munin/water relabeled as PGM benchmarks (see §Corrections).

**COVERAGE-ASYMMETRY ANALYSIS (user concern, 2026-08-16): will reviewers question the mode
coverage gaps (Float ⊃ Interval ⊃ p-box)?** Verdict and closures:
- **Interval**: the paper claims interval verified "across the full corpus of §5.2" but the
  artifact (interval_sweep) has 113 rows vs 129 graphs — a discoverable claim/artifact mismatch.
  CLOSURE: corpus-regression re-run to cover interval on ALL 129 + structured. bnlearn closure
  already queued (user-approved sweep). Adversarial closure added: interval columns on
  fanin/mesh (~2× Float cost per D's fresh timings — cheap). After these, Interval coverage ==
  Float coverage everywhere, eliminating the "works on Float so why not show Interval" question.
- **p-box**: cannot match Float's range (O(steps²) — genuine); defense = stated-and-justified
  scope + spread across TYPES instead of size: soundness 50 configs/~12 topologies (fresh, done),
  tightness deep-dive on grid, + KarlNetwork if E passes (stress case), + fw-reliant drone (real
  infra, 1.5s, already tractable), + **NEW: mlgw-gas p-box conditional on G1 feasibility** (39
  edges — if maxcond modest, seconds of compute for a second real-infrastructure p-box point).
- **Paper mechanism**: include the corpus×mode coverage table WITH the reason for each gap in the
  manuscript (the A1.5 matrix, essentially) — a tabulated justified gap is a scope statement, an
  untabulated one is a reviewer discovery.

## D. Adversarial fanin-k / mesh-w — fresh, timed, fitted (Wave 2) — DONE 2026-08-16

Artifacts: `adversarial_timed.csv` (fresh sweep, warm protocol, per-row conditioning histograms),
`adversarial_fit_summary.txt` (fits), `adversarial_timed.stderr.log`. Old CSV values all
reproduced; timing and the w=9 extension are NEW.

1. **fanin (CONFIRMED + NEW timing):** `ipa_ops = 2k+1` EXACTLY on all 8 rows (k=2..16) — the
   factorization/Lemma-3 claim verified fresh. `bdd_nodes ≈ 16.0·k^1.49` (log-log fit). NEW: wall
   time IPA ≤1ms vs BDD build ~1–2s throughout — on this family IPA is ~1000× faster one-shot.
2. **mesh saturation hypothesis (CONFIRMED):** dlog2(ipa_ops) falls monotonically 4.36 → 0.48 as
   maxcond plateaus at 11 — the sweep measures a fixed-height (L=8) regime where BOTH methods
   saturate; it is NOT a true asymptotic-separation experiment. (Square w×w mesh remains the
   proposal for that, not run.)
3. **Crossover, both units (NEW precision):** in op-units BDD leads from w=3 (old framing); in
   WALL TIME **IPA is faster through w=4** (0.37s vs 1.19s) and BDD leads from w=5 (3.9s vs 1.2s),
   reaching 55× at w=8. The paper's "BDD wins on mesh" survives but should be stated in seconds,
   not op-ratios (the 1486× op-ratio at w=8 overstates a 55× time gap).
4. **NEW FINDING — memory wall between w=8 and w=9:** ops grew ×1.39 (3.9M→5.4M) but wall time
   ×37 (159.5s→5,924.7s); throughput collapsed 24.4k→0.9k ops/s, and CUDD hit a (non-fatal)
   34.7GB allocation failure immediately after. IPA's practical boundary on mesh-8×w is set by the
   sub-problem cache's MEMORY footprint crossing RAM, not by op-count growth. w=9's wall time is
   therefore a practical-boundary datapoint, NOT a clean scaling point — flag wherever cited.
   (BDD at w=9: 3,335 nodes, 3.8s — untroubled.)
5. **§4.3 cost-expression nuance (NEW, wording-relevant):** realized sub-problems exceed
   Σ_d 2^{|C_d|} over UNIQUE diamonds by a factor rising 0.33 → ~48 (decelerating, near-flat by
   w=8→9): nested reconvergence re-evaluates the same diamond under many outer contexts. The
   paper's W = Σ 2^{|C|}·O(|E|) is fine if the sum ranges over context-INSTANCES; the
   unique-diamond version (the one computable most cheaply) underestimates deep-mesh work ×48.
   Recommend §4.3 wording check (see §Corrections).
6. Oracle checks: pathenum rows ~1e-16 exact; MC rows within ~2 stderr units. All BDD builds ok.
7. Per-row conditioning-set histograms recorded (e.g. w=8: 903 diamonds, 42×|C|=1 … 2×|C|=11) —
   direct input to G's total-cost hypothesis.

Paper deliverable (per user decision): compact table/figure with BOTH ipa_ops/bdd_nodes AND
seconds, k and w series, saturation caveat stated. Draft at Wave 4.

**Approved follow-ups (user, 2026-08-16 — Wave 3):**
1. **Static instance-weighted cost predictor**: compute W = Σ over context-INSTANCES of
   2^{|C|}·|E| by walking the nesting structure (root_diamonds → sub_structs), validate
   predicted-vs-realized ops across corpus + mesh → upgrades §4.3 to a validated a-priori cost
   model (strongest available fix).
2. **Square w×w mesh sweep** (w=2..6, per-w budget) → the true asymptotic-separation experiment
   the fixed-L family cannot provide.
3. **w=9 rerun with `--heap-size-hint`** → quantifies how much of the 37× slowdown was GC thrash
   (machine is 16GB; sys_free was ~1.8GB during runs). Honest number may improve.
Framing adopted: symmetric resource characterization — diabetes: IPA fails by memory, BDD by
time; deep mesh: IPA memory-degraded, BDD fine; fanin: IPA wins outright. "Every exact method
pays; we measured which resource and where."

## F. p-box soundness evidence — fresh reconciliation (Wave 2) — in progress

Source archaeology (done earlier): "16/16" = corpus_cvx.jl (8 graphs × 2 regimes, operator-level
cvxF vs MC — the sweep the handoff's 14-count missed); "20/20" = cvx_sound.jl (cvxP); framework
level = pbox_sweep (10 nets) + validate_framework_pbox (4 configs); grid_envelope 18/18; "38" =
20+18.

| Sweep | Level/operator | Historical claim | Fresh result (2026-08-16) | Artifact |
|---|---|---|---|---|
| corpus_cvx.jl | operator-ref, cvxF vs MC, steps=50 | 16/16 sound | **CONFIRMED 16/16 sound (uns=0.000 all)**; tightness pattern reproduced (bands 0.02–0.28 weak-reconv/perfect; →1.00 strong-reconv uncertain); cvxI small violations ≤0.023 also reproduced | `corpus_cvx_fresh.log` |
| cvx_sound.jl | operator-ref, cvxP, steps=20 | 20/20 sound | **CONFIRMED 20/20 sound (uns=0.000 all)**; bands 0.05–0.15 easy regimes, 0.90–1.00 strong-reconv uncertain | `cvx_sound_fresh.log` |
| validate_framework_pbox.jl | framework, cvxP | 4/4 sound | **CONFIRMED 4/4 sound (uns=0.000)**; grid-perfect band 0.18 (was 0.34-UNSOUND pre-fix — fix holds on current code) | `validate_framework_pbox_fresh.log` |
| pbox_sweep.jl | framework | 10/10 sound | **CONFIRMED 10/10 sound (IPA_unsound=0.00e+00 all)**; naive baseline measurably unsound up to 0.652 (random_n12_s3) — historical contrast reproduced | `pbox_sweep_fresh.log` |

**F VERDICT (2026-08-16): every p-box soundness figure the paper cites is CONFIRMED on current
code with persisted artifacts — 16/16 (cvxF operator), 20/20 (cvxP operator), 4/4 (framework),
10/10 (framework sweep). The "dozens of configurations" phrasing in §5.3 is backed by 50 fresh
config-level checks across these four sweeps (16+20+4+10), all with zero soundness violations.**

Note: PBA emits benign "Disagreement between theoretical and observed mean/variance" warnings
during mixture/envelope ops — internal moment-check noise, present in historical runs too; not an
error signal.

## G. Drone p-box tractability (step 1: identification diagnostics) (Wave 2/3) — step 1 DONE 2026-08-16

Artifact: `identify_diagnostics.log`. Identification itself is CHEAP everywhere it completes
(≤0.5s even at K=16) — propagation is the p-box bottleneck, as hypothesized.

**1. The handoff's total-cost hypothesis is now QUANTIFIED and explains both prior failures:**

| K | E | uniq diamonds | maxcond | Σ2^|C| (sum2c) | predicted p-box cost vs K=6 |
|---|---|---|---|---|---|
| 6 | 919 | 180 | 6 | 1,330 | 1× (measured ~270s) |
| 8 | 1,146 | 284 | 9 | 7,758 | ~6× → ~27 min (OVER the 900s budget) |
| 10 | 1,359 | 465 | 14 | 178,382 | ~134× → ~10 h |
| 12 | 1,510 | 691 | 15 | 243,632 | ~183× → ~14 h |
| 16 | 1,648 | 1,005 | 16 | 653,958 | ~492× → ~37 h |

maxcond saturates (14→15→16) while sum2c keeps exploding — exactly why maxcond alone
under-predicts p-box cost. Even absent the K=8 silent-exit anomaly, K=8 would have timed out at
900s; K≥10 is hopeless at steps=50 on this machine. **The p-box tractability boundary on
concentrated-minimal sits between K=6 and K=8, and the driver is total conditioning states
(sum2c), not the widest diamond.** (K=8 anomaly isolation still worthwhile for the SILENT-exit
mechanism, but the boundary itself is explained.)

**2. mlgw-gas-network: p-box GO.** 37 nodes / 40 edges, 7 diamonds, maxcond=4, sum2c=36 —
trivially p-box-feasible (predicted well under a second per operator). Second real-infrastructure
p-box datapoint secured pending the actual run (inputs to be built synthetically around float
values — no pbox/ subdir exists; convention stated when run).

**3. drone-network-full identification DID NOT COMPLETE (900s budget, gc_live ballooned to
25.5GB on a 16GB machine — memory-doomed, mirrors diabetes).** AND a provenance discovery: the
on-disk drone-network-full (289n/6,166e, max in-degree 86) is a DIFFERENT, larger variant than
the 244-node "mission-relevant pairs" build on which the §5.4.3 "conditioning 27–28" figure was
measured (PAPER_GUIDE.md:285 records that original run "blew past 8GB"). So: the qualitative
claim "unrestricted connectivity is well beyond the practical range" is fresh-corroborated
(identification itself exhausts memory); the specific NUMBER 27–28 remains a single historical
heavy measurement with no fresh artifact and ambiguous build identity. → §Corrections: either
cite it as such ("a single heavy measurement indicated 27–28 before memory exhaustion") or drop
the number and keep the (stronger) memory-exhaustion statement. **DECIDED (user, 2026-08-16): drop the 27–28 number.** §5.4.3 (and its echoes in
REVIEWER_RESPONSES_draft R1.6/R2.2 and RESS_edit_proposals) should state the fresh-provable
version: identification itself exhausts memory on the unrestricted network (>25GB demanded on a
16GB machine within 15 minutes, this session's artifact) — "well beyond the practical range"
stands, with no unverifiable width figure attached. This also sets the CAMPAIGN POLICY: any paper
number without a this-session artifact is replaced by what the fresh evidence proves, not
qualified into staying.

**4. vtol item failed on a path bug** (priors live in `interval/` not `float/`) — rerun chained
before E.

**6. FIXED AND VALIDATED (2026-08-17, same follow-up session, user-directed): `is_det` generalized
to Float64/Interval/pbox.** `NewIdentify.jl` now has type-dispatched `_is_zero_val`/`_is_one_val`
helpers (mirroring `DiamondPropagation.jl`'s existing `_pinned01` pattern, split into separate
zero/one checks since the source-node requirement only applies to the one-case) instead of the
Float64-only guard. Safety argument (not just empirical): excluding an already-degenerate node from
conditioning cannot change the answer (Lemma 1, conditional invariance — a degenerate variable's
total-probability sum collapses to one term whether or not it's enumerated); this is over-
conditioning removal, provably answer-preserving, not a new approximation.
**Validated two ways:**
- **Diamond-count check (direct, decisive)**: K=8 concentrated-minimal re-measured with pbox-typed
  priors post-fix: **284 unique diamonds, maxcond=9** — down from 687/maxcond=10 pre-fix, and an
  EXACT match to this table's Float64-diagnosed row (284/9758→ sum2c=7758 both). pbox now
  identifies the identical diamond structure Float64 always did. Item 5's "sum2c is a systematic
  underestimate" finding is now resolved by this fix, not just diagnosed — post-fix, the existing
  sum2c table (rows for K=6..16, vtol) should be accurate for pbox/Interval too, though only K=8 has
  been directly re-confirmed; K=10/12/16/vtol were not re-measured post-fix this pass.
- **Exactness gate (COMPLETE, both scripts, full pass)**: `consolidated_sweep.jl` (Float64+Interval
  vs sifted CUDD, 12 networks × perfect/imperfect = 24 configs) reran clean, all "ok", diffs ~1e-16
  — unchanged from pre-fix. `validate_framework_pbox.jl` (pbox vs 8000-sample MC, 4 configs) — ALL
  4/4 reran SOUND with **bit-for-bit identical** band values to pre-fix history: grid perfect 0.18,
  grid uncert0.7 0.68, bridge_5 perfect 0.58, random_n15 uncert0.7 0.06. Zero unsoundness anywhere.
  grid/bridge_5 have few source nodes (1-2), so the fix's effect there is real but modest by
  construction — K=8's 18 sources is why its reduction is dramatic and grid's isn't; expected, not
  a sign of inconsistency.
Not yet done: re-measuring K=10/12/16/vtol/mlgw diamond stats post-fix (§7 above still cites
pre-fix numbers for those); a full-corpus (129-graph) exactness rerun rather than just the
24-config family subset + K=8.

**7. CORRECTION (2026-08-17, same session): the ~27min K=8 prediction was checked against a REAL
measurement and is WRONG — the linear sum2c-scaling extrapolation model itself is unvalidated
beyond its single calibration point.** `validation/drone_pbox_k8_timed_postfix.jl`: proper warmup
(K=3, 25.0s, JIT paid outside the timed region) then a single real timed run of K=8's FULL
propagation (identify + update_beliefs_iterative), post-fix, steps=50, unspawned. Bounded to 3600s
(1 hour) via shell `timeout` as a safety net, not as the expected endpoint. **Result: did NOT
complete within 3600s (exit 124)** — more than double the ~27min prediction (itself: K=6 measured
270s for sum2c=1330, scaled linearly by K=8's sum2c=7758/1330≈5.83x ≈ 1574s≈26min). The model was
calibrated on exactly one point (K=6) and extrapolated by a single ratio; this result shows that
extrapolation does not hold, i.e. cost is NOT simply linear in sum2c (candidate confounders not
accounted for: sum2ce/stored-edges-per-diamond, which the diagnostic tracks separately and this
model never used; diamond nesting depth; GC/memory pressure at larger p-box array sizes). **Do not
cite the ~27min figure, or any other sum2c-linear extrapolation for K=10/12/16/vtol, without a
real timed measurement.** Cross-reference item E's own cost-model calibration note (above): sum2c
OVER-predicted KarlNetwork by 6.6x (predicted ~1h, measured 9.1min) — the OPPOSITE direction from
K=8's 2x+ underestimate. Two data points, wrong in opposite directions: there is no consistent
correction factor, meaning sum2c is not a time-predictor at all, not merely a miscalibrated one
("order-of-magnitude screen, not a clock" — E's own phrase, now doubly confirmed).

**DECISION: stop trying to produce precise hour-estimates for K=10/12/16/vtol.** The qualitative
claim (impractical at steps=50 on this machine) is already fully supported by real evidence: K=6
measured tractable (270s), K=8 measured intractable (>1h, direct timeout), and K=10/12/16/vtol's
sum2c sits 1-2 orders of magnitude above K=8's — structurally far worse on a measure that, even
though unreliable as a clock, remains a valid monotone ordering/screen. Any manuscript or notes
text citing a specific hour-count for these networks (the ~10h/14h/37h/64h figures earlier in this
same table) should be replaced with the qualitative statement + the real K=6/K=8 evidence chain,
not with a corrected extrapolation — no extrapolation method has been shown reliable enough to
trust for this purpose, and chasing one is not worth the effort for numbers a paper doesn't need
to be precise.

**5. CORRECTION (2026-08-17, follow-up session): the sum2c cost model above is a systematic
UNDERESTIMATE for pbox/Interval — root cause identified, code-confirmed.** K=8 silent-exit
isolation (unspawned main-thread rerun, `validation/drone_pbox_k8_isolate.jl`) measured
**687 unique diamonds, maxcond=10** for concentrated-minimal K=8 using PROPERLY pbox-typed node
priors — not the 284/maxcond=9 this table's row 2 reports. Root cause: `is_det(n)` in
`NewIdentify.jl` (line ~78) excludes prior-1.0 SOURCE nodes from conditioning **only when
`node_priors` is Float64-typed** — the function's own comment states "(Float64-guarded;
pbox/Interval never excluded.)" `identify_diagnostics.jl`'s `diagnose()` always builds Float64
midpoint priors (line ~94: `np[nid] = (lo+hi)/2`) as a fast proxy, on the stated assumption
identification is "type-generic" — it is NOT, specifically for this exclusion. Consequence: every
row in this table (K=6 sum2c=1330 through vtol sum2c=2.75M) was measured on an easier
(Float64-optimized) version of the identification problem than pbox/Interval actually face. The
qualitative conclusion (boundary between K=6 and K=8; sum2c/total-conditioning-states, not
maxcond, is the driver) is very likely still directionally right — K=6's *measured* (not
predicted) pbox success and K=8's *measured* (not predicted) non-completion within budget both
still hold as directly-observed facts, independent of this bug. But the PRECISE sum2c numbers in
this table should not be cited as pbox/Interval's true cost without a caveat, and re-deriving them
with pbox- or Interval-typed `diagnose()` calls (not Float64) is a cheap, worthwhile follow-up
before these numbers go in the manuscript. Separately: this same mechanism (Threads.@spawn vs
main-thread) was tested and did NOT reproduce the original silent early-exit — running K=8
unspawned ran for the full 300s budget (killed by an external `timeout`, exit code 124, not a
crash; 35,910 real PBA operator-noise warnings logged, confirming genuine sustained computation).
The silent-exit anomaly itself therefore still appears specific to the spawned-task context
(consistent with, not proof of, the project's documented stack-overflow-under-Threads.@spawn
failure mode for diamond-join tasks) — narrowed, not fully closed.

## E. KarlNetwork p-box re-test (Wave 2) — DONE 2026-08-16: CLAIM DISPROVEN, KARL PROMOTED

**KarlNetwork p-box COMPLETES on current code**: steps=50, cvxP, propagate **545.9s** (budget
900s); steps=10 warmup 188.6s; identify 0.9s; 145 unique diamonds, maxcond=11, sum2c=17,200;
beliefs for all 26 nodes. Artifact: `karl_pbox_test.log`.
- The PBOX_ANALYSIS.md "grid/KarlNetwork p-box timed out" claim is now empirically DISPROVEN on
  both counts (grid: this session's 50-config F artifacts; Karl: this run) — as suspected, it
  predates the NewIdentify/cvx rewrite. Correction #5 finalized.
- Per the user's checkpoint decision ("keep + promote if E succeeds"): **Karl joins the p-box
  evidence** as the strong-reconvergence stress case (maxcond=11) — labeled honestly as a
  colleague-generated synthetic network.
- Cost-model calibration note: sum2c alone over-predicts Karl (17.2k states → predicted ~1h at
  drone-K6's per-state rate, measured 9.1 min) because per-state cost scales with sub-graph size
  (sum2ce captures this better). Treat sum2c as an order-of-magnitude screen, not a clock.

## H. Threading analysis (H1 read-only) (Wave 2) — done 2026-08-16

**Can identification (`new_identify`) parallelize where propagation can't?** In principle yes; in
practice not worth it for this paper. The analysis:

- **Recursion structure** ([NewIdentify.jl](InfoPropFrmwrk/src/Algorithms/DiamondDecomposition/Internal/NewIdentify.jl)):
  the root loop over `join_nodes` calls `build(v, ∅, incoming(v))` per join — these are independent
  EXCEPT for one shared mutable object: the global `unique_diamonds` memo Dict. `components`/
  `shared_fork` are pure; all mutation funnels through `group_diamond`.
- **The blocking detail**: `group_diamond` INSERTS a diamond's entry into `unique_diamonds`
  (line 140) BEFORE filling its `sub_structs` (lines 141–145). Under any concurrency, a second
  task can memo-hit a half-built entry and consume it — a correctness race beyond mere Dict
  corruption (Julia Dicts are also not thread-safe for concurrent writes, the same class of bug
  that forced propagation's `use_parallel=false`). Safe parallel design = root-join-level worker
  pool + lock-protected memo with **publish-after-build** (build locally, atomically publish;
  concurrent duplicate builds discarded — wasted work, deterministic result). Per-task recursion
  stays serial, so stack depth matches the serial case (no small-task-stack overflow exposure).
- **Why it's not worth doing now**: identification is seconds everywhere tractable (link 724n:
  1.6s) and where it FAILS (diabetes-bnlearn) the failure mode is **memory exhaustion** (9.5GB) —
  parallelism aggravates memory, it doesn't help. No watchlist item depends on identification
  speed. The real identification ceiling is the materialized per-context subgraph storage
  (each unique (edgelist, conditioning) context stores O(|E|) edges) — a storage-representation
  question, not a threading one.

**The `ReachabilityModuleLIFO.jl` archaeology** (handoff's cited path was stale; actual:
[src/Network-flow-algos/src/Active_Work_Algos/ReachabilityModuleLIFO.jl](src/Network-flow-algos/src/Active_Work_Algos/ReachabilityModuleLIFO.jl), 751 lines):
it is a PROPAGATION variant (its own `update_beliefs_iterative`/`updateDiamondJoin`), Float64-only,
built on the OLD pipeline (`DiamondProcessingModule`). Design: per-worker LIFO queues + work
stealing, parallel only at top-level conditioning-state enumeration (`is_top_level &&
num_states >= 2` gate), `ReentrantLock` around the shared diamond cache and result accumulator.
**It pre-solved exactly the two failure modes that later forced propagation single-threaded**
(recursive per-state spawning → task-stack overflow; unlocked shared cache → data race). It was
orphaned by the DiamondDecomposition rewrite, not shown unsound — though no validation record
exists either. Verdict: a viable TEMPLATE if propagation threading is ever revisited (drone-scale
nets, 6–28s, are the only workloads that would benefit); porting cost = re-typing for
Interval/pbox + new pipeline types. **Recommendation: future work, out of scope for this
revision.**

Side-note for the roadmap (not a current bug): NewIdentify's insert-before-fill memo publication
is fragile under any future concurrency work — flip to publish-after-build if H2 is ever pursued.

**Addendum (user pointer, 2026-08-16): accuracy-preserving optimization ideas transferable from the
OLD `DiamondProcessingModule.jl`** (1,771 lines; predecessor of the correct-by-construction module —
scope here is strictly "optimize WITHOUT losing accuracy", per user):
1. **Cached set operations** — the old module's `DiamondOptimizationContext` memoizes
   intersection/setdiff/edge-filtering/ancestor-intersection by set-hash keys. Deterministic, pure,
   zero accuracy risk. NewIdentify's hot spots that would benefit: `infl(p,E)` (fresh Set per
   parent per call), `components`' O(|P|²) pairwise influence intersections, and
   `_subgraph_structure`'s per-node `intersect(full_anc[n], relevant)`.
2. **Algorithmic variant of `components`** — instead of materializing per-parent influence sets and
   intersecting pairwise, index un-conditioned forks → the parents they reach, and union parents
   per fork (same union-find result, O(Σ|anc|) instead of O(|P|²·|anc|)). Provably identical
   grouping (same connectivity relation), so accuracy-safe.
3. **Storage dedup / laziness** — the actual observed failure mode (diabetes, 9.5GB) is the
   materialized per-context subgraph storage. Sub-structures could be built lazily at first
   propagation use, or edgelists deduped across contexts that share structure (identity stays
   (edgelist, conditioning); only the storage layout changes). Highest value, most engineering.
   Priority: (3) attacks the real ceiling, (1)/(2) are cheap CPU wins; threading remains last.
   D's and G1's fresh runs log identification wall-time separately, giving the baseline to judge
   whether (1)/(2) are worth doing at all.

## mlgw-gas p-box + bnlearn interval sweep (Wave 2 additions per checkpoint decisions) — 2026-08-16

**mlgw-gas-network p-box (NEW): SOUND and fast.** steps=50 cvxP propagate 10.2s; soundness vs
3,000-sample framework-Float64 MC across ALL 37 nodes × 21 thresholds: worst violation 0.0057
(SOUND, <0.03); max band 0.540. Inputs synthetic-triangular (W=0.05) around the float values —
structure real, uncertainty synthetic, stated wherever cited. Artifact: `mlgw_pbox_test.log`.
→ The p-box evidence now spans: grid (deep-dive) + Karl (stress, 546s) + fw-reliant drone +
mlgw-gas (real infrastructure) — the "range across types" answer to the coverage concern.

**bnlearn interval sweep (NEW): 15/17 EXACT at machine precision** (corner-agreement ≤2.2e-16;
artifact `bnlearn_interval_sweep.log`): asia, cancer, earthquake, survey, sachs, child, insurance
(maxcond 9), alarm, mildew, barley (maxcond 14, 31s), hailfinder, hepar2, win95pts, pathfinder,
pigs (441 nodes). Two boundary rows:
- **andes: TIMEOUT at 300s with gc_live=18.5GB** — NEW boundary finding AND a notes correction:
  the old "tractable, all <2s" bnlearn claim was IDENTIFICATION time; andes (maxcond=21) hits the
  context-instance memory wall in propagation (same mechanism as mesh w=9 and diabetes/drone-full
  identification). Whether andes Float64 PROPAGATION was ever completed is doubtful — treat
  andes as propagation-intractable on 16GB in any mode until shown otherwise.
- **link: interval propagation FAILS by MEMORY on 16GB — root-caused 2026-08-16.** Three runs
  triangulated it: guarded-sweep failure (suspected contamination) → clean-process spawn failure
  (suspected task stack) → **direct main-task run: `ReadOnlyMemoryError` thrown from a Dict
  ALLOCATION (`rehash!`/`GenericMemory`) inside `updateDiamondJoin`
  (DiamondPropagation.jl:82)** = Windows-flavored memory exhaustion growing the propagation
  dicts, NOT a stack overflow, NOT contamination, NOT a logic bug. Same resource family as
  andes/diabetes/drone-full. Artifact: `link_interval_direct.log`. Float64-only run queued to pin
  link's exact coverage row. NOTE: the historical "16/17 bnlearn tractable" was IDENTIFY-ONLY
  (PAPER_GUIDE §8's own wording) — propagation on andes/link was never actually completed
  anywhere; the notes' "tractable" wording needs the identify-vs-propagate qualifier
  (→ §Corrections).
  **Guard-pattern lesson kept for all future sweeps: after any timeout, exit the process or run
  one item per process — abandoned tasks poison subsequent measurements.**

## Interval memory-wall: root cause, framework fix, and the corner-pair resolution (2026-08-16)

**Diagnosis** (`interval_blowup_diagnosis.log`): the interval-vs-Float64 blowup is CACHE-CONTEXT
MULTIPLICITY — interval-valued contextual beliefs defeat sub-problem dedup, so the same diamond
is evaluated under vastly more distinct prior-contexts. Measured: barley 606,975 interval entries
vs 22,656 float (26.8×; 34.5× time); link 2,050,296 entries at 24GB crash vs 2,982 float.
(Eliminated en route: guard-contamination, spawn task stack, the zero-weight skip — which is
already type-generic (`_pinned01`), correcting my stale memory note.)

**Framework fix (user-approved): `LEAN_DIAMOND_CACHE`** — opt-in flag (default OFF = byte-identical
legacy behavior incl. the server cache serializer). ON: entries store only the join-node belief
(~100× smaller) with a get()-miss collision guard (same-key/different-join → recompute + merge;
exact always). Files: `TypesAndCache.jl` (flag), `DiamondPropagation.jl` (serial lookup path).
**GATE PASSED 11/11** (`lean_cache_gate_trimmed.log`): power/Karl/mlgw/metro/barley × Float64 +
Interval, plus KarlNetwork PBOX steps=20 — per-node EXACT equality off-vs-on, identical entry
counts, ≤6% time overhead. The fix is validated and stays in (default off).

**Payoff attempt & the deeper truth:** link interval with lean ON ran 63 min (5.9GB held, peak
10.1GB) without finishing — terminated (user). So link's context explosion is ≥4 orders of
magnitude, not the 690× the full-entry crash point suggested: lean caching removes the memory
CEILING but not the COUNT. Native interval propagation on link-shaped networks is
impractical-by-time regardless.

**ROOT CAUSE FOUND (user question "is there different diamond sets?" — essentially YES):**
the explosion was largely an artifact of MY synthetic-widening convention, not intrinsic interval
arithmetic. Counts: link has **184/724 nodes with prior exactly 1.0**, andes 89/223, barley 10/48
— perfectly tracking blowup severity. Widening `[v−0.05, v+0.05]` turned every structural
certainty into an uncertainty (`[0.95,1.0]`), which (a) makes those nodes conditionable that
Float64's `is_det` rightly excluded (→ different/deeper diamond sets), (b) prevents the
type-generic zero-weight skip from ever firing, and (c) destroys cache-context dedup. The same
run in Float64 kept the 1.0s certain — so float-vs-interval compared DIFFERENT problems.
Cross-check: the drone interval inputs preserve hub certainty ([1,1]) by design, and 242-node
vtol interval propagation runs in seconds — convention, not scale. Confirmed dramatically by the
corner runs: even a FLOAT propagation with the 184 certainties degraded to 0.95 explodes
(lo-corner ran 3.5+ min vs 0.47s with certainties preserved; killed).

**Corrected convention (all my sweep scripts): degeneracy-preserving widening** — priors exactly
0.0/1.0 stay degenerate; only genuine uncertainties widen.

**CORRECTED-CONVENTION RESULTS (2026-08-16 evening):**
- **link: FULLY RESOLVED.** Native interval propagation **0.574s, EXACT** (corner diff 0.0 both
  bounds) — down from 24GB OOM / >63 min under the flawed convention. Corner-pair route also
  exact (lo 1.37s / hi 0.73s, 0 monotonicity violations). Structural note: interval-mode
  identification retains more conditioning candidates (1,754 diamonds, maxcond 22 on paper,
  since `is_det` is Float64-guarded), but the type-generic `_pinned01` skip drops degenerate ones
  at propagation — the context-aware-identity + zero-weight-skip design working as intended.
  Coverage row: link = Float64 ✓ + Interval ✓ (native).
- **andes: genuinely propagation-intractable on 16GB in ANY value type.** Its FLOAT lo-corner
  crashed (memory) even with all 89 certainties preserved — so the historical "tractable <2s"
  note was identification-only, and no full propagation of andes has ever completed anywhere.
  With 134 genuinely-uncertain nodes and maxcond≈21, this is a real context explosion, not a
  convention artifact. Coverage row: andes = identification ✓ only; boundary specimen alongside
  diabetes (identification/memory) and drone-full (identification/memory).
  CONFIRMED: native-interval under the corrected convention also fails (TIMEOUT 304s at 20.7GB,
  `bnlearn_andes_corrected.log`).
- bnlearn propagation coverage final: **16/17 non-diabetes networks propagate in Float64 AND
  Interval** (15 from the sweep + link corrected); andes excluded with the measured reason.

**Framing (per user, and correct): this episode VINDICATES the diamond-stats cost model, it does
not revise it.** IPA's propagation cost has been understood throughout — before, in, and after
the paper — as a function of the diamond/conditioning statistics; every anomaly this session
(barley 27×, link OOM, andes, mesh w=9, drone K-boundary) was fully explained by those statistics
once they were measured ON THE INPUTS ACTUALLY RUN. The failure here was procedural (Claude's):
inputs were changed without re-measuring the diamond stats that were known to govern cost, and
the initial investigation chased mechanisms instead of running the model's own cheap diagnostic.
Procedural rule now standing: any input-convention change → identify-only diamond-stats probe
first, compared against baseline.

**Still true and still valuable:** (1) the lean-cache fix is validated (11/11 exact gate) and
stays — uncertainty-DENSE networks legitimately grow contexts and lean entries cut that memory
~100×; (2) the corner-pair route remains the exact fallback for any network whose native interval
run is slow; (3) the paper's synthetic-uncertainty convention MUST state that structural
certainties are preserved — a methods sentence (echoes R3.6's transparency ask).

## Wave-3 approved items — results (2026-08-16 late evening)

**Square w×w mesh sweep (`square_mesh.csv`) — DONE, the true asymptotic story:** with BOTH
dimensions growing, neither method saturates: IPA ops grow ~×20/step (46 → 452 → 5,982 → 120,383
at w=4..7; maxcond 3→9), BDD nodes ~×3–7/step (248 → 759 → 1,035 → 7,479). Both exponential;
BDD's exponent smaller — the honest asymptotic-separation statement the fixed-L=8 family could
not provide. Oracle-exact (pathenum ≤3.9e-16) through w=4. Complements D's saturating family:
paper gets BOTH regimes, cleanly labeled.

**mesh w=9 with --heap-size-hint=10G — running** (w=5 calibration 4.17s ≈ no-hint 3.87s; w=9 leg
>25 min at last check vs 5,924.7s no-hint reference → hint at best a partial rescue; final
number recorded when it exits).

**p-box steps regression — attribution in progress:** Julia-version hypothesis WEAKENED
(julia-1.12.6 installed Jul 26 20:06, hours BEFORE the Jul-27 00:20 historical measurements —
they were likely already on current Julia). The user-approved keyed unit-box cache is APPLIED to
`pbox_conditional_combine` (`_unit_box(n)` in InputProcessingModule.jl — exactness-identical
content, keyed by operand discretisation length). `pbox_component_probe.jl` queued (auto-runs
when the heap-hint job exits): re-times steps=50/200 on repaired code AND times mixture/env/
imp/makepbox in isolation for real attribution, plus a bitwise cached-vs-fresh clamp equality
gate.

## G2. Sifted-BDD K-sweep on drone family (Wave 3)

_(pending — with K=8 anomaly isolation; next session's opener alongside the witnessed diabetes
probe (LAST per user) and the remaining PENDING watchlist rows: grid regression, Float64 corpus
pipeline, drone belief re-derivation.)_

## Corpus regression block (Wave 2 final) — in progress 2026-08-16 evening

**Interval over the FULL 129-graph corpus — DONE, claim/artifact mismatch CLOSED**
(`interval_sweep_full.csv`): attempted=129, checked=129, **failed=0, IPA_exact=129**; worst
over-width 2.22e-16, worst unsound-direction deviation 2.78e-16 (both machine precision); naive
baseline over-widens up to **0.4522** — the paper's "up to 0.45" figure confirmed. Root cause of
the old 113-row artifact: the historical sweep's oracle used the NAIVE CUDD build and silently
dropped (bare `catch`) the ~16 dense graphs whose naive build blew up — the ORACLE was
intractable on those, never IPA; fixed by switching the oracle to the sifted build (0 failures).
§5.3's "verified across the full corpus" is now literally artifact-backed.

- `interval_bdd_vs_ipa_timing` (#7): **CONFIRMED** — IPA faster on all 8 families, fresh ratios
  3.9–99.9× (old 2.9–95.1×; same BDD node counts; normal jitter). Paper table + "2.9 to 95"
  phrase should update to fresh values (→ Corrections #6).
- `timing_imprecise` (#10): **RESOLVED (2026-08-17 morning) — NOT a regression; the HISTORICAL
  measurement was wrong.** Attribution chain: (a) component probe shows all cost sits in the
  cvxP blend convolutions (33ms × 2·steps blends per combine at steps=200; mixture/env/imp/
  makebox ≤0.035s) — the operator's documented O(steps³), which `pbox_operator_and_soundness`
  already recorded; (b) the clamp is exonerated (keyed-cache repair changed nothing: 6.65s/313.8s
  vs 5.98s/275.7s pre-repair; bitwise gate IDENTICAL — cache kept as a harmless micro-win);
  (c) **the smoking gun: `timing_imprecise.jl` builds its p-box inputs ONCE at ambient
  discretisation and only flips `PBA.setSteps` between legs** — its "steps=200/800" rows never
  propagated genuinely 200/800-level distributions, which is how it printed an impossible
  sub-linear curve (8.27s "at 200", 110s "at 800") for a cubic operator. The faithful
  measurement (inputs rebuilt per level + setSteps) gives ~6.7s @50 and ~314s @200 on cex,
  slope ≈ steps^2.8; a 25/50/100/200 curve is being measured for the exponent fit; steps=800
  is impractical (~hours) and should not be claimed. Today's Karl/mlgw/vignette numbers are
  faithful current values and all consistent. → Corrections: replace §5.3's "grows
  quadratically… (2.7s, 8.3s, 110s at 50/200/800)" with the measured ≈cubic scaling + fresh
  curve + a practical-band recommendation (steps≈25–100); `pbox_steps_scaling.csv` carries the
  same historical bug; `timing_imprecise.jl` needs the inputs-per-leg fix (user's script —
  flagged, not touched).
- **Heap-hint w=9 (Wave-3 #3): REFUTED, decisively.** With `--heap-size-hint=10G` the w=9 run
  took **38,108s (10.6h)** vs 5,924.7s no-hint (same 5,426,417 ops — deterministic): the larger
  allowed heap ballooned to ~14GB on the 16GB machine and made OS-level pressure worse. w=9's
  practical boundary stands at ~99 min; heap tuning does not rescue it, corroborating the
  memory-wall (not GC-tuning) reading. Lesson: the run should have carried a budget — it consumed
  the night.
- `certified_bound_vignette` (#11): **CONFIRMED digit-for-digit** (bands [0,0.02]/[0,0.10]/
  [0,0.12]/[0.98,1.00]; MC 9,604/385/267/9,604). `grid_envelope` (#9): **CONFIRMED 18/18 sound**,
  bands 0.180→0.70 exactly matching §5.3's quoted range.
- **p-box steps regression QUANTIFIED** (`pbox_steps_probe.log`): steps=50 5.98s (July ref 2.68s,
  ×2.2), steps=200 **275.7s (ref 8.27s, ×33)** — steps-dependent slowdown fully explaining the
  killed timing_imprecise run (steps=800 extrapolates to ~1h/repeat). Prime suspect: Jul-27
  clamp's per-combine unit-box rebuild. Proposed repair: cache the unit box KEYED BY current
  PBA steps (exactness-identical; the original module-load cache was the bug, keying fixes it).
  Awaiting user approval → then before/after probe + value-equality gate, then re-measure the
  paper's steps-scaling row on repaired code.
- **W-predictor** (`w_predictor.log`): the no-dedup instance bound is VALID but loose — realized
  = 1–5% of W_pred (cache dedup worth 20–100×). §4.3 wording: "sound a-priori upper bound with
  family-dependent dedup factor", not "definite per-instance cost". (Full per-family table in log.)
- **Adversarial interval** (`adversarial_interval.csv`): EXACT (corner-diff 0.0) on all fanin k
  and mesh w=2..7 — Interval==Float64 coverage closure for the family. TIMING columns of the big
  mesh rows are POLLUTED (float corner legs ran after the interval leg's multi-GB cache in the
  same process: 2,291s vs 81s fresh-process reference) — discard timings, keep exactness. mesh_8
  leg deliberately killed (redundant datum, polluted timing). **Process-hygiene rule, now twice
  learned: one timing measurement per fresh process.**

## Corrections recommended for user's notes + manuscript (I do not apply these)

Policy (user, 2026-08-16): numbers without a this-session artifact are DROPPED in favour of what
fresh evidence proves — not qualified into staying.

| # | File / location | Current claim | Recommended action | Evidence artifact |
|---|------|---------------|--------|-------------------|
| 1 | main.tex §5.4.3 + §5.5; REVIEWER_RESPONSES_draft R1.6/R2.4; RESS_edit_proposals (3 spots) | "unrestricted connectivity produced conditioning requirements of 27–28" | **DROP the 27–28 figure** (single historical 8GB-blowing run, ambiguous build). Replace with: identification itself did not complete — demanded >25GB on a 16GB machine within 15 min. Qualitative claim strengthens, number goes | `identify_diagnostics.log` (drone-network-full row) |
| 2 | main.tex §4.3 cost expression | W = Σ_d 2^{|C_d|}·O(|E_d|) "computable before enumeration" | Clarify the sum ranges over context-INSTANCES (unique-diamond version underestimates ×48 on deep mesh); static instance-weighted predictor + validation coming (Wave 3 approved) | `adversarial_timed.csv`, fit summary |
| 3 | main.tex §5.2 text | "several real infrastructure networks" | Reword: munin/water are bnlearn PGM benchmarks (provenance); real infra = power (untraced), mlgw-gas (cited, adopted), drone. Add the corpus×mode coverage table | A1 provenance section |
| 4 | Old adversarial framing (notes; planned paper table) | "BDD wins by orders of magnitude" (op-ratio 1486×) | State crossover + gap in SECONDS (IPA faster ≤w=4; BDD 55× at w=8); op-units as secondary | `adversarial_timed.csv` |
| 5 | notes/PBOX_ANALYSIS.md (BOTH copies: notes/ AND validation/) line ~100 | "grid/KarlNetwork p-box timed out" | **RETIRE the claim in both copies** — disproven: grid via 50 fresh sound configs; Karl completes steps=50 in 546s | F logs; `karl_pbox_test.log` |
| 6 | main.tex tab:interval_timing + §5.3 "2.9 to 95" | old timing values | Update to fresh values (3.9–99.9×, same direction/magnitudes) | fresh `interval_bdd_vs_ipa_timing.csv` |
| 7 | main.tex §5.3 "grows quadratically with the discretisation level (2.7s, 8.3s, 110s at 50/200/800)" | wrong exponent AND mismeasured numbers (historical script fixed inputs, flipped setSteps only) | **REPLACE**: cost grows ≈cubically (O(steps³) per combine, measured slope ≈2.8); fresh curve 25/50/100/200; recommend the steps≈25–100 practical band; do NOT claim steps=800. Also fix `pbox_steps_scaling.csv` + `timing_imprecise.jl` (inputs must be rebuilt per leg) | `pbox_component_probe.log`, `pbox_steps_probe.log`, steps-curve log |
| 8 | PAPER_GUIDE §8 + CORPUS_INVENTORY §5 "bnlearn 16/17 tractable, all <2s" | identification-only figures presented as tractability | Qualify: identify 17/17 <2s; PROPAGATION 16/17 (float+interval, link included via corrected convention); andes propagation-intractable any mode (memory, maxcond≈21) | bnlearn sweep logs, andes/link direct logs |
| 9 | manuscript methods (§5.3/§5.4 inputs) | synthetic-widening convention unstated | Add methods sentence: synthetic uncertainty widens only non-degenerate priors; structural certainties (0/1) preserved — degrading them changes the problem class (mirrors drone hub [1,1] semantics) | link convention experiments |
| 10 | main.tex §5.5 practical-range paragraph | — | ADD the resource-symmetry finding: diabetes = IPA memory-fail vs BDD time-fail; mesh w=9 = IPA memory wall (heap tuning refuted) vs BDD fine; fanin = IPA wins outright; square mesh = both exponential, BDD smaller exponent | B/D/sqmesh/heaphint artifacts |
| 11 | `identify_diagnostics.log` / G's sum2c table (K=6..16, vtol) — any paper text citing these exact numbers | sum2c predictions computed via Float64-typed `diagnose()` calls | **FIXED, not just caveated**: `is_det` (`NewIdentify.jl`) generalized to Float64/Interval/pbox (2026-08-17, user-directed, gated). Post-fix, pbox-typed K=8 measures 284 diamonds/maxcond=9 — an exact match to the table's Float64 row, confirming the fix resolves the discrepancy rather than just explaining it. Exactness gate: `consolidated_sweep.jl` (Float64+Interval vs BDD, 24 configs) clean; `validate_framework_pbox.jl` (pbox vs MC) ALL 4/4 configs confirmed bit-for-bit identical to pre-fix values (SOUND, zero unsoundness). **Remaining**: K=10/12/16/vtol/mlgw diamond stats not yet re-measured post-fix (table above still shows pre-fix numbers for those); full 129-graph exactness rerun not done (only the 24-config family subset + K=8) | `drone_pbox_k8_isolate.jl`, `k8_isolate.log`, this table's item 6 (2026-08-17) |

## Artifact index

| Artifact | Produced by | Date |
|----------|-------------|------|
| _(pending)_ | | |
