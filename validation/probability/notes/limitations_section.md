# §5.3 Limitations — paste-ready prose + checklist

Honest, non-over-claiming limitations paragraph synthesising the whole investigation. Matches the settled
framing (PAPER_GUIDE.md §1, §3; SESSION_WORK_LOG.md §9; pbox_operator_and_soundness.md). Numbers live in
the tables/figures; prose stays qualitative + points to them.

================================================================================================
## Paste-ready prose (§5.3 Limitations)

IPA is an exact method for source-to-node reliability, and we are explicit about where its advantages
do and do not lie.

**Exact point reliability.** IPA offers no asymptotic advantage over a well-ordered decision diagram.
Both IPA's diamond conditioning and a sifted ROBDD are exponential in the graph's width (the conditioning
width for IPA, the pathwidth for the diagram), reflecting the \#P-hardness of network reliability; across
our corpus neither dominates, and IPA's operation count tracks the sifted-ROBDD node count to within a
constant factor (Table~\ref{tab:complexity}). IPA is therefore competitive with, but not structurally
superior to, a well-ordered BDD for exact point evaluation: its distinctive value lies in the native
propagation of imprecise inputs, not in a smaller exact state space.

**Scalability.** Being exact, IPA is exponential in graph width and is intended for the sparse-to-moderate
regime; on our corpus it is exact and practical to roughly fifty nodes, with dense or deeply reconvergent
graphs the limiting case --- a ceiling shared with every exact reliability method.

**Imprecise propagation.** For interval-valued inputs IPA returns the exact reliability range at machine
precision --- reliability is monotone in every input, so the range is attained at the input corners ---
and at lower one-shot cost than the corresponding corner evaluations on a decision diagram
(Table~\ref{tab:interval_timing}). For probability-box (distributional) inputs the picture is more
nuanced. Our conditioning operator returns \emph{sound} bounds on the reliability distribution --- bounds
that decision-diagram methods cannot produce analytically --- but their tightness is structure-dependent:
they are tight for high-reliability or weakly reconvergent systems and conservative, though still sound,
for strongly reconvergent systems with broadly uncertain components (Figure~\ref{fig:envelope}). p-box
propagation is also more costly (quadratic in the discretisation level and, in the present implementation,
practical only for small networks); for larger networks we recommend interval propagation together with
Monte Carlo. The bounds are sound at the discretisation level modulo floating-point round-off, as is
standard for Williamson--Downs p-box arithmetic. We provide two operators: a Fr\'echet-based variant whose
soundness follows from the classical Fr\'echet--Hoeffding bounds, and a tighter variant restricted to
positive branch dependence that is validated sound across our corpus but whose formal soundness proof we
leave to future work.

**Structural scope.** IPA addresses directed acyclic reliability structures; cyclic networks are handled
only via the acyclic transformation of Section~[X] and remain, in the general cyclic case, outside the
present scope (R3.3).

================================================================================================
## Compact version (if space-limited)

IPA is exact but not asymptotically cheaper than a well-ordered BDD (both ~2^{width}, \#P-hard); it is
competitive, not superior, for exact point reliability, and exponential in graph width (practical to
~50 nodes). Its distinctive capability is imprecise propagation: exact (and faster than a diagram's corner
route) for intervals, and sound analytic bounds for p-boxes --- tight for high-reliability/weakly-
reconvergent systems, conservative but sound otherwise, small-network-only, and sound modulo floating-point
round-off. The tighter p-box operator is validated sound across our corpus with a formal proof left to
future work (a Fr\'echet variant is provably sound). IPA targets DAGs.

================================================================================================
## Author checklist — must be in the section (don't over/under-claim)
[ ] State plainly: NO structural advantage over sifted BDD for exact point reliability (competitive, not superior).
[ ] Complexity: both ~2^{width}, #P-hard, neither dominates → point to the complexity table.
[ ] Scalability ceiling ~n=50 / dense-deep = limit; shared with all exact methods.
[ ] Interval = exact + faster one-shot than BDD corners → point to interval-timing table (2.9–95x; note one-shot).
[ ] p-box = SOUND but tightness structure-dependent (tight high-reliability, conservative reconvergent-uncertain)
    → point to the envelope figure. Do NOT conflate sound with tight.
[ ] p-box cost quadratic in steps, small-network only; large nets → interval + MC.
[ ] Float-point/ULP caveat (Williamson–Downs) — one sentence, not alarmist.
[ ] Two operators: cvxF provable (Fréchet/Makarov), cvxP tight but proof open (future work). Don't call cvxP "guaranteed".
[ ] DAG scope + tie to the cyclic-transformation section (R3.3).
[ ] Frame as boundaries of a characterised contribution, not apologies — the certified-bound vignette
    (§[X]) shows the p-box bound is decision-useful precisely where it matters.
