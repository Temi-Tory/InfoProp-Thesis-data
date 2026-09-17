# Point-by-point reviewer responses — draft text for the tracker's response columns

Paste each block into the corresponding "Your Response / Discussion Notes" cell of
`Reviewer_Comments_Response_Tracker.docx`. Section numbers refer to the REVISED manuscript structure
(per `RESS_edit_proposals.md`): §5.1 grid benchmark, §5.2 corpus comparison vs ROBDD, §5.3 imprecise
propagation, §5.4 drone case study, §5.5 limitations. Adjust numbering if the final layout differs.

One statement is used in several responses and should stay consistent: the dPrPm reference
implementation is unavailable and its authors could not be reached, so validation was re-based on an
independent, open, exact oracle (a reduced-ordered binary decision diagram with dynamic variable
reordering), with dPrPm retained only as the published, explicitly caveated point of reference.

================================================================================
## Comments to the Authors (first reviewer table)

### 1. Limited benchmark validation (single 16-node network)
> We agree, and have substantially expanded the validation. The revised manuscript validates the method
> against an independent exact oracle — a reduced-ordered binary decision diagram (ROBDD) with dynamic
> variable reordering — across a corpus of 129 random and mutated DAGs (10–28 nodes, densities 0.14–0.42),
> six topological families (multi-source, grid/lattice, layered, bridge, series–parallel, complete),
> larger random networks up to 50 nodes, and several real infrastructure networks, in addition to the
> original benchmark. Worst per-node disagreement anywhere in the corpus is 1.1×10⁻¹⁶ (floating-point
> round-off), for both perfect and imperfect component reliabilities (new §5.2). The applied drone
> networks are also now included in the exact-method comparison (§5.4.3).

### 2. Runtime comparison not fully convincing (134× from published runtimes)
> We accept this criticism. The 134× figure has been removed from the abstract and conclusions, and the
> dPrPm runtime comparison is now explicitly labelled indicative and non-controlled (§5.1.2); as the
> dPrPm implementation is unavailable and its authors could not be reached, a controlled re-comparison
> against it is not possible. All quantitative performance claims in the revision rest instead on
> controlled, same-environment comparisons against an exact ROBDD (§5.2–5.4). We have also tightened the
> measurement protocol itself: every runtime reported was measured after a discarded warm-up run, so that
> program-initialisation cost is excluded, and this discipline is stated in the manuscript (§5 preamble).

### 3. Lack of comparison with established exact methods
> A quantitative comparison against an exact method has been added. The revised §5.2 reports, for every
> corpus network, exact agreement with a sifted ROBDD together with cost measures on both sides (maximum
> conditioning-set size and realised sub-problem count for the proposed method; node count for the
> diagram). The finding is stated honestly: both methods are governed by the same structural width
> parameter, realised costs are of the same order, and neither dominates — the method's distinctive
> contribution is the native propagation of imprecise reliabilities (new §5.3), which decision-diagram
> methods do not provide. The comparison is extended to the applied drone networks in §5.4.3.

### 4. Theoretical complexity analysis requires clarification
> Section 4.3 has been rewritten. The revision gives an exact per-instance cost expression
> W = Σ_d 2^{|C_d|}·O(|E_d|) over the resolved diamonds, computable before enumeration because the
> conditioning sets are produced by the identification procedure itself; a new factorisation lemma
> (Lemma 3) showing when fan-in conditioning reduces from exponential to linear; and a formal positioning
> of the method as a specialisation of cutset conditioning, with its width parameter bounded by (and
> empirically tracking) the treewidth that governs junction-tree inference and well-ordered decision
> diagrams. Worst-case behaviour is discussed explicitly: the method is exponential in this width, as is
> every exact method, reflecting #P-hardness.

### 5. Drone case study lacks reliability insights
> The case study has been rebuilt around reliability findings (revised §5.4). It now reports which
> facilities in each candidate design carry the most uncertainty about their delivery reachability: in the
> higher-redundancy designs the worst-served facilities have reachability probability bounded between 0.55
> and 0.72 under the acknowledged input uncertainty, against near-certainty for well-connected ones, and a
> map-style figure locates where uncertainty concentrates. The redundancy/tractability trade-off is itself
> presented as a decision-relevant finding: provisioned redundancy improves resilience but raises the cost
> of verifying it exactly, and the practical boundary was measured on the real network. Runtime statistics
> now support, rather than substitute for, the engineering interpretation.

### 6. Scalability limitations deserve deeper discussion
> The revised §5.5 discusses the practical range explicitly and anchors it to a measured, real-network
> example calibrated to the figure raised by the reviewers: on the drone network, unrestricted
> connectivity produces conditioning requirements of 27–28 (impractical), while bounding provisioned
> alternate routes per location to sixteen yields 15–17 — just inside the practical range identified in
> the original submission — with full exact propagation completing in under 25 seconds. We are also
> explicit that imprecise propagation is not a scalability remedy (it uses the same conditioning depth),
> and that only network-design changes alter the cost. A depth-limited hybrid (exact conditioning to a
> chosen depth, rigorous bounding beyond it) is outlined as future work and clearly labelled as proposed,
> not implemented.

### 7. Algorithm reproducibility
> The revision adds the formal machinery needed to reproduce the algorithm: the recursive reachability
> model and influence-set definitions (§2), full proofs of the conditional-invariance and supernode-
> equivalence lemmas plus new separator-sufficiency and factorisation lemmas (§4.1), an explicit
> statement of how stored sub-problems are identified by substructure and conditioning context (§4.2.1),
> and a worked multi-level nested example traced step by step (§4.2). The complete implementation and
> validation suite are openly available (Data and Software Availability).

### 8. Minor editorial issues
> A language pass has been completed; the specific issues identified (duplicated punctuation,
> typographical errors, and overlong sentences in Sections 1, 4, and 5) have been corrected, and the
> sections rewritten in this revision were drafted to the same standard.

================================================================================
## Reviewer #2 (second reviewer table)

### 1. Parallels with Cutset Conditioning / Junction Tree — justify novelty
> The revised §4.3 makes the relationship formal, and we state it candidly. The method is a
> specialisation of cutset conditioning to source-to-node reachability in DAGs: rather than a single
> global cutset, it identifies a local separating set at each reconvergence actually encountered
> (Lemma 2), conditions on it, and recurses, with memoisation of resolved sub-problems; a new
> factorisation lemma (Lemma 3) prevents joint conditioning over forks that are independent given the
> context, reducing fan-in cost from exponential to linear where independence permits. The realised cost
> is governed by the same width parameter as junction-tree inference and well-ordered decision diagrams,
> and we make no claim of asymptotic superiority. The theoretical contribution is the specialisation
> itself (definite per-instance cost, local conditioning, factorisation) together with the capability the
> specialisation enables: the propagation is arithmetic over {+, ×, complement}, and therefore extends
> natively to interval- and p-box-valued reliabilities (§5.3) — an exact-inference capability that
> junction-tree and decision-diagram engines do not provide.

### 2. Benchmark against state-of-the-art exact solvers on the same grid and drone networks
> Done. The grid benchmark is re-verified against a sifted ROBDD (agreement 1.1×10⁻¹⁶; §5.1.2), the full
> corpus comparison is reported in §5.2, and — addressing the "same drone networks" point directly — the
> comparison is extended to the applied case-study networks in §5.4.3: exact agreement on the
> configurations where the diagram completes, with the proposed method moderately faster for one-shot
> interval queries (approximately 14× and 6× on the sparse and low-redundancy configurations), and, at
> the higher-redundancy configuration, the diagram not completing within a practical budget under either
> of two ordering strategies while the proposed method completes in under 25 seconds. The claim is scoped
> precisely: a wider measured practical range on this network, not a structural superiority.

### 3. DAG transformation of the bidirectional multiplex network
> The case study has been rebuilt, and its directionality is now grounded in the system rather than in a
> modelling convenience (revised §5.4.1). The source design study's connections are undirected (routes
> can be flown either way), but the reliability question is directional: whether supply reaches each
> facility from the hub tier. The dependency graph is therefore directed from hubs outward, matching the
> source study's own hub-and-spoke architecture; the previous level-ordering heuristic has been removed.
> We acknowledge explicitly (§5.5) that general cyclic and bidirectional dependency structures — feedback
> loops, return flows — are outside the present scope, and identify their principled treatment as future
> work; the revised limitation statement is written so that the validity of the source-to-facility
> reachability assessment does not rest on the suppressed cyclic behaviour.

### 4. Scalability limit; strategies for high-treewidth graphs including a hybrid
> The revised §5.5 expands this discussion. It gives the measured practical boundary on a real network in
> terms of a controllable redundancy design parameter (see response 6 above / §5.4.3), and outlines the
> hybrid the reviewer describes: exact conditioning to a chosen depth, with reconvergent contributions
> beyond that depth combined without conditioning to give a rigorous bound — sound-but-wider intervals
> for interval inputs, and Fréchet-bounded combination for distributional inputs. We are transparent that
> this hybrid is proposed and analysed qualitatively, not implemented or evaluated in this revision; the
> method as reported never trades exactness for tractability, and we prefer to state the boundary honestly
> rather than claim an approximation capability we have not validated.

================================================================================
## Reviewer #3 (third reviewer table)

### 1. Detailed pseudocode / multi-level nested example
> A worked multi-level example has been added (§4.2): the nested network of Figure 12 is traced step by
> step — each diamond's conditioning set, the enumerated states, the resulting conditional signal maps,
> and the belief at each join — showing how inner structures are resolved once and reused by outer ones,
> and comparing the total enumerated states against direct multi-level conditioning. The formal recursion
> underlying the trace is now fully specified by the lemmas of §4.1 and the model of §2.

### 2. Supernode storage/query; overlapping diamonds; cache explosion
> A new §4.2.1 specifies the identification of stored sub-problems: a resolved substructure is keyed by
> the pair (induced substructure, conditioning context), so that the same subgraph reached under different
> outer conditioning states is treated as a distinct sub-problem — this is precisely what guarantees
> correctness when diamonds overlap or share conditioning variables (cf. the invariance condition of
> Lemma 1). Conversely, conditioning variables whose state is already fixed by the enclosing enumeration
> contribute a single state, so enumeration never expands over variables carrying no remaining
> uncertainty. The stored state space is thereby bounded by the number of genuinely distinct conditional
> sub-problems, which is the realised-work quantity we measure and report (§5.2).

### 3. Prove Lemmas 4.1/4.2
> Done. The revision states and proves the conditional-invariance lemma from the law of total probability
> and component independence, including the precise condition under which the stored conditional map is
> context-invariant (no outer conditioning fixes a variable internal to the resolved substructure), and
> strengthens the supernode-equivalence proof accordingly. Two further lemmas are added and proved:
> separator sufficiency (the identified conditioning set restores conditional independence of the join's
> parents) and independent-substructure factorisation (§4.1).

### 4. Overlapping / non-hierarchical diamonds; no information loss or cycles
> Handled by the context-aware identification of §4.2.1 together with the invariance condition of
> Lemma 1: overlap and shared conditioning never cause reuse of a map outside its validity condition,
> because context is part of the sub-problem identity. Reduction replaces a resolved subgraph by a
> supernode conditioned on upstream variables only, so the reduced graph remains acyclic by construction.
> These guarantees were also exercised empirically: the expanded corpus (§5.2) includes grid and other
> strongly overlapping reconvergent topologies, all exact against the independent oracle.

### 5. Complexity: tighter bounds / worst-case discussion
> Addressed in the rewritten §4.3: an exact per-instance cost expression (not an asymptotic guess), a
> width-parameter bound relating the method to treewidth, junction trees, and well-ordered decision
> diagrams, an explicit worst-case discussion (#P-hardness; exponential in width, as for all exact
> methods), and a measured cost comparison across the corpus (§5.2) in which neither the proposed method
> nor the diagram dominates.

### 6. Drone DAG transparency (probabilities from distances, levels, bidirectionality)
> The case study has been rebuilt so that every input is traced to the source design study (revised
> §5.4.1). Connection existence follows the source study's own range rule exactly (within nominal range:
> 70 km short-range, 700 km fixed-wing); location availability adopts the source study's own resilience
> assumption (hubs always available; non-hub failure probability 0.2), represented as the interval
> [0.75, 0.85] as a built-in sensitivity assessment of that stated-but-underived figure; direction follows
> the source study's hub-and-spoke supply logic (replacing the previous level heuristic); and exactly one
> extension is added and flagged as such — connections within the final ten per cent of nominal range are
> treated as genuinely uncertain ([0,1]) to represent unquantified weather derating, extending a
> limitation the source study itself states and defers. The previous distance-decay probability model has
> been removed. Configuration statistics (nodes, edges, conditioning requirements) are tabulated per
> design.

### 7. Figure quality and captions
> All figures have been reviewed; captions now state the takeaway as well as the content, and the new
> figures added in this revision (width-correlation, bound-tightness envelope, and the reliability map of
> the drone network) follow the same rule.

### 8. Broader applicability (Bayesian networks) / limitations
> The relation to exact inference in probabilistic graphical models is now explicit (§1.1, §4.3): the
> method is a specialisation of cutset conditioning, in the same width-governed class as junction-tree
> inference, so the machinery transfers to source-to-node reachability queries on other directed acyclic
> probabilistic models. The capability that does not transfer back is imprecise propagation: standard
> exact engines (junction tree, decision diagrams) operate on point-valued parameters, whereas the
> proposed propagation extends natively to interval and p-box inputs (§5.3). Limitations are consolidated
> and stated explicitly in §5.5 (no structural advantage for exact point values; width-exponential
> practical range; p-box tightness structure-dependence and cost; DAG scope).
