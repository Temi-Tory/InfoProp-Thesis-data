# Literature verification log (2026-08-10)

Purpose: before any of these citations go into Related Work or the manuscript, verify what the
source actually claims/does rather than trusting the one-line description that motivated adding it.
Two of six were explicitly flagged by the author as needing web-search confirmation; one (credal
networks/2U) was flagged as needing an actual read, not just an abstract skim. Status below.

## 1. Williamson & Downs 1990 — CONFIRMED, already correctly cited

Full citation: Williamson, R.C., Downs, T. (1990). "Probabilistic arithmetic I: Numerical methods
for calculating convolutions and dependency bounds." *International Journal of Approximate
Reasoning*, 4(2), 89–158.

Confirmed via Semantic Scholar / ScienceDirect abstract: this is exactly the paper that formalises
Fréchet-bound-based dependency bounds (the bounds valid for *any* joint dependence between two
random quantities) as a computational procedure — i.e. the correct foundational citation for the
`cvxF` operator. `RESS_WRITING_HANDOFF.md` already cites this correctly (line 114: "formalised for
this kind of probability-bound arithmetic by Williamson & Downs, 1990"). No change needed — just
confirmed, not previously verified against the actual paper.

## 2. Credal networks / 2U (Fagiuoli & Zaffalon) — CONFIRMED by direct read, claim is defensible AND strengthened

Full citations, now both in hand as PDFs (user-supplied):
- Fagiuoli, E., Zaffalon, M. (1998). "2U: An exact interval propagation algorithm for polytrees with
  binary variables." *Artificial Intelligence*, 106(1), 77–107. [Referenced as [16] below.]
- Mauá, D.D., Cozman, F.G. (2020). "Thirty years of credal networks: Specification, algorithms and
  complexity." *International Journal of Approximate Reasoning*, 126, 133–157. **Read directly in
  full** (Sections 1, 3, 5.3, 6.1, 6.2, 7) — this is the "actually read the paper" pass the credal
  networks claim needed.

**Exact quotes from Mauá & Cozman 2020, Section 6.2 (p.149–150), verbatim:**
- "The basic result is that, if we impose no restriction on the input credal network, [deciding
  whether upper probability of a query exceeds a threshold] is **NP^PP-complete** [86]."
- "...if every credal set is a singleton and the DAG is a polytree, then deciding marginal inference
  is in P. But we also know **the 2U algorithm takes polynomial time to compute an inference for a
  credal network over binary variables whose DAG is a polytree** [16]."
- "Can we remove the restriction on binary variables and stay within P? **No: when the DAG is
  already a tree, marginal inference is NP-hard when variables have more than two values** [91,92]!"
- "**When the input credal network is assumed to have bounded treewidth, then deciding marginal
  inference is still NP-hard** [69]." A fully-polynomial approximation scheme (not exact) exists
  only if *both* treewidth *and* the number of values per variable are bounded [91].

**This is a stronger and more precise finding than the original hypothesis.** The original framing
("2U is exact only for polytrees, diamonds/reconvergence push you to NP^PP") is confirmed, but the
bounded-treewidth result is the more interesting one: for classical (precise) Bayesian networks,
bounded treewidth guarantees polynomial *exact* inference (junction tree). **For credal networks,
that guarantee breaks** — bounded treewidth alone is still NP-hard once credal sets replace point
probabilities; only an *approximation* scheme is available, and only with a second restriction
(bounded value-count) on top.

**Defensible claim for the paper (revised, stronger):** IPA's cost is governed by an analogous width
parameter — conditioning-set size across resolved diamonds — yet IPA remains *exact* (not an
approximation scheme) at that cost. This is not a generic consequence of "bounded width ⟹
tractable": the credal-network literature's own complexity results (Mauá & Cozman 2020) show that
guarantee does *not* survive the move from point probabilities to imprecise (interval/p-box) ones —
bounded-treewidth credal-net inference is still NP-hard, and even the tractable relaxation is
approximate, not exact. IPA's width-governed *exact* result should therefore be framed as following
from the specific structure of interval/p-box arithmetic operators and explicit diamond conditioning
— not asserted as something "obviously" available once a width parameter is bounded.

**Caveat to keep in the writing:** IPA propagates interval/p-box valued edge/node reliabilities on a
DAG; credal networks are sets of joint distributions over discrete random variables with graphical
structure. Related but not identical problem classes — word this as an analogous tractability
boundary, not a literal restatement of the same problem.

## 3. Feng et al. 2016 — CONFIRMED, but the finding REVERSES the hypothesis being tested

Full citation: Feng, G., Patelli, E., Beer, M., Coolen, F.P.A. (2016). "Imprecise system reliability
and component importance based on survival signature." *Reliability Engineering & System Safety*,
150, 116–125.

**The question was:** does this paper deliver analytic (non-simulated) p-box bounds, or does it rely
on simulation/percolation approximation of the survival signature? This mattered because "IPA
produces bounds a competitor can only get via simulation" was flagged as the paper's strongest and
most testable claim.

**Verified directly** (read the actual introduction/results text of a citing companion paper,
Patelli, Feng, Coolen, Coolen-Maturi 2017, "Simulation Methods for System Reliability Using the
Survival Signature," RESS — open-access PDF via Strathprints, read in full):
- "Feng et al. [9] developed an **analytical method** to calculate the survival function of systems
  with uncertainty about parameters of assumed component failure time distributions."
- Later: "The results are then compared to **the analytical solution** adopting the method presented
  in [9]" — used repeatedly as ground truth to validate a *separate* Monte-Carlo simulation method.

**So: Feng et al. 2016's bounds are analytic, not simulated.** The original hypothesis was wrong —
good that this got checked before it went in the paper, since a reviewer with survival-signature
background would catch a blanket "cannot produce analytically" claim immediately.

**What IS still true and defensible**, per the same 2017 paper's own stated limitations:
- Feng et al.'s method requires grouping components into **exchangeable types** (iid failure times
  within a type) — a structural precondition IPA does not need.
- Computing the survival signature **itself** (as opposed to propagating bounds given it) is
  acknowledged in the 2017 paper as a genuinely separate, harder problem: "[computing the survival
  signature] can already be done for quite substantial systems using the approach proposed in [10,
  34] **but which remains also a topic for research**" for very large systems. [10] = Reed (2017),
  a BDD-based exact survival-signature computation method — i.e. even the "exact" side of this
  literature reaches for BDD-style structure exploitation once systems get large, same tool family
  IPA is being compared against elsewhere in the paper.

**Defensible claim for the paper:** replace any "simulation vs analytic" framing for Feng et al. 2016
specifically. Correct differentiation: survival-signature bound propagation is analytic given the
signature, but (a) requires component-type exchangeability IPA doesn't need, and (b) computing the
signature itself for general/large/non-repeating topologies is a separate, actively-researched
computational problem, distinct from and orthogonal to the bound-propagation step. IPA propagates
directly on the DAG's own structure in one pass with no signature-construction step.

## 4. Behrensdorf et al. — CONFIRMED, and correctly the "simulation-based" comparison point

Full citation: Behrensdorf, J., Broggi, M., Beer, M. (2019). "Reliability Analysis of Networks
Interconnected with Copulas." *ASCE-ASME Journal of Risk and Uncertainty in Engineering Systems,
Part B: Mechanical Engineering*. Tested on the IEEE Reliability Test System (RTS).

Confirmed via search: models dependency between network components using vine copulas, uncertainty
via p-boxes/imprecise copulas, and — explicitly — **Monte Carlo simulation** combined with the
survival signature to get network reliability bounds. This one genuinely is simulation-based, unlike
Feng et al. 2016. Useful as the actual "our competitor needs simulation" comparison point instead of
Feng et al. 2016.

**Resulting three-way related-work structure (recommended):**
1. Feng et al. 2016 — analytic bound propagation, given the survival signature; requires
   type-exchangeable components; signature computation itself is a separate hard problem for large/
   general topologies.
2. Behrensdorf et al. 2019 — Monte Carlo simulation + survival signature + vine copulas, for
   general/dependent network topologies (this is the "needs simulation" comparator).
3. IPA — single-pass analytic p-box propagation directly on arbitrary DAG structure, no signature
   precomputation, no type-exchangeability requirement, cost governed by conditioning-set width.

## 5. Jacob, Dubois & Cardoso 2011 — CONFIRMED REAL (web search had failed to surface it; found via a citing paper)

Full citation, recovered from the reference list of a citing paper (below): Jacob, C., Dubois, D.,
Cardoso, J. (2011). "Uncertainty Handling in Quantitative BDD-Based Fault-Tree Analysis by Interval
Computation." Springer Berlin Heidelberg, pp. 205–218. (Page range/venue style is consistent with
the SUM 2011 proceedings you named, though I have not independently confirmed the exact
conference — worth a quick DBLP check before the manuscript locks the venue name.) My earlier
web-search attempt failed only because I searched on "interval-valued BDD reliability," not the
paper's actual title (fault-tree analysis, not general reliability).

**Found and read via a citing paper**, user-supplied: Imakhlaf, A.J., Hou, Y., Sallak, M. (2017).
"Evaluation of the reliability of non-coherent systems using Binary Decision Diagrams." *IFAC
PapersOnLine*, 50(1), 12243–12248. Read in full (all 6 pages).

**What Jacob et al. 2011 actually does**, per this citing paper's characterization (p.12243): "the
authors proposed an approach based on interval computation methods in BDD-fault tree analysis,
relying on the analysis of the structure and monotonicity of the Boolean formula. **However, this
method needs to check the monotonicity of the variables in the structure function that can make it
inapplicable to very large systems.**"

This is directly useful and precisely analogous to IPA's own interval method (which also relies on
monotonicity of the reachability function for corner enumeration). **Defensible claim:**
interval-valued BDD-based fault-tree/reliability analysis already exists (Jacob, Dubois & Cardoso
2011) and — like IPA's interval mode — exploits monotonicity; its own follow-up literature
characterizes it as not scaling to very large systems due to the monotonicity-checking cost. Do not
claim "BDD cannot do interval at all" — it can, with this caveat.

**The citing paper itself (Imakhlaf, Hou & Sallak 2017) is also a good, real, freely-available
related-work entry in its own right**: it extends interval/imprecise BDD reliability to
**non-coherent** systems via Dempster-Shafer belief-function bounds (bel/pl) on BDD paths. Two
self-reported limitations from their own conclusion (p.12248), read directly:
- "the exact solution cannot be obtained for systems with large number of components because it is
  **NP-hard**" — same fundamental BDD-size blowup as ever, now compounded by belief-function
  bookkeeping.
- Their intervals are **variable-ordering-dependent**: their own 3-component case study (Fig. 5–7)
  required checking multiple/all 3! orderings and conservatively taking the widest resulting
  interval to guarantee the exact solution was contained — an ordering-search burden IPA's
  propagation does not have.

**Recommended related-work framing:** BDD-based interval and imprecise reliability analysis is an
active, real line of work (Jacob, Dubois & Cardoso 2011 for coherent/monotone systems via interval
computation; Imakhlaf, Hou & Sallak 2017 extending to non-coherent systems via belief functions).
Both self-report the same two costs IPA avoids: (i) monotonicity/structure-function analysis that
doesn't scale to very large systems, and (ii) ordering-dependent results requiring exploration of
multiple variable orderings and a conservative envelope to guarantee soundness.

## 6. Utkin & Coolen 2007 — CONFIRMED, general survey (background citation only)

Full citation, read directly (intro, pp.261–263): Utkin, L.V., Coolen, F.P.A. (2007). "Imprecise
Reliability: An Introductory Overview." In *Computational Intelligence in Reliability Engineering*,
SCI vol. 40, pp. 261–306. Springer-Verlag.

This is a broad survey/overview chapter, not a specific technique to compare against. It motivates
imprecise reliability generally (incomplete statistical information, unrealistic independence
assumptions, expert-elicited interval judgements, fuzzy reliability theory's shortcomings) and
surveys many approaches at a high level. **Use as a general background/motivation citation** for "why
imprecise reliability matters" in the introduction, not as a technical comparator in the
differentiation paragraphs — it doesn't propose a competing algorithm to contrast against IPA.

## 7. Kozine, Krymsky & Gurov — NOT YET CHECKED

Lower explicit priority in the original request; not verified this pass, and no PDF supplied yet.
Flag before use.

---
## Net effect on manuscript claims

1. **p-box / survival-signature comparison**: the load-bearing "IPA gives you analytically what
   others need simulation for" sentence needs to name Behrensdorf et al. 2019 (Monte Carlo + vine
   copulas + survival signature) as the simulation comparator, not Feng et al. 2016. Feng et al.
   2016 needs a more precise differentiation instead: analytic bound propagation given the survival
   signature, but requiring component-type exchangeability, with signature-construction itself
   remaining an active research problem for large/general topologies (per Feng's own co-authors,
   Patelli et al. 2017).

2. **Credal-networks / 2U comparison** (Interval and p-box sections both): solid, now read directly
   rather than triangulated, and stronger than first thought — lead with the bounded-treewidth
   result (credal nets don't inherit the classical "bounded width ⟹ exact tractable" guarantee;
   IPA's width-governed exactness is not a free consequence of bounding conditioning-set size, it
   follows from the specific interval/p-box arithmetic + explicit diamond conditioning).

3. **Interval / BDD comparison**: new, solid material from Jacob, Dubois & Cardoso 2011 and
   Imakhlaf, Hou & Sallak 2017 — both real, both read directly. Correct any "BDD can't do interval"
   overclaim to the precise version: it can, via monotonicity-based interval computation, but its
   own literature reports it doesn't scale to very large systems and (for the belief-function
   extension) produces ordering-dependent results requiring a multi-ordering conservative envelope.

4. **Still open**: Kozine, Krymsky & Gurov not yet checked (no PDF supplied, lower priority).
   Jacob et al. 2011's exact venue (SUM 2011 vs. another Springer proceedings) worth a quick DBLP
   check before the bibliography locks it in.
