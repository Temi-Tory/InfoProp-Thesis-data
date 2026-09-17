# Corpus inventory (2026-08-16, corrected 2026-08-17)

Full audit of every network with ACTUAL recorded IPA results, cross-referenced against
`dag_ntwrk_files/` so "exists as a file" is separated from "has results." ~60 directories
(central_scotland_*, edinburgh_area, national_*, HB0_local_*, most drone-network-* variants beyond
the 3 official ones, pareto-point-1..6, scaled-power-network-*x, etc.) are leftover generated files
from earlier project phases with **zero references** in any results CSV or notes file — not part of
the reported corpus, not counted below.

> **CORRECTIONS (2026-08-16/17, `validation/fresh_20260816/` campaign)** — every open item this
> document originally flagged was independently re-verified under a "fresh-or-it-didn't-happen"
> policy. Authoritative record: `validation/fresh_20260816/MASTER_FINDINGS.md` (full findings + a
> 11-row corrections ledger). Headline corrections affecting this document specifically:
> - Directory count was **90, not 85** (two non-orphan surprises found: `drone-network-full`,
>   289n/6166e; `mlgw-gas-network`, since adopted as real infrastructure — see below).
> - `paper_data.csv` **IS** the literal 129-graph list (this doc's "no single file lists all 129"
>   caveat was wrong) — assembled by `validation/make_merged.jl`.
> - **The stale "p-box times out on grid/KarlNetwork" claim (§4 below, and `PBOX_ANALYSIS.md`) is
>   DISPROVEN** — grid confirmed fine repeatedly; KarlNetwork freshly re-tested, completes steps=50
>   in 546s, and has been **promoted into the p-box evidence corpus**.
> - **p-box soundness sweep is 50 configs (16/16, 20/20, 4/4, 10/10), not the ~14 this doc found** —
>   the missing sweep (`corpus_cvx.jl`) was located and re-verified fresh. See §6.
> - **Net3 (EPANET water distribution benchmark) added this session** (2026-08-17, separate from the
>   campaign) — 97 nodes/119 edges, 51 diamonds, maxcond=5, comfortably tractable. See §4a.
> - A **real bug was found in the drone p-box cost model** itself (`is_det` in `NewIdentify.jl`
>   excludes prior-1.0 sources from conditioning only for Float64-typed priors, never for pbox/
>   Interval) — the campaign's K=6..16 cost predictions (§7 below) were measured on an
>   easier-than-real version of the problem and are systematic underestimates. See §7.
> Treat every number below as superseded wherever this banner's points contradict it; sections not
> mentioned here were not specifically re-checked this pass.

## Top-line summary

| Group | # networks | Size range (V/E) | Float64 | Interval | p-box | vs sifted BDD |
|---|---|---|---|---|---|---|
| Core regression corpus ("129-graph gate") | 129 | n=4 to ~130 | 129/129 exact | 129/129 exact | no | 114/114 (subset) exact |
| 6 named topological families | 8 curated instances | 8-25 V | exact | exact | partial (below) | 8/8, 2.9x-95x faster |
| Adversarial scaling families (fanin-k, mesh-w) | 15 configs | 7-64 V | exact | — | no | 15/15, incl. deliberate BDD losses |
| Real infrastructure (power/Karl/metro/munin/water) | 6 | 28-1398 E | exact | exact | **no (timed out)** | power/grid/Karl only |
| bnlearn (cited PGM repository) | 17 (16 usable) | 8/8 to 724/1125 | exact (synthetic priors) | not run | no | not run |
| p-box soundness sweep | ~12 distinct networks, ~14 configs | 10-16 V | — | — | sound, 14/14 | no |
| Drone case study (real, this session) | 3 official + 1 K-variant | 217-242 V, 263-1753 E | exact | exact | 2/4 tractable | yes, sifted CUDD |

Total distinct networks with **any** recorded IPA result: **~185** (129 core + 8 families overlap with
core + 15 adversarial + 6 infrastructure + 17 bnlearn + drone). Note the 8 named families and some
infrastructure networks double-count against the 129 in places — see caveats at the end.

---

## 1. Core regression corpus — "129-graph gate"

Authoritative definition (from `notes/REVIEWER_RESPONSE_map.md`, R2.1 response, quoted verbatim):
> "129 random+mutant DAGs (n=4..~130, density 0.05–0.46, 2 probability vectors) + 6 topological
> families {multi-source, grid/lattice, layered/k-partite, bridge (non-series-parallel),
> series-parallel, complete} + larger n=30–50 + real infrastructure {power, grid, KarlNetwork, drone,
> metro, munin} + adversarial {fanin-k, mesh-w}."

- **Float64**: 129/129 exact vs ground truth (machine precision, ~1e-16).
- **Interval**: 129/129 exact (machine precision) — "Neglecting reconvergent dependence
  (independence-assuming propagation) is over-wide for intervals" is the contrasting unsound baseline.
- **vs sifted CUDD**: 114/114 exact (a subset of the 129 — not all 129 were BDD-compared; the 15-config
  gap is likely the adversarial/mesh cases deliberately run past BDD's comfort zone, see §2).
- Underlying data files: `paper_data.csv` (131 rows — random n=10..28 + `mutant_rand28_s1..8`, columns
  include density, nroots, nuniq (unique diamonds), maxcond, naive-vs-sifted BDD node counts and
  status), `interval_sweep.csv` (113 rows, IPA vs naive interval over-width), `large_graphs.csv` (19
  rows, n=30..50, both random and multi-source variants), `cudd_complexity.csv` (a smaller/earlier
  overlapping subset of the naive-vs-sift comparison).
- **Size/density from `paper_data.csv`** (n=10..28 portion): V=10..28, E=12..73, density=0.14..0.42,
  nroots (fork proxy)=2..20, **nuniq (unique diamonds)=4..154**, **maxcond=1..17**. Naive-BDD blowup
  (>2.5M nodes / node cap hit) on 15/131 configs, almost all in the densest random_n25_p02_* group;
  sifted BDD never blew up (0/131).
- **Size/density from `large_graphs.csv`** (n=30..50 portion): V=30..50, E=44..113, both single-source
  random and multi-source variants, all "ok" (exact vs sifted BDD, exact vs MC where checked).
- Caveat: I could not locate a single file listing all 129 by name with size+diamond stats in one place
  — the figure is assembled from `paper_data.csv` + `large_graphs.csv` + the "n=4..~9" small end,
  which I did not find a dedicated CSV for (possibly folded into `complexity_validation.csv`'s named
  families instead, or generated/discarded before being saved). Treat "129" as the authoritative
  cited figure from the reviewer-response map, not something I independently recounted row-by-row.

## 2. 6 named topological families (curated, reused across many experiments)

grid_4x4/grid4x4, grid_5x5, bridge_5 (+bridge_3), layered_5x4/layered4x6, seriesparallel_4,
complete_8, counterexample(-n15), multisrc_n15/multisource, random_n15/n20/n25 (as named
representatives, distinct from the bulk `random_n*_p*_s*` sweep in §1).

- **Float64 + Interval vs sifted CUDD**: `consolidated_sweep.csv` — 12 networks × {perfect, imperfect
  node} = 24/24 configs, all exact (worst diff ~3.3e-16 Float64, ~2.2e-16 Interval).
- **IPA-interval vs sifted-BDD-interval TIMING** (one-shot query cost): `interval_bdd_vs_ipa_timing.csv`
  — 8 families, IPA faster by **2.9x (random_n25) to 95x (grid4x4)**. Sizes V=8..25, E=21..57,
  bdd_nodes=215..5622.
- **Complexity/diamond stats**: `complexity_validation.csv` — grid_4x4 (V16/E24, 39 diamonds,
  maxcond=7), grid_5x5 (V25/E36, 50 diamonds, maxcond=5), counterexample (V15/E23, 13 diamonds,
  maxcond=4), bridge_5 (V16/E25, **55 diamonds, maxcond=10**), complete_8 (V8/E28, 21 diamonds,
  maxcond=6), layered_5x4 (V20/E34, 48 diamonds, maxcond=6), plus random_n12/15/20/25 (s1/s2 each).
- p-box status: bridge_5 and random_n15/n20/n25-scale instances get soundness coverage via §5's
  pbox_sweep.txt / validate_framework_pbox.jl; grid gets the deepest p-box treatment of any network in
  the whole corpus (see §5 and this session's transition-zone work). seriesparallel, complete_8,
  layered, counterexample, multisource have **Float64/Interval only, no p-box run recorded**.

## 3. Adversarial controlled-scaling families

`adversarial_factored.csv` — two deliberately-constructed families to probe worst-case exponential
behaviour directly (not random sampling):
- **fanin-k** (k=2,4,6,8,10,12,14,16): V=7..49, E=8..64, maxcond=1 for all (single wide fork, not
  nested) — IPA ops grow linearly (5..33), bdd_nodes grow slower (37..802). Validated exactly against
  path-enumeration up to k=8, Monte Carlo at k=10, "skip" (no independent oracle, BDD-status-only)
  beyond that.
- **mesh-w** (w=2..8): V=16..64, E=21..105, **maxcond=6..11**, unique diamonds 21..903. This is where
  BDD's advantage is deliberately demonstrated: at w=8, bdd_nodes=2621 vs IPA ops=3,895,252 — **BDD
  wins by orders of magnitude**, validated exactly (path-enum up to w=2, MC to w=5, skip beyond).
- No p-box run on either family.

## 4. Real infrastructure networks (non-drone)

power-network (28 E), KarlNetwork (75 E), metro_directed_dag_for_ipm (351 E), munin-dag (1398 E),
munin-sub1 (273 E), water (67 E, node/arc count matches bnlearn's own `water` network — likely the
same source, converted twice via different pipelines).

- **Float64 + Interval**: exact on all 6 (`notes/PIPELINE_REWRITE_STATUS.md`, `notes/ROADMAP.md`:
  "power/grid/KarlNetwork exact"; metro explicitly confirmed running "end-to-end... through
  new_identify" per `ROADMAP.md`).
- **p-box**: explicitly attempted and **timed out** on grid+KarlNetwork per `notes/PBOX_ANALYSIS.md`
  ("p-box propagation is SLOW (PBA interpreted); grid/KarlNetwork p-box timed out") — this predates
  this session's drone p-box tractability-boundary finding but is the same underlying phenomenon:
  p-box cost compounds with diamond count/conditioning width in a way Float64/Interval doesn't.
  metro/munin/water/power have **no p-box attempt on record** at all.
- **vs sifted BDD**: power, grid, KarlNetwork confirmed exact ("114/114" umbrella above likely
  includes these); metro/munin/water BDD-comparison status not found in notes — flag as unconfirmed,
  not "not done."

## 5. bnlearn corpus (cited PGM benchmark repository, 2026-07-28)

17 networks converted from bnlearn.com/bnrepository via a BIF-topology parser (structure only,
synthetic Float64 reliabilities assigned — legitimate for a structural-exactness claim, explicitly
**not** a decision-relevant one per `PAPER_GUIDE.md`).

| network | V/E | maxcond | status |
|---|---|---|---|
| asia | 8/8 | — | tractable |
| cancer | 5/4 | — | tractable |
| earthquake | 5/4 | — | tractable |
| sachs | 11/17 | — | tractable |
| survey | 6/6 | — | tractable |
| alarm | 37/46 | — | tractable |
| child | 20/25 | — | tractable |
| insurance | 27/52 | — | tractable |
| barley | 48/84 | — | tractable |
| mildew | 35/46 | — | tractable |
| hailfinder | 56/66 | — | tractable |
| hepar2 | 70/123 | — | tractable |
| win95pts | 76/112 | — | tractable |
| andes | 223/338 | **21** | tractable (753 unique diamonds, mostly tiny) |
| pathfinder | 109/195 | — | tractable |
| pigs | 441/592 | — | tractable |
| link | 724/1125 | **6** | tractable, identify in 1.6s |
| **diabetes** | **413/602** | n/a | **EXCLUDED — confirmed intractable.** 97 forks, 265 joins (unusually reconvergence-dense). Two independent attempts both crashed via memory exhaustion (7.9GB pre-emptive kill, then 9.5GB+ hard segfault) before completing identification, let alone propagation. |

All maxcond values for the 15 "—" rows are reported only as "0-21 range, all <2s" collectively in
`PAPER_GUIDE.md` §8, not broken out per-network in any file I found — only andes (21) and link (6) have
individually-quoted values. Float64 only (synthetic priors); Interval/p-box not run on this corpus.
**BDD status: diabetes-bnlearn's sifted-CUDD behaviour is still an open question** — I fixed a real bug
in `validation/diabetes_bdd_probe.jl` this session (it would silently exit before finishing if run as a
plain script rather than `include`d in a REPL) but have no confirmation it was ever successfully run to
completion since the fix. This is a genuine open item, not a stale one.

## 6. p-box soundness sweep (small networks, dedicated soundness check)

Two separate sweeps, not fully reconciled with each other or with the "16/16" figure quoted in
`PAPER_GUIDE.md` §3 (I could only directly verify 14 configs across ~12 distinct networks — flagging
the discrepancy rather than asserting 16 without a source):

- `data/pbox_sweep.txt` (10 networks, all V=10-15): bridge3, seriesparallel3, grid3x4, layered4x3,
  multisrc_n12, random_n12_s1/s2/s3, random_n15_s1, cex_n15 — all reported SOUND, IPA_unsound=0.00e+00
  in every case (contrasted against a naive/independence baseline that IS measurably unsound, up to
  0.65 on random_n12_s3).
- `validation/validate_framework_pbox.jl` (4 configs): grid (perfect + uncert0.7), bridge_5 (perfect),
  random_n15 (uncert0.7) — all SOUND vs 8000-sample Monte Carlo.
- `data/grid_envelope.csv` (6 rows): grid ONLY, sweeping distribution (tri/uni) × regime × width
  (0.05-0.15) — not new networks, deeper characterization of the one network.
- `data/timing_imprecise.csv`: **only 1 network** (counterexample, V15/E23) — Float64 vs Interval vs
  p-box at steps=50/200/800, showing p-box's steps-driven cost explicitly (2.7s → 8.3s → 110s at
  steps 50/200/800 respectively, vs 0.7ms Float64).

## 7. This session's additions (drone case study + deep p-box characterization)

Drone case study — 3 official networks, all real-infrastructure-grounded (Jones et al. Scotland medical
drone paper), Float64 + Interval + sifted-BDD-comparison complete for all 3 (belief CSVs: 218-243 rows
each, one row per node):

| network | V/E | maxcond | Float/Interval/BDD | p-box |
|---|---|---|---|---|
| fw-reliant-centralized | 217/263 | 10 | all exact/validated | **tractable** (1.5s), 0/194 sinks show cvxP/cvxF divergence (edges all degenerate [x,x] — structural, explained) |
| concentrated-minimal (K=16, official) | ~233/1648 | 16-17 | all exact/validated | not attempted at official K=16 |
| concentrated-minimal-K6-test (control variant) | 230/919 | 6 | Interval only (this was a K-tuning control, not an official network) | **tractable** (266-270s), 36 diamonds, 0/191 sinks diverge |
| vtol-dense-decentralized | 242/1753 | 17 | all exact/validated | **INTRACTABLE** — didn't finish steps=10 warmup within 1hr |
| concentrated-minimal K=8 (probe) | untested exact size | untested | not run | **unexplained silent stop** (not a timeout, not a caught error — process exited cleanly mid-run) |

Deep p-box operator-divergence (cvxP vs cvxF) characterization, this session, full 21-point threshold
sweeps: grid (steps=50 AND 200, confirming the divergence gap is not a discretization artifact),
bridge_5, random_n15 — all three show divergence **concentrated in the transition zone of the true
belief distribution**, not uniform/tail-only. This is the deepest p-box characterization of any
networks in the whole corpus; it has NOT been extended to the bulk 129-graph corpus or the bnlearn
corpus.

---

## Honest gaps (relevant to "is the tested range too narrow")

1. **p-box has by far the thinnest coverage of the three input types.** Roughly 14-16 soundness
   configs + 3 deeply-characterized networks (grid/bridge_5/random_n15) + 2 tractable real-network
   demonstrations (both showing zero operator divergence, explained) + 2 real-network intractability
   findings, against Float64/Interval's 129+17+6-network coverage.
2. **p-box's tractability boundary is measured but narrow**: comfortably tractable at maxcond≤10 on
   small synthetic networks and at maxcond=6-10 on real drone networks (263-919 edges), but breaks down
   somewhere between K=6 and K=16-equivalent redundancy on the real network family — a boundary that's
   real and reproducible (twice-confirmed K=6 success) but not finely resolved (K=8-15 gap unexplored/
   unexplained after two failed attempts this session).
3. **bnlearn corpus is Float64-only** — no Interval or p-box run on any of the 17 (16 usable) networks,
   despite it being the largest-scale, most citation-legitimate part of the whole corpus (up to
   724 nodes / 1125 edges).
4. **metro/munin/water have no p-box attempt on record**, and their BDD-comparison status (beyond
   power/grid/Karl) is unconfirmed in the notes I found.
5. **diabetes-bnlearn's BDD status is genuinely unresolved** — not a stale gap, a real open item with a
   just-fixed script ready to answer it.
