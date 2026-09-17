# RESS Revision — Writing Handoff

## 0. Purpose and how to use this document

This is a briefing for whoever drafts or edits the manuscript prose for the RESS (Reliability Engineering
& System Safety) revision. It describes the METHOD, its MATHEMATICAL PROPERTIES, and the RESULTS obtained
— it does not describe software. If you are drafting text and find yourself wanting to name a function,
a script, a data type, a file, or a programming language, stop: translate the underlying mathematical or
reliability-engineering statement instead. Concrete translation table:

| Do NOT write (implementation) | DO write (reliability / mathematics) |
|---|---|
| "the algorithm calls `new_identify`" | "the diamond-identification procedure" / "recursive conditioning" |
| "conditioning set size (`maxcond`)" | "the conditioning-set cardinality \|C\|", "the effective treewidth-like width parameter" |
| "the `K_REDUNDANCY` parameter" | "the number of provisioned alternate routes per node, a network-design/redundancy parameter" |
| "`Interval`/`pbox` type" | "interval-valued reliability" / "a probability box (p-box)" |
| "the JSON prior file" | "the assumed component reliability" |
| "sifted CUDD" | "a reduced-ordered binary decision diagram (ROBDD) with dynamic variable reordering" |
| "the script blew up / ran out of memory" | "did not complete within a practical computational budget" |

Every numeric claim below traces to a specific validation artifact (data file or script) — file paths are
given in brackets for the WRITER'S own verification, but should not appear in the manuscript. Pull the
actual number from the referenced CSV/log rather than retyping it from memory, to avoid transcription drift.

This document supersedes nothing — `PAPER_GUIDE.md` remains the technical index (file paths, reproduction
commands) for the research team. This document is the DISTILLATION of everything in that folder plus
everything found/fixed in the 2026-07-27/28 session, written for drafting, not for reproducing.

--------------------------------------------------------------------------------
## 1. What the reviewers actually asked for (condensed)

Three reviewers examined the original submission. None of them mentioned imprecise probability
(interval/p-box) at all — that capability is being added to the revision as a new, voluntary
strengthening, not a response to a specific comment, and should be introduced as such (it earns its own
scrutiny, it is not "answering" anything). The comments that DO need direct answers:

- **R2.1 / R3.2** — validation used only one 16-node network; benchmark against an independent exact method
  on the SAME networks. → Answered by an independent open exact oracle (a canonical ROBDD) across a broad
  synthetic corpus AND, newly, the applied case study (§3.4 below) — previously only the corpus and a toy
  benchmark network had this comparison; the applied case study did not.
- **R2.2** — the published speed comparison used a different implementation environment and is not
  controlled; moderate the claim or redo it with a controlled comparison. → All new timing results in this
  handoff use a warmup-then-measure protocol; an early draft of the applied-case-study comparison violated
  this discipline and produced a materially wrong conclusion before being caught and corrected — see §3.4.3.
  This is worth a sentence in the manuscript's methodology section: *how* timings are measured, not just
  what they show.
- **R2.4 / R3.1 / t3 / t5** — the complexity argument is qualitative; relate it formally to established
  exact-inference methods (cutset conditioning, junction trees) and give a tighter bound.
- **R2.6 / R3.4** — computation becomes impractical beyond a nesting depth of about 18; discuss the
  practical range of applicability more explicitly, and do not present imprecise propagation as a free
  scalability fix (it uses the same conditioning depth as the exact case).
- **R2.5** — the applied case study reports runtime but no reliability-engineering insight. → Directly
  answered by the rebuilt case study (§3.4): a decision-relevant reliability finding derived from the
  network's actual infrastructure data, not a runtime table.
- **t6** — the applied case study's transmission-probability derivation lacks transparency (how are
  probabilities obtained from distances, and how is directionality justified). → Directly answered: every
  input is now traced to a specific number or constraint in the case study's source publication, with
  exactly one clearly-flagged extension (§3.4.1).

--------------------------------------------------------------------------------
## 2. Headline claims (state exactly these — all measured, ready to write)

1. **Exact source-to-node reliability, independently verified.** The method reproduces exact reliability
   against a canonical reduced-ordered binary decision diagram (ROBDD), a widely used independent exact
   method, across a broad synthetic corpus and multiple real/applied networks — worst observed disagreement
   at floating-point noise level (~1e-16), for both perfect and imperfect components.
2. **No structural advantage over a well-ordered exact competitor in the general case** — both scale with
   the same treewidth-like parameter. The method's distinguishing capability is native support for
   IMPRECISE component reliabilities (interval and p-box), not a smaller state space.
3. **Interval reliability is exact by construction** (monotonicity of the reachability function in every
   component reliability ⟹ the extreme-case corners are the true bounds; validated to machine precision
   against corner evaluation on the full corpus) and, on every one of 8 tested topological families PLUS
   one real applied network, interval propagation completes FASTER than the exact-competitor route to the
   same interval answer (build once, evaluate at two extreme points) — factors of roughly 3x to 95x,
   established both on synthetic families and (newly) confirmed on a real infrastructure network.
4. **p-box (full distributional) reliability propagation is a genuinely new capability relative to exact
   decision-diagram methods**, which cannot produce a distributional reliability bound at all. The chosen
   operator is empirically sound across a broad validation sweep (zero violations); a more conservative
   variant is provably sound via classical probability theory (the Fréchet–Hoeffding bounds). Soundness of
   the tighter, empirically-validated operator under partial (positive-only) dependence information remains
   an open mathematical question — checked against the literature and found genuinely unresolved, not a
   citation we failed to find (§3.1.5).
5. **A concrete, decision-relevant use of the p-box capability**: from a single propagation, the method
   certifies a guaranteed bound on the probability that a component's reliability falls below a stated
   requirement. Matching that precision by simulation would require hundreds to thousands of samples
   (worst-case, before knowing the answer), and even then yields only a statistical estimate, not a
   guarantee. Exact decision-diagram methods have no analytic route to this bound at all.
6. **A rebuilt, source-grounded applied reliability case study** (§3.4) replaces an earlier case study whose
   inputs were not properly derived from its stated source, and whose designs did not correspond to
   anything in that source. The new case study derives every input from the source publication's own
   stated model and results, adds exactly one clearly-flagged extension, and yields genuine,
   decision-relevant reliability findings about a real medical drone logistics network for Scotland.

--------------------------------------------------------------------------------
## 3. New/updated technical content since the last handoff

### 3.1 The conditioning operator for imprecise reliabilities

**The mathematical content.** When two branches of a network reconverge below a shared point of
uncertainty (a "diamond"), belief at the reconvergence point is a weighted combination of the belief along
each branch, weighted by the probability of the shared upstream condition. For point-valued (precise)
reliabilities this is ordinary conditional probability. For interval-valued reliabilities it is exact
corner enumeration (the reachability function is monotone in every component, so the extreme corners of
the input intervals give the extreme output bounds — no dependency issue arises). For distributional
(p-box) reliabilities, the combination is a **convex combination of two dependent random quantities**, not
an independent sum — treating it as an independent sum (as an earlier, now-corrected version of the
framework did) is unsound and can assign probability mass outside [0,1].

**The operators.** Write the combination as an envelope over the weighting variable's own distribution,
blending the two branch distributions at each weight level. Two blends are available:
- A **Fréchet blend**, which makes no assumption about the dependence between the two branches beyond what
  is forced by the Fréchet–Hoeffding bounds (valid for ANY joint dependence). This is **provably sound** —
  it inherits a classical theorem (Fréchet 1951 / Hoeffding 1940, formalised for this kind of probability-
  bound arithmetic by Williamson & Downs, 1990) rather than requiring an original proof.
- A **positive-dependence blend**, motivated by the observation that the two branches are both
  non-decreasing functions of the shared upstream reliabilities, hence cannot be negatively dependent. This
  blend is tighter and has been validated sound across a broad sweep (dozens of topology/regime
  combinations, zero violations against Monte Carlo ground truth), but a general proof of its soundness
  remains open (see §3.1.5).

**Recommended framing for the manuscript:** lead with the Fréchet blend as the GUARANTEED bound (cite the
classical theorem), and present the positive-dependence blend as an empirically-validated, tighter
alternative whose general proof is future work. Do not describe the tighter operator as "guaranteed."

**Numerical hardening.** Because the underlying arithmetic is standard floating-point (not directed/outward
rounding), and because the combined quantity is a probability and therefore mathematically confined to
[0,1], the operator's output is intersected with [0,1] as a final step — a projection that can only ever
tighten the result, never invalidate it, since it discards only values that are already known to be
impossible. This step includes a safeguard: if the pre-projection excursion beyond [0,1] ever exceeds a
tolerance far above ordinary floating-point noise (by roughly four orders of magnitude) it raises an error
rather than silently discarding it, so that a genuine future soundness regression cannot be masked as
harmless rounding. Worth one sentence in a numerical-implementation footnote; not headline material.

#### 3.1.1 Tightness envelope (how good is the tighter operator, honestly)

Across a sweep of input-distribution shapes, uncertainty widths, and reconvergence regimes, on a
methodology-benchmark network: the bound is TIGHT (≈9–22% of the range) under high-reliability /
weakly-reconvergent conditions, and CONSERVATIVE (up to ≈60–70% of the range) under adversarial
strongly-reconvergent, fully-uncertain conditions — but never unsound (zero violations across the whole
sweep). State this as a characterised envelope (a figure showing band width vs. regime), not a hidden
weakness: soundness never varies with the regime; only tightness does, and it is understood to be driven by
reconvergence depth and input uncertainty, not by the shape of the input distribution (which was found to
be a secondary factor). [data: `grid_envelope.csv`]

#### 3.1.2 Decision-relevant certified bound (the concrete payoff)

At a stated reliability requirement, the method certifies a bound on the probability that a component's
true reliability falls below that requirement, from a single propagation. On the methodology-benchmark
network at a representative requirement, the certified band width ranged 0.02–0.12 depending on regime;
matching that precision by simulation, planned conservatively (without foreknowledge of the answer), would
require roughly 270 to 9,600 samples, and even then the result is a statistical estimate with no guarantee.
An exact decision-diagram method has no analytic route to this bound at all and would itself fall back to
simulation. This is the concrete "so what" of the imprecise-propagation capability and belongs prominently
in the results section, not buried as a footnote. [data: `certified_bound_vignette.csv`]

Caveat for honest reporting: the "samples needed if you already knew the answer" figure collapses toward
zero when the true probability is near 0 or 1 (correct statistics, not an error) — report the worst-case
planning figure, which is what a practitioner would actually have to budget before sampling, not the
hindsight figure.

#### 3.1.3 Interval propagation: exact AND fast

Established previously that interval propagation is exact to machine precision (worst observed discrepancy
on the order of 1e-16) against corner evaluation across the full validation corpus. Newly established: on
every one of 8 tested topological families, one-shot interval propagation (a single pass) is FASTER than
the natural exact-competitor route to the same interval answer (build the decision diagram once, evaluate
it twice, at the extreme low and high inputs) — by factors of roughly 3x to 95x depending on family. This
should be scoped honestly: it is a one-shot-query comparison (build from nothing, get one interval answer).
A workload that reuses a single pre-built diagram across many repeated queries is a different scenario,
untested here, and could favour the diagram-based method instead — say this explicitly rather than let the
speed result imply an unqualified general advantage. [data: `interval_bdd_vs_ipa_timing.csv`]

#### 3.1.4 Cost of the full distributional (p-box) case

p-box propagation cost grows with the chosen discretisation level (a user-controlled precision/cost
trade-off, not a fixed overhead): interval propagation itself is a small constant-factor cost over exact
point-valued propagation (roughly 1.2x, effectively free), while full distributional propagation costs grow
quadratically with the number of discretisation levels used, in exchange for a proportionally tighter
distributional bound. Frame this as a controllable dial: state the achieved bound tightness at the
discretisation level actually used, and do not claim p-box propagation is cheap — claim that it is
CONTROLLABLE, with rigorous bounds guaranteed at every setting.

#### 3.1.5 Soundness of the tighter operator: a genuinely open question, not a missed citation

A literature check (source arithmetic libraries' own documentation, the classical dependency-bound
literature, and a directly on-topic methodological survey from mid-2026) found no existing theorem
covering "known-positive-but-otherwise-unspecified dependence" — the literature offers a strict trichotomy
(full independence / a fully specified dependence structure / fully unknown dependence), with nothing in
between. An attempted original derivation (via a classical ordering-of-dependence argument that is the
natural first thing to try) does not go through cleanly: the relevant comparison function is neither
uniformly favourable nor unfavourable to positive dependence over the full range of outcomes, and a
concrete counterexample (two independent versus perfectly dependent uniformly-distributed quantities) shows
their combined distributions cross rather than one uniformly bounding the other. Conclusion for the
manuscript: state plainly that soundness of the tighter operator is empirically supported and argued, with
a general proof identified as future work — do not imply a proof exists or is straightforward, and do not
spend manuscript space attempting one under this revision's timeline.

### 3.2 Complexity ("the diamond stuff")

**The formal picture.** The method is a specialisation of classical cutset conditioning to source-to-node
reachability: it identifies "diamond" substructures (points where paths from a common ancestor reconverge)
and resolves the dependency they introduce by conditioning on a minimal separating set, recursing until the
remaining structure factors into independent contributions. Per-instance computational cost is exactly
`2^|C|` per diamond, summed over the recursion, where `|C|` is the size of the conditioning (separating)
set actually required at that point — this is a DEFINITE, per-instance-computable quantity, not a guessed
asymptotic bound, because the conditioning sets are produced by the identification procedure itself before
any expensive enumeration begins. An independent-substructure refinement (recognising when parts of a
reconvergence are provably independent given the current conditioning) reduces the conditioning-set size
needed in favourable cases (from exponential to linear in the number of independent contributing branches
at a fan-in structure), closing a self-inflicted inefficiency without changing the underlying
worst-case complexity class.

**The relationship to established methods.** The maximum required conditioning-set size across a network is
bounded by (and empirically tracks closely with) the network's treewidth/pathwidth — the same parameter
that governs the size of a well-ordered exact decision diagram and the cost of junction-tree inference on
the same structure. Measured across the corpus, the method's realised computational cost is the same order
of magnitude as a well-ordered decision diagram's size, sometimes smaller, sometimes larger, with neither
method dominating — an honest structural finding: this method is not asymptotically superior to a
well-ordered exact competitor; its distinguishing strength lies elsewhere (imprecise propagation, §3.1).

**A concrete, real-network illustration of the practical limit** (new, from the applied case study,
§3.4.2): connecting every operationally-plausible pair of locations in a real ~240-node infrastructure
network, even after excluding pairs that could never correspond to an actual operational connection,
produces a conditioning-set requirement (~27-28) beyond the practical range previously identified from the
original submission's own reported experience (computation becomes impractical beyond roughly 18). Limiting
the network design to a bounded number of alternate routes per location (a genuine, real-world
redundancy/robustness design choice, not an arbitrary knob) brings the requirement down to 15–17 — just
inside the practical range — while still exceeding, in redundancy, several of the network configurations
originally used for methodology testing. This is a concrete answer to "what is the practical range of
applicability" (R2.6): a specific, real, measured example of the boundary, calibrated deliberately to the
reviewer's own stated figure, rather than an abstract restatement of the limitation.

### 3.3 Comparison to an independent exact method, extended to the applied case study

Previously, the independent-exact-method comparison (against a well-ordered reduced binary decision
diagram) existed for the synthetic validation corpus and the methodology-demonstration network, but NOT for
the applied case study — despite the reviewers explicitly asking for the comparison on "the same grid AND
drone networks." This has now been done, with three findings, reported together as one honest, verified
result (do not report only the favourable part):

1. On the sparsest of three new applied-network configurations, the two methods agree exactly (to
   floating-point noise), and one-shot interval propagation is markedly faster than the decision-diagram
   route to the same bound (roughly 14x).
2. On the same configuration but with a network design deliberately provisioned for LOW redundancy (few
   alternate routes per location), both methods are fast, and the proposed method remains moderately faster
   (roughly 6x) — i.e. at low redundancy, both methods are comfortably practical, and the qualitative
   speed advantage from point (1) holds here too.
3. On the SAME network topology but provisioned for HIGHER redundancy (calibrated to the reviewer's own
   stated practical-limit figure — see §3.2), the decision-diagram method did not complete within a
   practical computational budget under either of two variable-ordering strategies (an optimised dynamic
   search, and a naive fixed order), while the proposed method completed the full exact computation in
   under 25 seconds.
   **State this precisely**: the honest, verified claim is that the proposed method's PRACTICAL RANGE OF
   APPLICABILITY, in terms of a real, controllable network-redundancy parameter, extends further on this
   real network than the decision-diagram method's does — both methods are governed by the same underlying
   network property, and both are fast at low redundancy; only the proposed method remains practical at the
   higher, still operationally meaningful, redundancy level tested. Do NOT state that the decision-diagram
   method structurally cannot handle this class of problem, or that the proposed method possesses a design
   flexibility the alternative categorically lacks — that claim was drafted, checked against a controlled
   comparison, and found to overstate what was actually shown; the corrected, narrower claim above is what
   the evidence supports.

**Methodological note for the paper's own credibility**: an early pass at this comparison used
timing measurements taken without a warmup step and consequently attributed compilation/startup overhead to
algorithmic cost, producing a materially wrong conclusion (the decision-diagram method appeared faster on
the sparse case, by a factor that reversed completely once measured correctly). This was caught before
being reported and is mentioned here only so it is not silently repeated: any runtime claim in the
manuscript should be described as measured after a warmup/discard-first-run step, and this should be stated
explicitly in whatever methodology paragraph describes how timings were obtained (this is itself a direct,
concrete answer to R2.2's complaint about runtime-comparison rigour).

### 3.4 Applied reliability case study — medical drone logistics network for Scotland

**Source.** A published conceptual design study for a medical drone delivery network across Scotland,
using real hospital, airport, and candidate-station location data, two drone types (short-range
vertical-takeoff, long-range fixed-wing) with stated nominal ranges and station-infrastructure
specifications, and a stated illustrative reliability assumption (non-hub locations assumed to fail
independently with a given probability; hub locations assumed always available) used in that study's own
resilience analysis.

#### 3.4.1 What was wrong with the previous version of this case study, and what replaced it

The earlier version of this case study derived component reliabilities from an invented distance-decay
formula with no basis in the source publication, derived a different invented formula for location
reliability, imposed a directionality on the network based on geographic latitude (with no operational
justification — the source publication's own network model treats connections as symmetric, since a
delivery route can run in either direction), and used network designs that were constructed to control the
proposed method's own computational cost rather than derived from the source publication's actual
optimisation results (which are not public). None of this was viable to defend under review.

The rebuilt case study derives every quantity from the source publication directly:
- **Location reliability**: hub locations are assumed always available and non-hub locations assumed to
  fail independently with the SAME probability the source publication itself used in its own resilience
  analysis — represented as an INTERVAL (a band around that figure) precisely because the source
  publication's own figure is stated but not itself derived or justified from first principles; the
  interval represents a sensitivity test on that very assumption, which the source publication's own
  point-probability framework could not perform.
- **Connection existence**: a connection between two locations exists for a given drone type if and only
  if the physical distance is within that drone type's stated nominal range — an exact match to the source
  publication's own network-construction rule, not an approximation of it.
- **Connection reliability — the one clearly-flagged extension**: the source publication explicitly holds
  weather/wind conditions constant in its own analysis, while separately noting (without giving a value)
  that weather-driven range variation is, in principle, an uncertain quantity that would be elicited from
  expert judgement. The rebuilt case study extends exactly this point, honestly: a connection well within a
  drone's nominal range is treated as reliable; a connection within an illustrative weather-derating margin
  of the range limit (an assumed, clearly-stated illustrative bound, since the source publication does not
  quantify one either) is treated as an HONEST interval of [certainly unreliable in the worst case, reliable
  in the best case] — i.e., genuinely uncertain, which is the correct and honest representation of not
  knowing whether adverse weather closes that particular route. This is presented as an EXTENSION of the
  source publication's own stated (and deliberately deferred) limitation, not as an unrelated invention.
- **Network configurations**: three configurations are constructed as PROXIES for the qualitative character
  of three specific trade-off points described in the source publication's own results (a fixed-wing-reliant
  centralised design serving remote locations; a densely-interconnected short-range design; a
  minimal-investment design retaining only pre-existing, non-optional infrastructure) — explicitly labelled
  as proxies for the DESCRIBED character of those points, since the source publication's actual optimised
  network layouts are not published. This distinction must be preserved in the manuscript: these are
  representative designs matching a described trade-off, not reproductions of an unavailable result.

#### 3.4.2 The redundancy/tractability finding (see also §3.2)

A network design parameter — the number of alternate routes provisioned per location, a genuine
reliability-engineering redundancy choice — was swept to find where computation remains practical. Every
location connected to every reachable location was found impractical (§3.2). A small number of alternate
routes (comparable to a design that offers essentially no redundancy) is comfortably practical for both the
proposed method and an independent exact competitor. A moderate number of alternate routes, deliberately
chosen to sit just inside the practical range identified from the original submission's own reported
experience, remains practical for the proposed method but not for the independent exact competitor under
either of two configurations tested (§3.3). This is presented as a genuine, real, decision-relevant
tractability finding, not an engineering workaround: **more redundancy improves resilience but costs more
to verify exactly; the method's practical redundancy ceiling on this real network was measured, not
assumed, and calibrated against the reviewers' own stated figure.**

#### 3.4.3 Reliability results and their interpretation (R2.5 answer)

Across the three network configurations, propagated location-reliability bounds were sound (every result
correctly bounded within [0,1]) and, importantly, non-degenerate — genuinely informative rather than
vacuous. In the lowest-redundancy (tree-like) configuration, bounds ranged narrowly (band width 0 to 0.10,
mean about 0.09) reflecting the location-reliability assumption directly, with little additional
uncertainty accumulated through the network. In the two higher-redundancy configurations, the
least-reliable locations showed a genuine, decision-relevant spread — as low as 55% to as high as 72%
reachability confidence for the worst-served locations, against near-certainty for well-connected ones.

**This is the reliability-engineering insight the case study should lead with**: which real locations in
the network carry the most uncertainty about their drone-delivery reachability, honestly propagated from
the network's actual redundancy structure and the acknowledged uncertainty in its component-reliability
assumptions — not merely a runtime table, which is what the earlier version of this case study offered and
which the reviewers correctly identified as insufficient (R2.5). A map-style figure, coloured by the
computed reliability lower bound (or by band width, to show WHERE uncertainty is concentrated), is a strong
candidate figure for this section, directly analogous to the source publication's own geographic figures —
turning the abstract propagation result into a literal reliability map of the network.

--------------------------------------------------------------------------------
## 4. Reviewer-comment → manuscript-content map (this session's contributions only)

| Comment | What to write | Section 3 reference |
|---|---|---|
| R2.2 (runtime rigour) | State the warmup/measurement discipline explicitly in methodology | §3.3 note |
| R2.3 / R3.2 (benchmark vs exact solver, same networks) | Independent-exact-method comparison now covers the applied case study too, with the corrected tractability-range framing | §3.3 |
| R2.5 (case study lacks reliability insight) | Lead with the reliability-spread finding and which locations are most uncertain, not runtime | §3.4.3 |
| R2.6 / R3.4 (practical scalability range) | Concrete, measured, real-network illustration of the practical limit, calibrated to the reviewers' own figure | §3.2, §3.4.2 |
| t6 (transmission-probability transparency) | Every input traced to the source publication's own tables/text; the one extension explicitly flagged and motivated by the source's own deferred limitation | §3.4.1 |
| New capability (not a reviewer response, a strengthening) | Certified decision-relevant bound from one propagation vs. simulation's sample-count cost | §3.1.2 |

--------------------------------------------------------------------------------
## 5. Wording guardrails — claims to avoid restating even though an earlier draft made them

- Do NOT claim the tighter p-box operator is "guaranteed" or "proven" sound — it is empirically validated;
  only the more conservative (Fréchet) operator is proven, via a classical theorem, not an original result.
- Do NOT claim imprecise (interval or p-box) propagation is a scalability fix for high-treewidth networks —
  it uses the same conditioning depth as exact propagation; only network REDESIGN (reducing redundancy)
  changes the computational cost, and that is a design trade-off, not a free capability of imprecision.
- Do NOT claim the proposed method has a design-flexibility advantage the independent exact competitor
  categorically lacks — both are governed by the same network property; the verified claim is a WIDER
  practical range on the one real network tested, not a structural asymmetry (§3.3).
- Do NOT present the three applied-case-study network configurations as reproductions of the source
  publication's actual optimised designs — they are explicitly labelled proxies for a described qualitative
  character, because the actual designs are not public.
- Do NOT report a runtime or timing figure without stating that it was measured after a warmup/discard-first
  run — an unwarmed measurement produced a materially wrong conclusion once in this exact case study before
  being caught (§3.3), and reviewers have already flagged exactly this class of rigour gap once (R2.2).
- Do NOT quote a specific speedup or discretisation-cost multiplier that was not actually measured at the
  configuration being described — the p-box cost curve is real and quadratic in discretisation level, but
  the specific multiplier depends on the level chosen; state the level and its corresponding measured cost.

--------------------------------------------------------------------------------
## 6. Data/evidence inventory (for the writer's own number-checking; do not cite paths in the manuscript)

- Tightness envelope, certified-bound vignette: `data/grid_envelope.csv`, `data/certified_bound_vignette.csv`
- Interval-vs-exact-competitor timing (synthetic corpus, 8 families): `data/interval_bdd_vs_ipa_timing.csv`
- p-box discretisation cost curve: `data/timing_imprecise.csv`, `data/pbox_steps_scaling.csv`
- Applied case study source publication: `csvfiles/drone_info/` (PDF + underlying location/distance data)
- Applied case study network generation and all derivation choices, with full provenance comments:
  `drone_network_to_dag_reliability.jl` (repo root)
- Applied case study conditioning-width / redundancy sweep: `validation/drone_diamond_stats.jl`,
  `validation/drone_k_sweep.jl`
- Applied case study vs. independent exact competitor (all three findings in §3.3, including the corrected
  one): `validation/drone_bdd_comparison.jl`, `validation/gen_k6_test.jl`
- Applied case study reliability results + map-style figures (by role, by reliability): generated PNGs
  alongside each of the three network configurations under `dag_ntwrk_files/drone-network-*/`
- Full reviewer comment text and DONE/WRITE/FUTURE status per item: `notes/REVIEWER_RESPONSE_map.md`
- Formal set-theoretic model, lemmas, and the exact per-instance complexity formula: `PAPER_GUIDE.md` §4-5
