# RESS revision — section-by-section edit proposals

**How to use this document.** Each numbered edit gives: (a) where it goes in `RESS_Paper__New_.docx`,
(b) a quote of the existing passage (abbreviated with `…` — search for the opening words in Word),
(c) the proposed replacement or addition, and (d) a one-line rationale keyed to the reviewer comments.
Proposed text is written in the paper's register and contains no implementation language. Bracketed
notes in *italics* like *[writer note: …]* are instructions to us, not manuscript text — remove them
when applying.

Numbers cited here are taken from the validation artifacts (see `PAPER_GUIDE.md` §6 data inventory),
not from memory. Where a number still needs to be read off an artifact at figure/table-making time,
a *[writer note]* says which one.

**Scope decisions locked with the author (2026-07-28):** paper only (thesis chapters untouched);
§4.4 kept as a trimmed numerical-realisation section; old six-Pareto case study fully replaced;
point-by-point reviewer responses drafted separately (`notes/REVIEWER_RESPONSES_draft.md`).

**APPLIED (2026-07-28, later):** every edit in this document has been applied into a complete compiled
revised manuscript at `latex_revised/main.tex` (+ `main.pdf`, 43 pp., original figures extracted from
the docx plus three new generated figures). The worked example (EDIT 6) now has REAL generated numbers:
the Figure-12 network is `dag_ntwrk_files/test-decomp3s2t` (1:1 edge match); reference-recursion trace
with all-0.9/sources-1.0 gives b(16)=0.80614907, path-enumeration agreement ≤3.4e-16, 68 distinct
sub-problems with reuse vs 145 without (script: scratchpad fig12_trace.jl — copy into validation/ to
keep). Drone stats re-verified from raw inputs: worst node = 195 (Islay Hospital) [0.5620, 0.7224] in
both dense configs; mean widths 0.089/0.093/0.094; all nodes sound. Grid exact beliefs recomputed for
Table 1 (e.g. node 16 = 0.98538853). This markdown remains the edit-by-edit rationale map; the LaTeX is
the applied artifact.

--------------------------------------------------------------------------------
## EDIT 1 — Abstract (full replacement)

**Existing (opening):** "Reliability analysis in directed acyclic process networks requires computing …
achieves a 134-fold reduction in runtime relative to a published message-passing alternative. Analysis of
six Pareto-optimal drone logistics network configurations …"

**Proposed replacement (whole abstract):**

> Reliability analysis in directed acyclic process networks requires computing, for each node, the
> probability that at least one viable path exists from any source node to that node. Standard analytical
> formulations become inaccurate or inefficient in the presence of reconvergent path structures, where
> multiple paths diverge from shared upstream ancestors and reconverge downstream, creating statistical
> dependencies that violate path-independence assumptions.
>
> This paper presents the Information Propagation Algorithm (IPA), an exact message-passing method that
> resolves these dependencies through conditional enumeration on shared fork ancestors. IPA processes the
> network in topological order, identifying reconvergent (diamond) substructures, solving them by
> conditioning on a minimal separating set, and replacing them with statistically equivalent supernodes.
> The method is shown to be a specialisation of cutset conditioning to source-to-node reachability: its
> per-instance cost is exactly determined by the conditioning-set sizes encountered, a width parameter that
> also governs the size of a well-ordered binary decision diagram on the same network. Exactness is
> verified against an independent reduced-ordered binary decision diagram across a corpus of 129 random
> directed acyclic graphs, six topological families, and several real infrastructure networks, with worst
> observed disagreement at floating-point precision. The distinguishing capability of the method is the
> native propagation of imprecise component reliabilities: interval-valued inputs yield the exact
> reliability range, a consequence of the monotonicity of the reachability function, and probability-box
> inputs yield guaranteed distributional bounds through a conditioning operator built on the
> Fréchet–Hoeffding inequalities, enabling certified bounds on decision-relevant probabilities that
> point-valued exact methods cannot produce analytically.
>
> The method is applied to a medical drone logistics network for Scotland in which every input is derived
> from the source design study. Propagated reliability bounds identify the locations whose delivery
> reachability is most uncertain, and a sweep of a network-redundancy design parameter locates the
> practical boundary of exact computation on this real network; within the range tested, the proposed
> method remains practical at a redundancy level at which the decision-diagram alternative did not complete
> within a practical computational budget.

**Rationale:** removes the uncontrolled 134× headline (R2.2), reflects the corpus-wide independent
verification (R2.1/R3.2), foregrounds the imprecise capability (new contribution), and replaces the
six-configuration summary with the rebuilt case study (R2.5, t6).

--------------------------------------------------------------------------------
## EDIT 2 — Highlights (full replacement of the five bullets)

**Existing:** "Exact reliability computation for directed acyclic process networks … Demonstrates that
practical tractability is governed primarily by diamond nesting depth rather than network size"

**Proposed replacement:**

> - Exact source-to-node reliability for directed acyclic networks with reconvergent dependencies,
>   verified to floating-point precision against an independent exact decision-diagram method
> - Formally positioned as a specialisation of cutset conditioning, with per-instance cost determined by
>   the conditioning-set width — the same parameter that governs well-ordered decision diagrams
> - Native propagation of imprecise component reliabilities: exact interval ranges and guaranteed
>   probability-box bounds
> - Certified bounds on decision-relevant reliability probabilities from a single propagation, without
>   simulation
> - Applied case study of a medical drone logistics network for Scotland, locating the practical
>   redundancy boundary of exact analysis

**Rationale:** aligns the advertised contributions with the revised claims (R2.2, R2.4, new capability).

--------------------------------------------------------------------------------
## EDIT 3 — §1 Introduction, contributions paragraph

**Existing:** "The proposed approach present several advantages: it preserves exact reliability computation
… required a fast assessment of the systems."

**Proposed replacement:**

> The proposed approach presents several advantages. First, it preserves exact reliability computation in
> DAGs with reconvergent structures, avoiding the independence errors that arise from standard local update
> rules. Second, by decomposing and caching repeated dependency patterns, it avoids repeated conditional
> enumeration over already-resolved substructures, and its computational cost on a given network is
> determined exactly, before enumeration begins, by the sizes of the conditioning sets its decomposition
> identifies. Third, and distinctively, the propagation scheme extends beyond point-valued component
> reliabilities: interval-valued reliabilities are propagated exactly, and probability-box (p-box)
> reliabilities are propagated with guaranteed bounds, so that epistemic uncertainty about component data
> can be carried through the analysis rather than suppressed into point estimates. These properties make
> the method suitable for design-stage studies in which many network configurations must be assessed, and
> for decision problems in which the reliability inputs themselves are only partially known.

**Rationale:** grammar fix, moderates the "nearly real-time" claim (R2.2/R2.4), introduces the imprecise
capability as a headline contribution.

--------------------------------------------------------------------------------
## EDIT 4 — §1.1 Related Works, two additions

**4a. After the message-passing paragraph** (ends "…approximation quality depends heavily on network
topology and component correlation strength."), **add:**

> In the exact-inference literature on probabilistic graphical models, dependencies induced by shared
> ancestry are classically resolved either by conditioning — cutset conditioning enumerates the states of a
> set of variables whose removal renders the remaining structure singly connected (Pearl 1988) — or by
> clustering, as in the junction-tree algorithm, whose cost is exponential in the treewidth of the network
> (Lauritzen and Spiegelhalter 1988). Both families are exact and both are governed by a structural width
> parameter of the underlying graph. Section 4.3 positions the present method within this landscape: it is
> a specialisation of cutset conditioning to the source-to-node reachability problem, and its realised cost
> is governed by the same width parameter that controls junction-tree inference and well-ordered binary
> decision diagrams.

*[writer note: add Lauritzen & Spiegelhalter (1988), J. Royal Statistical Society B 50(2), to the
bibliography; Pearl (1988) is already cited.]*

**4b. New closing paragraph of §1.1, before "Hence, existing methods face a trade-off …" — add:**

> A further limitation cuts across all of the exact methods above: they operate on point-valued component
> reliabilities. In practice, component failure probabilities are often known only imprecisely — from
> sparse data, expert elicitation, or manufacturer bounds — and a rich literature on imprecise probability
> represents such knowledge as intervals or as probability boxes (p-boxes), i.e. bounds on the cumulative
> distribution of an uncertain quantity (Ferson et al. 2003). Arithmetic on p-boxes with known or unknown
> dependence is formalised in Williamson and Downs (1990), building on the classical Fréchet–Hoeffding
> bounds on joint distributions. Decision-diagram and path-based exact methods do not propagate such
> imprecise inputs natively: an interval query requires repeated evaluation at selected input corners, and
> no analytic route exists to a distributional bound. The method proposed here propagates interval and
> p-box reliabilities directly, which is the capability that distinguishes it from a well-ordered decision
> diagram of comparable computational cost.

*[writer note: add Williamson & Downs (1990), Int. J. Approximate Reasoning 4(2); Ferson et al. (2003),
Sandia report SAND2002-4015 (or the equivalent archival reference) to the bibliography.]*

**Rationale:** grounds the R3.1 comparison (4a) and motivates the new imprecise capability with the
standard literature (new contribution); both are needed before §4.3 and §5 can refer to them.

--------------------------------------------------------------------------------
## EDIT 5 — §2 Network Model: formal reachability model and imprecise inputs

**5a. In §2.3 Reliability Objective, after the definition of b(v)** (ends "…is referred to as the node
reliability (or belief) at v."), **add:**

> Equivalently, reachability can be expressed recursively. Define for each node the reachability indicator
>
> R_v = X_v ∧ ( v ∈ S  ∨  ⋁_{u∈Pa(v)} ( R_u ∧ X_{uv} ) ),
>
> so that b(v) = P(R_v = 1). Because all node and edge indicators are mutually independent (Assumption 2),
> R_v is a monotone Boolean function of the component indicators: switching any component from failed to
> operational can only preserve or create source-to-node connectivity, never destroy it. Two consequences
> are used repeatedly in what follows. First, computing b(v) is #P-hard in general, since it subsumes
> two-terminal network reliability. Second, the monotonicity of R_v in every component makes b(v) a
> non-decreasing function of every component reliability, a property that Section 5 exploits to propagate
> interval-valued inputs exactly.
>
> For a set A ⊆ V, let anc(v) denote the ancestors of v (nodes with a directed path to v), and let
> F = {v : |Ch(v)| ≥ 2} and J = {v : |Pa(v)| ≥ 2} denote the fork and join nodes of G. Given a set
> E_c ⊆ F of forks whose reachability states have been fixed by conditioning, the unresolved influence of
> a parent u of a join node is infl(u; E_c) = ({u} ∪ anc(u)) \ E_c — the upstream components on which the
> signal through u still depends. Two parents are dependent precisely when their unresolved influences
> intersect; this is the structural criterion used by the decomposition of Section 4.

**5b. New subsection §2.5 "Imprecise component reliabilities" after §2.4 Model Assumptions:**

> The formulation above takes the component reliabilities R(v) and P(u,v) as known point values. In many
> applications these inputs are themselves uncertain: failure probabilities may be estimated from sparse
> operational data, elicited from experts, or specified only as bounds. We therefore allow each component
> reliability to be specified in one of three forms of increasing informativeness:
>
> (i) a point value p ∈ [0,1], as above;
>
> (ii) an interval [p̲, p̄] ⊆ [0,1], asserting only that the true reliability lies between the stated
> bounds;
>
> (iii) a probability box (p-box): a pair of cumulative distribution functions (F̲, F̄) bounding the
> distribution of the uncertain reliability, appropriate when partial distributional information is
> available (Ferson et al. 2003; Williamson and Downs 1990).
>
> The reliability objective generalises accordingly: for interval inputs, the target is the exact range
> [b̲(v), b̄(v)] of node reliabilities attainable over all component reliabilities consistent with the
> stated intervals; for p-box inputs, the target is a sound pair of bounds on the distribution of b(v).
> Section 5 shows that the proposed propagation scheme computes the interval range exactly — a consequence
> of the monotonicity established above — and computes guaranteed distributional bounds in the p-box case.

**Rationale:** provides the formal model the reviewers asked for (R2.7, t1, t3 groundwork) and the
definitions needed by the imprecise-propagation results (new contribution).

--------------------------------------------------------------------------------
## EDIT 6 — §3: worked multi-level nested example

**Placement:** new subsection §3.5 (after §3.4 "IPA Workflow and algorithm"), or immediately after the
Figure-12 discussion in §4.2 — recommended: §4.2, where the nested network is already introduced, so the
figure serves both purposes.

**Proposed addition (structure; numbers to be generated):**

> To make the procedure concrete, consider again the nested network of Figure 12 with all non-source nodes
> assigned intrinsic reliability 0.9 and all edges transmission probability 0.9. The inner diamond D1
> (fork 1, join 6) is identified first; its conditioning set is the single fork {1}, so its resolution
> enumerates two states and yields the conditional signal map ψ_D1(s), s ∈ {0,1}. Replacing D1 by a
> supernode, the reduced network exposes D2 (fork 7, join 11) and D3 (fork 14, join 12), each resolved in
> the same way. The outer diamond D4 (fork 1, join 16) is then resolved over its own conditioning set; the
> contributions of the inner structures enter through their stored conditional maps rather than through
> re-enumeration of their internal paths. Table X traces the quantities computed at each step: the diamond
> being resolved, its conditioning set, the enumerated states, the resulting conditional signal
> probabilities, and the belief at its join node. The final belief at node 16 agrees with exhaustive path
> enumeration to floating-point precision, while the total number of enumerated conditioning states is
> [N] rather than the [M] states required by direct multi-level conditioning without decomposition.
>
> *[writer note: generate the numeric trace (per-step ψ values, belief at each join, N and M) by running
> the reference recursion on the Figure-12 network with the stated probabilities; validation/rc_core.jl is
> the machine-checked reference for exactly this recursion. Do not hand-compute. Table X is a new small
> table.]*

**Rationale:** direct answer to t1 (step-by-step multi-level nested trace beyond §3.3's single diamond).

--------------------------------------------------------------------------------
## EDIT 7 — §4.1: strengthen Lemma 1 and Lemma 2; add separator-sufficiency and factorisation lemmas

**7a. Replace the statement and proof of Lemma 1 (Conditional Invariance).**

**Existing:** "Lemma 1 (Conditional Invariance of a Resolved Diamond). … Proof. By construction, all
statistical dependencies internal to D_in are removed once the variables in C_in are fixed. …"

**Proposed replacement:**

> **Lemma 1 (Conditional invariance).** Let A ⊆ V and let R_A denote the vector of reachability
> indicators of A. Then for any node v,
>
> b(v) = Σ_{c ∈ {0,1}^{|A|}} P(R_A = c) · P(R_v = 1 | R_A = c),
>
> and the decomposition is well defined because every R_u is a deterministic function of the mutually
> independent component indicators {X_w, X_{wu}}.
>
> Moreover, let D be a diamond subgraph with join j and conditioning set C ⊆ F ∩ anc(j), and let
> ψ_D(c) = P(J_D | R_C = c) denote its conditional signal map. If an enclosing computation conditions on
> further variables A' with A' ∩ D = ∅ — that is, the outer conditioning fixes no variable internal to D —
> then ψ_D(c) is unchanged: for fixed c, ψ_D(c) is a function only of the component indicators internal to
> D, which are independent of all indicators outside D. Outer conditioning therefore affects only the
> weights P(R_C = c | R_{A'}), never the map ψ_D itself.
>
> *Proof.* The first display is the law of total probability over the partition {R_A = c}. For the second
> claim, fix c. Conditional on R_C = c, the event J_D is determined by the indicators of nodes and edges
> internal to D. By Assumption 2 these are independent of every indicator outside D, hence of R_{A'}
> whenever A' contains no internal variable of D. Consequently
> P(J_D | R_C = c, R_{A'} = a) = P(J_D | R_C = c) for every outer state a. ∎
>
> The condition A' ∩ D = ∅ is essential and is enforced by the identification procedure: when an outer
> conditioning does fix a variable internal to a previously resolved subgraph — as can occur when diamonds
> overlap or share conditioning nodes — the sub-problem is a different one and is resolved (and stored)
> separately under its own conditioning context. Section 4.2.1 makes this identification precise. A
> conditioning variable already fixed by an outer state contributes a single term to the enumeration
> rather than two, so overlapping conditioning never doubles work unnecessarily.

**7b. New Lemma (separator sufficiency), inserted after Lemma 1:**

> **Lemma 2 (Separator sufficiency).** Let v be a join node with parents Pa(v), and let
> C ⊆ F ∩ anc(v) be such that every directed path from a common ancestor of two distinct parents
> u_i, u_j ∈ Pa(v) to those parents intersects C — that is, C is a cutset of the parents' shared ancestry.
> Then, conditional on R_C, the parent reachability events {R_{u_i}} are mutually independent, and
>
> b(v | R_C = c) = R(v) · ( 1 − Π_{u ∈ Pa(v)} ( 1 − P(R_u = 1 | R_C = c) · P(u,v) ) ).
>
> *Proof.* With R_C fixed, the residual ancestry infl(u_i; C) of distinct parents share no component
> indicator, by the cutset property. Each R_{u_i}, conditional on R_C, is a function of its residual
> ancestry alone; functions of disjoint sets of independent variables are independent. The display is then
> the independent-union rule of Section 3.2.1 applied conditionally. ∎
>
> Lemma 2 is the justification for the conditioning sets used throughout: the identification procedure
> returns, for each reconvergent structure, a separating set C satisfying the cutset property, and the
> per-structure cost 2^{|C|} follows.

**7c. New Lemma (independent-substructure factorisation), inserted after Lemma 2:**

> **Lemma 3 (Independent-substructure factorisation).** Fix a conditioning context E_c and, for parents
> u, u′ of a join v, write u ~ u′ whenever infl(u; E_c) ∩ infl(u′; E_c) ≠ ∅. Let G_1, …, G_m be the
> equivalence classes of Pa(v) under the transitive closure of ~. Then the events {v is reached through
> some parent in G_k}, k = 1, …, m, are mutually independent, so
>
> b(v) = R(v) · ( 1 − Π_{k=1}^{m} ( 1 − P(v reached via G_k) ) ),
>
> and each class G_k can be conditioned on its own separating set C_k independently of the others.
>
> *Proof.* Distinct classes have disjoint unresolved influence by construction, so the class events are
> functions of disjoint sets of independent indicators, hence independent; the product form is the union
> rule for independent events. ∎
>
> The practical effect is substantial. At a join whose k parents share ancestry only pairwise within
> m independent groups, joint conditioning would enumerate 2^{|C_1|+…+|C_m|} states, whereas factorised
> conditioning enumerates Σ_k 2^{|C_k|}. In the extreme case of k parents each depending on its own single
> fork, the cost falls from 2^k to 2k — from exponential to linear in the fan-in.

**7d. Lemma renumbering.** Current "Lemma 2 (Supernode Equivalence)" becomes Lemma 4; its proof can stand
with one strengthening sentence:

> *Add at the end of the existing proof:* Formally, by Lemma 1 the stored map ψ_D(c) equals
> P(J_D | R_C = c) in every outer context that fixes no internal variable of D, and by Lemma 2 the
> downstream update uses only these conditional probabilities together with the weights P(R_C = c); both
> are preserved by the replacement, so every downstream belief is unchanged. ∎

**Rationale:** t3 asked for the lemma proofs to be strengthened from sketches; t2/t4 asked how
overlapping/shared-conditioning diamonds are handled without information loss (the context condition in
7a); the factorisation lemma is the new efficiency result referenced in §4.3 (R2.4).

--------------------------------------------------------------------------------
## EDIT 8 — §4.2: supernode identity paragraph (new §4.2.1)

**Placement:** end of §4.2, after the Figure-12 walk-through paragraph.

**Proposed addition:**

> **Identification of stored sub-problems.** A resolved sub-structure is identified by the pair (induced
> substructure, conditioning context): the internal nodes and edges of the diamond together with the set of
> upstream variables whose states are fixed when it is resolved. Two occurrences of the same substructure
> reached under different conditioning contexts are treated as distinct sub-problems, because an outer
> state that fixes a variable inside the substructure changes its conditional signal map (cf. the condition
> of Lemma 1). This context-aware identification is what guarantees correctness when diamonds overlap or
> share conditioning variables: reuse occurs only between genuinely identical sub-problems. Conversely,
> a conditioning variable whose state is already determined by the enclosing enumeration contributes a
> single state rather than two, so the enumeration never expands over variables that carry no remaining
> uncertainty. Together these two rules bound the stored state space by the number of genuinely distinct
> conditional sub-problems, which is the quantity reported as realised computational work in Section 4.3.

**Rationale:** direct answer to t2 (how conditional maps are stored and queried; cache-explosion
management) and t4 (overlapping/non-hierarchical diamonds, no information loss).

--------------------------------------------------------------------------------
## EDIT 9 — §4.3: replace the qualitative complexity discussion

**Existing:** "The benefit of decomposition is not that it removes the exponential nature of exact
inference in all cases … as explored empirically in the case studies that follow." (whole of §4.3,
including Table 1)

**Proposed replacement (retitle: "4.3 Complexity and relation to established exact methods"):**

> The computational cost of the procedure admits an exact per-instance expression. Let the recursion of
> Section 4.2 resolve diamonds d = 1, …, M (counting nested resolutions), with conditioning sets C_d and
> internal edge sets E_d. The work performed is
>
> W = Σ_{d=1}^{M} 2^{|C_d|} · O(|E_d|),
>
> since each diamond is resolved by enumerating the 2^{|C_d|} states of its conditioning set and each state
> requires a propagation over the diamond's internal structure. Every term of this sum is available before
> enumeration begins, because the conditioning sets are produced by the identification procedure itself;
> the cost of an analysis is therefore computable in advance for a given network, rather than merely
> bounded asymptotically. Memoisation of resolved sub-problems (Section 4.2.1) reduces the realised work to
> the number of genuinely distinct conditional sub-problems, which is the quantity measured in the
> experiments below. The factorisation of Lemma 3 reduces the exponents themselves in favourable cases —
> at a fan-in of k independent branches, from 2^k states to a number linear in k — without changing the
> worst-case class.
>
> **Relation to cutset conditioning and junction trees.** The procedure is a specialisation of cutset
> conditioning (Pearl 1988) to source-to-node reachability in DAGs. Classical cutset conditioning selects a
> single global cutset whose state enumeration renders the whole network singly connected, at cost
> exponential in the cutset size; the present method instead identifies, at each reconvergence actually
> encountered, a local separating set of the parents' shared ancestry (Lemma 2), conditions on it, and
> recurses, so that the realised cost is a sum of local exponentials rather than one global exponential.
> Tree-structured regions of the network are traversed by the closed-form updates of Section 3 at linear
> cost, and the factorisation of Lemma 3 prevents joint conditioning over forks that are independent given
> the current context. The maximum conditioning-set size encountered on a network is bounded by the size of
> the largest set of mutually entangled shared ancestors, a quantity that is in turn bounded by — and, as
> shown below, empirically tracks — the treewidth of the network. The method therefore sits in the same
> parametric complexity class as the junction-tree algorithm (cost exponential in treewidth; Lauritzen and
> Spiegelhalter 1988) and as a well-ordered reduced binary decision diagram (size exponential in pathwidth):
> all are exact, all are fixed-parameter tractable in the relevant width, and none escapes the #P-hardness
> of the underlying problem. No closed-form complexity in the node count alone exists for any of them.
>
> **Measured comparison.** Section 5.2 reports, for every network in the validation corpus, the maximum
> conditioning-set size, the realised number of conditional sub-problems, and the node count of a
> reduced-ordered binary decision diagram for the same network built under dynamic variable reordering.
> Two findings anticipate the details. First, the maximum conditioning-set size sits in the same band as
> the logarithm of the decision-diagram size — for example 7 against 8.2 on a 4×4 grid, 10 against 9.0 on a
> bridge network, 13 against 11.7 on the densest random network tested — confirming that both methods are
> governed by the same structural width parameter. Second, the realised work of the proposed method is of
> the same order as the decision-diagram size, sometimes smaller and sometimes larger, with neither method
> dominating across the corpus. We state the conclusion plainly: for exact point-valued reliability the
> proposed method is competitive with, but not structurally superior to, a well-ordered decision diagram.
> Its distinguishing capability lies in the native propagation of imprecise component reliabilities
> (Section 5.3), which decision-diagram methods do not provide.

*[writer note: keep or drop the qualitative Table 1 — recommend replacing it with a quantitative table
drawn from data/complexity_validation.csv (columns: network, |V|, |E|, max |C_d|, realised sub-problems,
ROBDD nodes). The three quoted width pairs are grid_4x4 maxcond 7 vs log2(290)=8.2; bridge_5 10 vs
log2(529)=9.0; random_n25_s1 13 vs log2(3255)=11.7. Realised-vs-ROBDD examples if needed: counterexample
42 vs 340, complete_8 142 vs 759, layered_5x4 1961 vs 1043.]*

**Rationale:** replaces the qualitative complexity argument with the exact per-instance formula, the
formal cutset-conditioning/junction-tree positioning, and the honest measured comparison (R2.4, R3.1, t5,
t8).

--------------------------------------------------------------------------------
## EDIT 10 — §4.4: trim and correct (retitle: "4.4 Numerical realisation")

**Existing:** "IPA is implemented in Julia as both part of the InfoPropFramework.jl package … which
provides independent convolution operators to compute pbox envelope propagation under path dependencies."

**Proposed replacement (whole section):**

> The propagation scheme of Sections 3–4 is arithmetic over the operations {+, ×, complement} on component
> reliabilities, and is realised once, generically, for the three input forms of Section 2.5: point values,
> intervals, and probability boxes. Three numerical points warrant note.
>
> First, multi-parent updates are evaluated in the product form 1 − Π_i (1 − p_i) rather than by the
> alternating inclusion–exclusion sum; the two are equivalent under independence, but the product form is
> numerically stable and, for interval-valued inputs, avoids the spurious widening that alternating sums
> introduce.
>
> Second, for interval inputs the conditioning step is evaluated at the corner states of the conditioning
> bounds and the result enclosed in an interval envelope; Section 5.3.1 shows this yields the exact range,
> by monotonicity.
>
> Third, for p-box inputs the conditioning recombination at a join is a convex combination of two dependent
> random quantities, not an independent sum; it is evaluated by the operator of Section 5.3.2, which
> integrates over the distribution of the conditioning weight and bounds the branch dependence by the
> Fréchet–Hoeffding inequalities. Because the underlying floating-point arithmetic is not outward-rounded,
> the computed bounds are intersected with [0,1] as a final step — a projection that can only tighten a
> bound on a probability, never invalidate it — and this projection is guarded: an excursion beyond [0,1]
> exceeding ordinary floating-point round-off by several orders of magnitude raises an error rather than
> being silently discarded, so that a genuine soundness regression cannot be masked as rounding.
>
> The full implementation, together with all validation scripts and data, is openly available (see Data
> and Software Availability).

**Rationale:** removes the description of the superseded independent-convolution recombination — which is
unsound for this step (Section 5.3.2) — and states the numerical safeguards; implementation naming is
confined to the availability statement (R2.7 reproducibility is served by the availability section and
the formal algorithm, not by package names).

--------------------------------------------------------------------------------
## EDIT 11 — §5 restructure (overview)

Proposed structure of the revised Section 5:

- **§5.1 Methodology demonstration on the benchmark grid network** (expanded §5.1; EDIT 12)
- **§5.2 Validation and cost comparison against an exact decision-diagram method** (new; EDIT 13)
- **§5.3 Imprecise reliability propagation** (new; EDIT 14)
- **§5.4 Applied case study: a medical drone logistics network for Scotland** (replaces §5.2; EDIT 15)
- **§5.5 Limitations and future work** (expanded §5.3; EDIT 16)

A short methodology sentence appears once, at the top of §5, and governs every timing number in the paper:

> All runtimes reported in this section were measured after a warm-up run of the same computation was
> executed and discarded, so that one-off program-initialisation cost is excluded from every figure; each
> reported time is the minimum of repeated measurements on otherwise idle hardware.

**Rationale:** the warm-up discipline is stated once and explicitly (R2.2); the section order runs
validation → comparison → new capability → application.

--------------------------------------------------------------------------------
## EDIT 12 — §5.1 grid benchmark: moderate the dPrPm claim, add independent re-verification

**12a. §5.1.2, runtime paragraph.**

**Existing:** "Table 2 compares the runtime of IPA with the runtime reported for dPrPm … it suggests that
IPA can provide substantial computational savings while retaining exactness."

**Proposed replacement:**

> Table 2 reports the runtime of IPA on the benchmark network alongside the runtime reported for dPrPm in
> (Tong and Tien 2019). Two caveats attend this comparison and we state them plainly. First, the dPrPm
> figure is quoted from the source study and was obtained in a different implementation environment; the
> comparison is indicative only, and no controlled speed claim is based on it. Second, the dPrPm reference
> implementation is not publicly available and its authors could not be reached, so the comparison cannot
> be reproduced independently. For these reasons the quantitative performance assessment of the proposed
> method in this paper rests on the controlled, same-environment comparison against an independent exact
> method in Section 5.2, and dPrPm is retained only as the published point of reference that motivated the
> benchmark.

**12b. End of §5.1.2, add:**

> The benchmark has also been re-verified independently. The node reliabilities produced by the proposed
> method were compared against a reduced-ordered binary decision diagram with dynamic variable reordering —
> a canonical independent exact method — constructed for the same network; the worst per-node disagreement
> is 1.1×10⁻¹⁶, i.e. floating-point round-off, confirming the published values in Table
> [tab:resultcomparison_grid]. During this hardening the diamond-identification procedure was also
> stress-tested beyond the benchmark's parameterisation (non-unit node priors, and the boundary case in
> which all node priors equal one); two edge-case identification errors were found and corrected, and the
> corrected procedure is the one validated across the full corpus of Section 5.2. Neither error affects
> the published benchmark table, which stands as originally reported.

**Rationale:** 12a moderates the uncontrolled comparison exactly as asked (R2.2) and records the
irreproducibility of dPrPm; 12b adds the independent verification on the same network (R2.3/R3.2) with
honest disclosure of the fixes found during hardening.

--------------------------------------------------------------------------------
## EDIT 13 — new §5.2: corpus-wide comparison against an exact decision-diagram method

**Proposed content (full draft):**

> **5.2 Validation and cost comparison against an exact decision-diagram method**
>
> To address the breadth of validation, the proposed method was compared against an independent exact
> method — a reduced-ordered binary decision diagram (ROBDD) with dynamic variable reordering — across a
> corpus of 129 random and mutated DAGs (10 to 28 nodes, densities 0.14–0.42), six topological families
> (multi-source, grid/lattice, layered, bridge, series–parallel, complete), larger random networks up to
> 50 nodes, and several real infrastructure networks. Every network in the corpus was evaluated by both
> methods; the worst per-node disagreement observed anywhere is 1.1×10⁻¹⁶, for both perfect and imperfect
> component reliabilities. Table [new: corpus summary] summarises the corpus and Table [new: structured
> networks] reports representative structured and real networks in detail.
>
> The comparison also quantifies cost. For each network we report the maximum conditioning-set size
> |C|max encountered by the proposed method, its realised number of distinct conditional sub-problems, and
> the ROBDD node count under dynamic reordering. As anticipated in Section 4.3, |C|max tracks the logarithm
> of the ROBDD size across the corpus — the two methods are governed by the same structural width — and the
> realised work of the two methods is of the same order, with neither dominating: on some networks the
> proposed method resolves fewer sub-problems than the diagram has nodes, on others more. No family in the
> corpus favours the proposed method for exact point-valued computation. This is an honest structural
> finding, and it sharpens rather than weakens the contribution: the value of the proposed method rests on
> the capabilities of Section 5.3, not on a claim of a smaller exact state space.

*[writer note: the two tables exist in paste-ready form (tex/paper_tables.tex): the structured-network
table (power-network, grid-graph, KarlNetwork, counterexample-n15 with |V|, |E|, diamonds, max |C|, ROBDD
nodes, max Δ ≤ 1.1e-16) and the corpus summary by family (129 graphs, median/max ROBDD nodes, naive-order
blow-up counts). Convert to Word tables; figures for the width correlation can be drawn from
data/complexity_validation.csv.]*

**Rationale:** answers R2.1 (breadth), R2.3/R3.2 (quantitative comparison with an exact method on the
same networks), and R2.4 (measured width correlation), with the honest no-dominance finding.

--------------------------------------------------------------------------------
## EDIT 14 — new §5.3: imprecise reliability propagation

**Proposed content (full draft):**

> **5.3 Imprecise reliability propagation**
>
> The results so far establish that the proposed method matches a well-ordered decision diagram on exact
> point-valued reliability at comparable cost. This section presents the capability that separates the two:
> the propagation scheme accepts interval- and p-box-valued component reliabilities directly (Section 2.5).
>
> **5.3.1 Interval-valued reliabilities: exact and fast.** Because the node reliability b(v) is
> non-decreasing in every component reliability (Section 2.3), its exact range over interval inputs is
> attained at the two extreme corners of the input box: the lower bound when every component takes its
> lower reliability, the upper bound when every component takes its upper reliability. No dependence issue
> arises, and the propagated interval is exact. This was verified across the full corpus of Section 5.2 by
> comparing the propagated interval against the decision-diagram evaluation at the two corner inputs: the
> worst discrepancy in either bound is of order 10⁻¹⁶. By contrast, interval propagation that ignores
> reconvergent dependence over-widens the range — by up to 0.45 in the corpus — illustrating that the
> conditioning machinery is as necessary for sound imprecise propagation as it is for exact point values.
>
> The interval computation is also fast. For a one-shot query — given a network, produce the interval
> reliability — the proposed method completed faster than the decision-diagram route to the same answer
> (build the diagram once, evaluate at both corner inputs) on every one of eight corpus families tested, by
> factors ranging from 2.9 to 95. We scope this claim carefully: it concerns the one-shot cost, in which
> the diagram's construction cost counts against it. A workload that amortises a single construction across
> many repeated queries on a fixed network is a different scenario, not tested here, and could favour the
> diagram-based route instead.
>
> **5.3.2 Probability-box reliabilities: guaranteed distributional bounds.** For p-box inputs the
> conditioning step requires care. At a join resolved by conditioning, the belief is a convex combination
> W·A + (1−W)·B, where W is the (uncertain) probability of the conditioning state and A, B are the
> (uncertain) conditional beliefs of the two branches. A and B are functions of shared upstream
> reliabilities and are therefore dependent; treating the combination as an independent sum is unsound and
> can assign probability mass outside [0,1]. The operator used here instead integrates over the
> distribution of W, blending the branch distributions at each weight level, with the branch dependence
> bounded by the Fréchet–Hoeffding inequalities (Williamson and Downs 1990). Soundness of the resulting
> bounds is inherited from that classical result: the computed pair of distribution functions encloses the
> true distribution of the node reliability under any dependence between the branches. A tighter variant
> restricts the dependence bound to non-negative dependence, motivated by the observation that both
> branches are non-decreasing functions of the shared upstream reliabilities and hence cannot be negatively
> dependent; this variant produced no soundness violation in any of the validation configurations tested
> (dozens of topology, input-shape, and uncertainty-width combinations, each checked against Monte Carlo
> ground truth), but a general proof of its soundness under partial dependence information of this kind is
> not available in the literature and is identified as future work. All headline claims in this paper use
> only the provable Fréchet-based bound.
>
> The tightness of the bounds — as distinct from their soundness, which does not vary — depends on the
> structure: across a sweep of input-distribution shapes, uncertainty widths, and reconvergence regimes on
> the benchmark network, the bound band ranged from approximately 0.18 of the unit range under
> high-reliability, weakly reconvergent conditions to approximately 0.70 under strongly reconvergent,
> fully uncertain conditions, with zero soundness violations across the sweep [figure: envelope]. The
> driver of tightness is reconvergence depth combined with input uncertainty; the shape of the input
> distribution is secondary. Computational cost is a controllable dial: interval propagation costs a small
> constant factor over point-valued propagation (a factor of about 1.2 in our measurements), while p-box
> propagation grows quadratically with the discretisation level of the distribution bounds, in exchange
> for proportionally tighter bands. We therefore state bound tightness always at the discretisation level
> used, and make no claim that distributional propagation is cheap — it is controllable, with rigorous
> bounds at every setting.
>
> **5.3.3 A certified decision bound from a single propagation.** The practical payoff is that the
> propagated distribution bounds certify decision-relevant probabilities. Consider a stated reliability
> requirement x* for a given node: the propagated p-box yields guaranteed lower and upper bounds on
> P(b(v) ≤ x*), the probability that the node fails its requirement, from one propagation. On the
> benchmark network at a representative requirement of x* = 0.95, the certified band on this probability
> had width between 0.02 and 0.12 across the regimes tested. Matching that precision by simulation,
> planned conservatively without foreknowledge of the answer, would require between 267 and 9,604 samples
> of the network's uncertain inputs, and the result would remain a statistical estimate rather than a
> guarantee. (When the true probability lies near 0 or 1 the retrospective sample requirement collapses —
> correct statistics, but knowable only in hindsight; the planning figure quoted is the one a practitioner
> must budget.) An exact decision-diagram method has no analytic route to this bound at all and would
> itself fall back on simulation. This certified-bound capability, not raw speed, is the concrete
> engineering value of imprecise propagation.

*[writer note: envelope figure from data/grid_envelope.csv (18 configurations, bands 0.18–0.44 in the
perfect regimes, 0.60–0.70 in the uncertain regimes, unsound = 0.000 everywhere). Certified-bound numbers
from data/certified_bound_vignette.csv. Interval-vs-diagram timing per family from
data/interval_bdd_vs_ipa_timing.csv (2.91×–95.07×). Interval overhead 1.2× and the p-box discretisation
cost curve from data/timing_imprecise.csv (0.668 ms point / 0.785 ms interval; p-box 2.7 s at 50 levels,
8.3 s at 200, 110 s at 800 on the 15-node reference network — quadratic growth stated as the measured
ratio, per the guardrail against unmeasured multipliers). Naive interval over-widening up to 0.45 from
interval_sweep data.]*

**Rationale:** presents the new capability with the decided framing: interval = exact and fast
(one-shot-scoped), p-box = provable Fréchet bound as headline with the tighter operator honestly labelled
(guardrails §5), tightness as a characterised envelope, and the certified bound as the "so what" (the
strengthening beyond the reviewer asks).

--------------------------------------------------------------------------------
## EDIT 15 — §5.4: replace the drone case study entirely

**Existing:** all of current §5.2 ("Application to Drone Medical Delivery Networks", §5.2.1–§5.2.4),
including the six-configuration tables and the exponential distance-decay probability model.

**Proposed replacement (full draft):**

> **5.4 Applied case study: a medical drone logistics network for Scotland**
>
> The methodology having been validated in Sections 5.1–5.3, this section applies it to a real
> infrastructure planning problem: the conceptual medical drone delivery network for Scotland designed by
> Jones et al., who optimised station placement and network structure over real hospital, airport, and
> candidate-station locations, two drone types (short-range vertical take-off and landing, nominal range
> 70 km; long-range fixed-wing, nominal range 700 km), and stated infrastructure specifications, trading
> off delivery time, capital cost, and resilience. The reliability question the present method can answer,
> and their point-probability framework cannot, is: given the acknowledged uncertainty in the component
> availability assumptions, how confidently can each location in a candidate design be said to be reachable
> from the supply hubs?
>
> **5.4.1 Model inputs and their provenance.** Every input of the reliability model is derived from the
> source study, with one clearly flagged extension.
>
> *Location availability.* The source study's own resilience analysis assumes that non-hub locations fail
> independently with probability 0.2 while hub locations are always available. We adopt the same structure,
> but represent the non-hub availability as the interval [0.75, 0.85] centred on the source study's figure,
> for a deliberate reason: that figure is stated in the source study as an assumption rather than derived
> from data, and an interval-valued input turns the analysis into a built-in sensitivity assessment of
> precisely that assumption. Hub locations retain availability 1.
>
> *Connection existence.* A connection between two locations exists, for a given drone type, if and only if
> the inter-location distance is within that type's stated nominal range — the source study's own
> network-construction rule, applied exactly. Where both drone types can serve a connection, the connection
> is available if either type's transmission succeeds, the two being independent.
>
> *Connection reliability — the flagged extension.* The source study holds weather conditions constant in
> its own analysis, while noting that weather-driven range variation is in principle an uncertain quantity
> requiring expert elicitation, which it deliberately defers. We extend exactly this deferred point, and
> only this point. A connection operating well within a drone's nominal range is treated as reliable. A
> connection whose length falls within an illustrative weather-derating margin of the range limit — the
> final ten per cent, an assumed bound since the source study does not quantify one either — is treated as
> genuinely uncertain: its transmission probability is the vacuous interval [0, 1], expressing honestly
> that adverse weather may or may not close that particular route. This is an extension of the source
> study's own stated limitation, not an independent invention, and no other probability in the model is
> assumed.
>
> *Direction of dependency.* The source study's connections are undirected, since a delivery route can be
> flown in either direction; the reliability question, however, concerns supply reaching facilities from
> hubs. The dependency graph is therefore directed from the hub tier outward — matching the source study's
> own hub-and-spoke architecture — and source-to-node reachability is computed on the resulting acyclic
> structure.
>
> **5.4.2 Network configurations.** The source study's actual optimised network layouts are not published.
> Three configurations are therefore constructed as proxies for the qualitative character of three
> trade-off points described in its results: a fixed-wing-reliant centralised design serving remote
> locations through a hub backbone (217 locations, 263 connections); a densely interconnected
> short-range design (242 locations, 1,753 connections); and a minimal-investment design retaining only
> pre-existing, non-optional infrastructure (230 locations, 1,648 connections). Each is explicitly a
> proxy for the described character of the corresponding design, not a reproduction of an unavailable
> optimisation result. *[writer note: node/edge counts confirmed 2026-07-28 directly from the generated
> network files.]*
>
> **5.4.3 Redundancy and the practical boundary of exact analysis.** A network-design parameter controls
> the reconvergent structure of each configuration: the number of alternate routes provisioned per
> location — a genuine redundancy choice in network design, not a parameter of the analysis method.
> Connecting every operationally plausible pair of locations produced conditioning-set requirements of
> 27–28, well beyond the practical range of exact analysis (the original submission reported computation
> becoming impractical beyond a nesting depth of approximately 18, a figure the reviewers also highlighted).
> Bounding the provision to sixteen alternate routes per location brought the requirement to 15–17 — just
> inside that range — and further increases in provisioned routes changed neither the requirement nor the
> runtime materially, indicating that the reconvergent structure of this network saturates at that level.
> The full exact interval propagation of the densest configurations completes in under 25 seconds; the
> sparse centralised configuration, whose conditioning requirement is 10, completes in well under one
> second. The practical boundary of exact analysis on this real network is thus a measured quantity,
> expressed in terms of a controllable design parameter: more provisioned redundancy improves resilience
> but raises the cost of verifying it exactly.
>
> The comparison of Section 5.2 was repeated on these networks. On the sparse centralised configuration the
> two methods agree to floating-point precision, and the one-shot interval computation of the proposed
> method is approximately fourteen times faster than the decision-diagram route to the same interval. On
> the minimal-investment topology provisioned at low redundancy (six alternate routes per location), both
> methods are comfortably fast and the proposed method remains moderately faster (approximately six times).
> On the same topology at sixteen alternate routes per location, the decision-diagram build did not
> complete within a practical computational budget under either of two variable-ordering strategies
> (dynamic reordering, and a fixed topological order), while the proposed method completed the full exact
> computation in under 25 seconds. We state the finding precisely: both methods are governed by the same
> underlying network property, and both are practical at low redundancy; on this network, the practical
> range of the proposed method, measured along a real redundancy design parameter, extends further than
> that of the decision-diagram alternative. No claim is made that decision-diagram methods cannot handle
> this problem class in general, nor that the crossover point has been located precisely.
>
> **5.4.4 Reliability findings.** The propagated interval reliabilities are informative, not vacuous, and
> they differ meaningfully across the three designs. In the centralised, low-redundancy configuration the
> propagated bounds are narrow (band width at most 0.10, mean 0.09): each location's reachability
> essentially inherits the availability band assumed for the locations themselves, with little additional
> uncertainty accumulated through the network — but also little protection: the design is tree-like, so
> single-route failures directly disconnect service. In the two higher-redundancy configurations the
> best-connected locations are reachable with near-certainty, while the worst-served locations carry a
> genuine, decision-relevant spread: the least certain facilities have reachability probability bounded
> between 0.55 and 0.72. That interval is the honest answer to the planning question under the
> acknowledged input uncertainty: no point-probability analysis of the same design could distinguish a
> facility whose reachability is confidently 0.6 from one whose reachability is anywhere between 0.55 and
> 0.72, yet the two call for different interventions. A map of the network coloured by the lower
> reliability bound (or by band width, showing where uncertainty concentrates) identifies the specific
> facilities where additional redundancy, or better component-availability data, would most improve
> either the network or our knowledge of it. [figure: reliability map]
>
> *[writer note: map figure from the generated per-configuration reliability plots; the belief-range
> numbers above are from the full-propagation record — worst-node interval [0.55, 0.72] in the denser
> configurations, band width ≤ 0.10 / mean ≈ 0.09 in the centralised one (mean 0.089). Runtimes: 16.68 s
> and 23.89 s for the two dense configurations, warm-measured; comparison figures 14.38× (sparse) and
> 6.46× (low-redundancy), decision-diagram node counts 2,667 and 4,968 respectively; agreement 0.0 and
> 1.11×10⁻¹⁶.]*

**Rationale:** replaces indefensible inputs with source-traced ones (t6), leads with reliability insight
rather than runtime (R2.5), turns the scalability limit into a measured, decision-relevant boundary
calibrated to the reviewers' own figure (R2.6), and extends the exact-method comparison to the applied
networks (R2.3/R3.2) with the narrow verified claim only (guardrails §5).

--------------------------------------------------------------------------------
## EDIT 16 — §5.5 Limitations and future work (replaces current §5.3)

**Existing:** "IPA provides exact source-to-node reliability values … and improve tractability in dense
dependency networks." (whole section)

**Proposed replacement:**

> **5.5 Limitations and future work**
>
> The method is exact, and we are explicit about where its advantages do and do not lie.
>
> *Exact point-valued reliability.* The method offers no asymptotic advantage over a well-ordered decision
> diagram. Both are exponential in the network's structural width — the conditioning width here, the
> pathwidth for the diagram — reflecting the #P-hardness of network reliability; across the corpus neither
> dominates, and the realised work tracks the diagram size to within a constant factor (Section 5.2). The
> method is competitive with, not superior to, a well-ordered decision diagram for exact point evaluation;
> its distinctive value lies in imprecise propagation.
>
> *Practical range.* Being exact, the method is exponential in width and intended for the
> sparse-to-moderate regime — a ceiling shared with every exact method. The applied case study makes the
> boundary concrete on one real network: conditioning requirements of 15–17, reached at sixteen provisioned
> alternate routes per location, remain practical (tens of seconds); the requirement of 27–28 produced by
> unrestricted connectivity does not. Imprecise propagation does not relax this boundary: interval and
> p-box propagation use the same conditioning depth as exact point propagation, and only a change to the
> network design itself alters the cost. For networks beyond the practical range, a depth-limited hybrid
> suggests itself: condition exactly to a chosen depth and, beyond it, combine reconvergent contributions
> without conditioning, which for interval inputs yields a rigorous outer bound (wider, but sound, since
> naive interval evaluation over-approximates a monotone function) and for p-box inputs would use the
> Fréchet combination for the unconditioned remainder. We emphasise that this hybrid is proposed, not
> implemented or evaluated here; it is future work, and the everyday method reported in this paper does not
> degrade exactness anywhere.
>
> *Imprecise propagation.* Interval results are exact at machine precision; the speed comparison of
> Section 5.3.1 is scoped to one-shot queries. Distributional (p-box) bounds are sound but their tightness
> is structure-dependent — tight for high-reliability or weakly reconvergent systems, conservative for
> strongly reconvergent systems with broadly uncertain components — and their cost grows quadratically with
> the discretisation level, which confines full distributional propagation to modest networks at present;
> for larger networks interval propagation combined with sampling is the practical recourse. The tighter
> positive-dependence conditioning operator is validated but not proven sound; the proven Fréchet operator
> is used for every guaranteed claim, and a proof (or refutation) for the tighter operator is an open
> mathematical question we have verified is not settled in the existing dependence-bound literature.
>
> *Structural scope.* The method addresses directed acyclic dependency structures. The applied case study's
> networks are directed by the hub-and-spoke supply logic of their source design (Section 5.4.1), which is
> the appropriate reading of that system; general cyclic or bidirectional dependency networks — feedback
> loops, return flows — are outside the present scope, and their principled treatment (for example by
> unrolling or by strongly-connected-component condensation) is future work.

**Rationale:** explicit practical-range discussion anchored to the measured real-network boundary (R2.6),
the hybrid honestly labelled proposed-not-implemented (R3.4), imprecision explicitly not a scalability fix
(guardrails §5), and the DAG-scope justification updated to the rebuilt case study's directionality
(R3.3).

--------------------------------------------------------------------------------
## EDIT 17 — §6 Conclusions (full replacement)

**Existing:** "An exact reliability analysis method … particularly during diamond decomposition when
nested diamonds are not interconnected."

**Proposed replacement:**

> An exact reliability analysis method for directed acyclic process networks with reconvergent dependency
> structures, the Information Propagation Algorithm (IPA), has been presented. The method computes
> source-to-node reliability by propagating reachability probabilities in topological order, resolving
> dependent incoming signals by conditioning on minimal separating sets of shared ancestors, and replacing
> resolved fork–join substructures with statistically equivalent supernodes. The revision establishes the
> method's formal position: it is a specialisation of cutset conditioning to source-to-node reachability,
> its per-instance cost is exactly Σ_d 2^{|C_d|} over the diamonds resolved — computable before enumeration
> — and an independent-substructure factorisation reduces fan-in conditioning from exponential to linear
> where independence permits.
>
> Exactness was verified against an independent exact method, a reduced-ordered binary decision diagram
> with dynamic variable reordering, across 129 random and mutated networks, six topological families, and
> real infrastructure networks, with worst observed disagreement at floating-point precision. The same
> comparison shows that the method's cost is governed by the same structural width parameter as the
> diagram's size, with neither method dominating: for exact point-valued reliability the method is
> competitive with, not superior to, a well-ordered decision diagram. Its distinguishing capability is the
> native propagation of imprecise component reliabilities: interval-valued inputs yield the exact
> reliability range at machine precision — and, for one-shot queries, faster than the decision-diagram
> route to the same interval on every family tested — while probability-box inputs yield guaranteed
> distributional bounds via a conditioning operator grounded in the Fréchet–Hoeffding inequalities,
> enabling certified bounds on requirement-violation probabilities from a single propagation, a result no
> point-valued exact method produces analytically.
>
> An applied case study of a medical drone logistics network for Scotland, with every input traced to the
> source design study and one clearly flagged extension, demonstrated the engineering use of the method:
> propagated reliability bounds identify the facilities whose delivery reachability is most uncertain under
> honest input uncertainty, and a sweep of a real redundancy design parameter located the practical
> boundary of exact analysis on the network — within which the method completed full exact propagation in
> under 25 seconds at a redundancy level where the decision-diagram alternative did not complete within a
> practical budget. Exact reliability analysis of large acyclic networks is feasible whenever
> dependency-inducing substructures remain sufficiently localised, and the boundary of feasibility can be
> measured and expressed in design terms rather than assumed.
>
> Future work includes a soundness proof for the tighter positive-dependence conditioning operator, the
> depth-limited hybrid scheme for networks beyond the exact range, extension to multi-state components and
> explicitly modelled common-cause failures, and principled treatment of cyclic dependency structures.

**Rationale:** conclusions now match the revised claims: formal positioning (R2.4/R3.1), honest
no-dominance finding, imprecise capability as the contribution, rebuilt case study, measured practical
range (R2.6).

--------------------------------------------------------------------------------
## EDIT 18 — Editorial checklist (R2.8, t7)

Typos and grammar observed in the current text (locations by section):

1. §1: "The proposed approach present several advantages" → "presents" (addressed by EDIT 3).
2. §5.1.1: "acompute node reliability … downstream nodes.." → stray "a" and duplicated full stop.
3. §5.1.1: "by identifies reconvergent dependency patterns … conditional decomposition.." → "by
   identifying …"; duplicated full stop.
4. §5.2.1: citation "(jones_drone_2025?)" is unresolved — add the Jones et al. reference to the
   bibliography (the source design study; update to its published status if now in press).
5. §5.2.3: "Comparing compuataional costs" → "computational" (section replaced by EDIT 15 regardless).
6. §5.2.1 (old): "The main computation cost … comes form the complexity" → "comes from" (replaced).
7. §6: "while computed the same result" → "while computing" (replaced by EDIT 17).
8. General: lengthy sentences in §1 and §4 flagged by the reviewer — EDITs 3, 9, 10 shorten the worst;
   a final language pass over §1 is still recommended.
9. Figures: every caption should state the takeaway, not only the content (t7); new figures proposed
   here (width correlation, tightness envelope, reliability map) include takeaway phrasing in EDITs
   13–15.

--------------------------------------------------------------------------------
## New references to add

- Lauritzen, S.L., Spiegelhalter, D.J. (1988). Local computations with probabilities on graphical
  structures and their application to expert systems. J. Royal Statistical Society B 50(2), 157–224.
- Williamson, R.C., Downs, T. (1990). Probabilistic arithmetic I: numerical methods for calculating
  convolutions and dependency bounds. Int. J. Approximate Reasoning 4(2), 89–158.
- Ferson, S., Kreinovich, V., Ginzburg, L., Myers, D.S., Sentz, K. (2003). Constructing probability
  boxes and Dempster–Shafer structures. Sandia National Laboratories, SAND2002-4015.
- Jones et al. — the drone-network source design study (currently the unresolved `jones_drone_2025`
  citation; use its current publication status).
- (Optional, for the treewidth statement) a standard treewidth/pathwidth reference, e.g. Bodlaender's
  survey.

## Numbers used in this document and their sources (writer verification)

- 1.1×10⁻¹⁶ worst corpus disagreement; corpus composition; structured-network table — tex/paper_tables.tex.
- Width pairs 7/8.2, 10/9.0, 13/11.7; realised-ops examples — data/complexity_validation.csv.
- Interval one-shot speedups 2.9×–95× (per-family values) — data/interval_bdd_vs_ipa_timing.csv.
- Interval overhead 1.2×; p-box 2.7 s/8.3 s/110 s at 50/200/800 levels — data/timing_imprecise.csv.
- Envelope bands 0.18–0.70, zero unsound (18 configs) — data/grid_envelope.csv.
- Certified band 0.02–0.12; samples 267–9,604 at x*=0.95 — data/certified_bound_vignette.csv.
- Naive interval over-widening up to 0.45 — interval sweep (see PAPER_GUIDE §1.5 / notes).
- Drone config sizes (confirmed from the generated .EDGES files, 2026-07-28): fw-reliant-centralized
  217 nodes / 263 edges; vtol-dense-decentralized 242 nodes / 1,753 edges; concentrated-minimal
  230 nodes / 1,648 edges. (NB: the smoke-test listing order "217/230/242" would have mis-mapped the
  latter two — the raw-file counts above are authoritative.)
- Drone: maxcond 27–28 unrestricted, 15–17 at K=16, plateau beyond; runtimes 16.68 s / 23.89 s;
  14.38× and 6.46× comparisons; ROBDD 2,667 / 4,968 nodes; sifted >30 CPU-min no convergence, fixed-order
  >7.6 GB — PAPER_GUIDE §6c (drone_k_sweep, drone_bdd_comparison, gen_k6_test records).
- Drone beliefs: centralised band ≤0.10 mean 0.089; dense worst-node [0.55, 0.72], band ≤0.167 —
  PAPER_GUIDE §6c smoke-propagation record.
- STALE ARTIFACT WARNING: grid_case_study/data/grid_accuracy.csv contains pre-correction p-box rows
  (unsound 0.34, "CHECK") from before the convex-combination operator; do not cite it. grid_cost.csv is
  empty. Current p-box soundness evidence: notes/pbox_operator_and_soundness.md.
