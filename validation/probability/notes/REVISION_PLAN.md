# RESS revision — section-by-section scope plan (awaiting sign-off before prose)

Manuscript confirmed: `RESS_Paper__New_.docx` is the RESS submission (title/authors match; §5.1 grid
vs dPrPm with the 134× claim, §5.2 six Pareto drone configs, Algorithm 1, Lemmas 1–2 sketch proofs —
all exactly what the reviewers quote in `Reviewer_Comments_Response_Tracker.docx`). The file has no
tracked changes and its comments part is an empty stub; 12 embedded figures are invisible to text
extraction (captions are visible). Deliverable will be a markdown proposal doc (quote existing passage →
proposed replacement → one-line rationale per edit) for manual application in Word.

Thesis chapters in the same folder are separate documents — NOT edited under this plan unless the user
says which should track the paper (open question Q1 below).

## Planned changes (mapped to reviewer comments; lengths are rough targets)

| # | Section | Change | Answers | Size |
|---|---------|--------|---------|------|
| 1 | Abstract | Rewrite: drop 134× headline (keep dPrPm only as caveated indicative comparison), add ROBDD-verified exactness across corpus + applied network, imprecise (interval/p-box) capability as the distinguishing contribution, rebuilt 3-configuration case study + redundancy/tractability finding | R2.2, R2.1/R3.2, new capability | ~250 words (replace) |
| 2 | §1 Introduction | Update contribution list: add native imprecise-reliability propagation; moderate "nearly real-time" claim to match honest complexity position | new capability, R2.4 | ~150 words edited |
| 3 | §1.1 Related Works | New paragraph: imprecise probability in reliability (interval reliability, p-boxes, Fréchet–Hoeffding bounds, Williamson & Downs 1990); 2–3 sentences positioning IPA relative to cutset conditioning / junction trees (full treatment in §4.3) | new capability, R3.1 | ~250 words new |
| 4 | §2 Network Model | Add formal set-theoretic model (reachability indicator recursion, ancestry/influence sets, forks/joins — from PAPER_GUIDE §4); extend component model to interval- and p-box-valued reliabilities | R2.7, t1, t3 groundwork | ~0.5–1 page |
| 5 | §3 IPA | Worked multi-level nested-diamond trace (can reuse the Figure-12 network) beyond the single-diamond example | t1 | ~0.75 page |
| 6 | §4.1–4.2 | Upgrade Lemma 1/2 proof sketches to full proofs (conditional invariance via law of total probability; separator sufficiency); add NEW Lemma: independent-substructure factorisation (fan-in: 2^k → linear); add context-aware supernode identity + zero-weight-state skip in mathematical language (overlapping/shared-conditioning diamonds) | t3, t2, t4, R2.7 | ~1.25 pages |
| 7 | §4.3 Complexity | Replace qualitative text: exact per-instance cost formula Σ 2^\|C_d\|·O(\|E_d\|); conditioning width bounded by / tracking treewidth-pathwidth; formal relation to cutset conditioning and junction-tree inference; measured cost same order as well-ordered ROBDD, neither dominating (honest: no structural advantage; niche = imprecise inputs) | R2.4, R3.1, t5, t8 | ~1–1.5 pages |
| 8 | §4.4 Implementation | MANDATORY correction: current text says p-box propagation uses independent convolution — that recombination is now known unsound for the conditioning step and was replaced by the convex-combination operator (Fréchet blend provably sound; positive-dependence blend empirically validated, proof open). Add one-sentence numerical footnote ([0,1] projection safeguard). Trim implementation detail (Q2) | correctness, new capability | ~250 words replaced |
| 9 | §5.1 Grid | Extend into full methodology demonstrator: (a) dPrPm published comparison kept with explicit accessibility caveat + moderated speed claim; (b) NEW independent re-verification vs canonical ROBDD (agreement ~1e-16; two hardening fixes disclosed, published table stands); (c) NEW interval propagation — exact by monotonicity, faster one-shot than ROBDD route (state one-shot scope honestly); (d) NEW p-box propagation — Fréchet blend as guaranteed bound, tighter blend as empirically validated; tightness envelope; certified-bound vignette (band 0.02–0.12; simulation would need ~270–9,600 samples worst-case planning); discretisation cost as a controllable dial; (e) timing-methodology sentence: all runtimes measured after warmup/discard-first-run | R2.1, R2.2, R2.3/R3.2, new capability | ~2 pages + 2 figs |
| 10 | NEW §5.x | Corpus-wide comparison vs exact ROBDD: breadth (129 random/mutant DAGs + topological families + real networks), exactness everywhere, cost same order both ways | R2.1, R2.3, R3.2 | ~1 page + table |
| 11 | §5.2 Drone case study | FULL REPLACEMENT (Q3): source-grounded inputs (hubs always available; non-hub interval band around the source study's own failure figure; range-cutoff connection rule matching the source's own model; ONE flagged extension — weather-derating interval near range limit); three configurations explicitly labelled proxies for the source's described trade-off points; redundancy (alternate-routes-per-location) sweep → measured practical boundary calibrated to the reviewers' own depth-18 figure; ROBDD comparison on the same networks (exact agreement; ~14×/~6× faster interval one-shot; decision-diagram non-completion at the higher redundancy level under both orderings — state the narrow verified claim only); reliability findings lead: worst-served locations 55–72% reachability confidence, map-style figure | t6, R2.5, R2.6, R2.3/R3.2, R3.3 (partial) | ~2.5–3 pages, replaces old §5.2 |
| 12 | §5.3 Limitations | Expand: explicit practical range with the real-network measured boundary; depth-limited hybrid as PROPOSED future work (not implemented; imprecision is NOT a scalability fix); DAG-transformation justification updated to the hub-and-spoke direction rationale + cyclic/bidirectional as future work | R2.6, R3.4, R3.3 | ~0.75 page |
| 13 | §6 Conclusions | Rewrite to match: exact + independently verified, no structural advantage over well-ordered exact competitor, distinguishing capability = imprecise propagation, measured practical range | all | ~0.5 page |
| 14 | Editorial | Typo/grammar checklist (observed: "acompute", "The proposed approach present", "compuataional", "cost comes form", duplicated punctuation §5.1.1); caption quality pass | R2.8, t7 | checklist |

## Resolved during scoping
- Grid table: REVIEWER_RESPONSE_map's "must be re-checked" is superseded by GRID_BENCHMARK_CORRECTED.md —
  re-verification CONFIRMS the published table; no numeric changes to it, only the added verification claim.

## Open questions for sign-off
- **Q1** Thesis chapters: should any (Diamond_Decomposition, Network_Model, Input_Module) track the new
  complexity/factorisation or imprecise-probability content? Default: paper only.
- **Q2** §4.4: keep a trimmed implementation section (correcting the unsound-operator description) or fold
  into a short "numerical implementation" note? Correction itself is non-optional.
- **Q3** Old six-Pareto-configuration analysis (§5.2 tables, depth-≤12/16/18 spectrum): fully deleted and
  replaced per the handoff. Confirm deletion is intended — the reviewer response letter must then explain
  the case-study rebuild transparently (inputs not defensibly derived from the source study).
- **Q4** Scope: also draft the point-by-point reviewer response letter (tracker has empty response
  columns), or manuscript proposals only?

## Flags — places where reviewer phrasing asks for more than the planned response gives
- R2 (2nd set) comment 4 literally asks for a hybrid approximate/exact scheme; plan responds with a
  discussion + proposed (unimplemented) depth-limited hybrid, honestly labelled future work.
- R2 (2nd set) comment 1 asks to "mathematically justify how IPA improves" on cutset conditioning /
  junction trees; the honest answer is specialisation + factorisation refinement within the same
  complexity class, with the genuine novelty shifted to imprecise propagation. Response must own this.
- R3.3 (bidirectional multiplex): the rebuilt case study changes the DAG-direction rule (hub-tier
  ordering per the source's own hub-and-spoke model, replacing the indefensible latitude sort) — the
  response letter must disclose this change, not present it as having always been the case.
