# The Domination Split: formal statements and proofs (2026-08-18)

Setting. G = (V, E) a DAG. Node durations d : V -> R>=0, edge delays w fixed (crisp); a
*complete path* is a directed source-to-sink path; len(pi, d) = sum of durations on pi plus
its delays. P(d) = max over complete paths of len; through_v(d) = max over complete paths
containing v; the float of v is f_v(d) = P(d) - through_v(d) >= 0. Durations live in a box
B = prod_u [d_u^-, d_u^+]; we want exact per-node bounds on f_v over B.

Interval-valued delays reduce to this setting by subdividing the edge with a dummy node that
carries the delay as its duration, so nothing below is lost by treating durations only.

## Proposition 1 (single-coordinate structure and corner sufficiency)

Fix all durations except d_u = x. Then
    P(x) = max(C0, C1 + x),   through_v(x) = max(A0, A1 + x),
where C1 = best complete path through u, C0 = best avoiding u, and A1, A0 are the same
restricted to paths through v (a path uses each node at most once, so x appears with
coefficient exactly 1). Both are convex piecewise-affine with a single breakpoint and slopes
0 then 1. Their difference f_v(x) has slope pattern 0 / +1 / 0 if P's breakpoint comes first,
or 0 / -1 / 0 if through_v's does; in either case f_v is MONOTONE in x on all of R (direction
possibly depending on the other coordinates).

Corollary (corner sufficiency): the extremes of f_v over the box B are attained at vertices
of B. Proof: at any point, push coordinate u to whichever endpoint does not worsen the
objective (possible by monotonicity in that coordinate with the rest fixed); repeat for each
coordinate in turn; the objective never worsens and the process ends at a vertex.

## Lemma 1 (incomparable coordinates)

If no complete path contains both u and v, then f_v is nondecreasing in d_u, uniformly in the
other coordinates.

Proof. No through-v path contains u, so through_v does not depend on d_u (A1 term absent),
while P is nondecreasing in it. Hence f_v = P - through_v is nondecreasing.

## Lemma 2 (dominated coordinates)

If every complete path through u also passes v (in particular u = v), then f_v is
nonincreasing in d_u, uniformly in the other coordinates.

Proof. Paths through u are a subset of paths through v, so the slope-1 envelopes coincide:
C1 = A1. With C0 >= A0, through_v's breakpoint A0 - C1 precedes P's breakpoint C0 - C1, so on
the middle segment through_v is already rising while P is still flat, giving slope -1, and 0
elsewhere. (Equivalently: if increasing d_u increases P, the new maximiser contains u, hence
v, hence is a through-v path, forcing through_v = P and f_v = 0.)

## Theorem (exactness of the domination split)

For each v let H_v = { u : some complete path contains both u and v, and some complete path
contains u but not v } (the *bypass set*). Then
    max_B f_v  is attained at a vertex with every incomparable coordinate at its upper end,
               every dominated coordinate (including d_v) at its lower end, and the H_v
               coordinates at some corner;
    min_B f_v  dually (incomparable low, dominated high).
Hence enumerating the 2^|H_v| corners of the bypass coordinates, with the remaining
coordinates pinned by Lemmas 1-2, yields the exact float range of v.

Proof. By the Corollary, an optimum lies at a vertex of B. The classification
{incomparable, dominated, bypass} is a partition of V: "comparable" (some common complete
path) splits into dominated and bypass by definition. At an optimal vertex, moving any
incomparable coordinate to its upper end (for the max; lower for the min) does not decrease
the objective by Lemma 1, and moving any dominated coordinate to its lower end (upper for the
min) does not decrease it by Lemma 2; both moves keep the point a vertex. So some optimal
vertex has the pinned pattern, and the split enumerates all such vertices.

## Complexity, and never-worse-than-exhaustive

Cost: sum over v of 2 * 2^|H_v ∩ interval-valued| crisp propagations, against 2^k for
exhaustive enumeration (k = number of interval-valued durations). One exhaustive sweep serves
every node simultaneously, so the production algorithm runs whichever of the two is cheaper
and is therefore never worse than exhaustive; the split's advantage is that its exponent is
the per-node reconvergent width, not the total interval count.

Measured: water 32-node network, all 32 durations interval — split 2,269,328 runs (exact),
exhaustive would need 2^32 = 4,294,967,296 (ratio 1,892, arithmetic); grid 5x5 all-interval
has |H_v| up to 23 of 25 and gets no speedup, consistent with NP-hardness of the general
problem (Chanas & Zielinski 2002).

## The series-parallel claim: REFUTED (2026-08-19)

An earlier Proposition 2 here claimed that bypass membership is an "N" pattern in the
reachability order, hence (by the Valdes-Tarjan-Lawler N-free characterisation) H_v = EMPTY
on two-terminal series-parallel DAGs, recovering SP-polynomiality of interval criticality.
Both steps are FALSE and the claim was removed from the chapter (2026-08-19 parity review).

Counterexample. The single diamond s -> {a, b} -> t is two-terminal SP and its order is
N-free. Yet s ∈ H_a: the complete path s-a-t contains both s and a, and s-b-t contains s but
not a. Likewise t ∈ H_a, so H_a = {s, t}. Verified against the shipped implementation:
interval_analyze_split with force_split performs 20 corner runs on this network
(2+8+8+2 over nodes s,a,b,t), where the refuted claim predicts 2 per node, 8 total. So
bypass membership does not imply an N pattern, and H_v is not empty on SP structure.

What fails underneath: Lemmas 1-2 pin only coordinates dominated in the u-towards-v
direction. The mirror case (every through-v path passes u, e.g. u = s above) is also
uniformly monotone — through_v then has slope 1 in d_u everywhere while P = max(C0, C1 + x),
so f_v is nonincreasing — but even adding that mirror lemma does not empty H_v on SP: in
s -> (a|b) -> m -> (c|d) -> t, coordinate a stands in none of the four directional relations
to c, yet f_c is INDEPENDENT of d_a (the series cut at m screens it: f_c = max(d_c,d_d) - d_c).
A true SP statement needs the mirror lemma plus a cut-node screening argument; neither is
derived here, so no SP, N-free, or polynomiality-recovery claim may appear in print. The VTL
citation itself is verified correct (SIAM J. Comput. 11(2):298-313, 1982) but currently
supports nothing in the chapter (bib entry retained, uncited).

What remains true: the exactness Theorem above is unaffected — enumerating a bypass
coordinate that happens to be monotone or independent is wasteful, never wrong. The diamond
relation survives only as: conditioning sets C (per join) and bypass sets H_v (per node) both
grow with reconvergent structure at different granularities, and elementwise containment
fails in both directions (chapter net: C = {1,3} while H_4 = {1,3,6,7,8}). A sharper
C-to-H_v statement is open.

## Scope notes

- Proven for the longest-path mode (classic floats). The shortest-path dual follows by the
  mirrored argument (swap max/min and the roles of the endpoints) but has not been re-derived
  line by line; do that before claiming it in print.
- Interval edge delays: handled by the subdivision reduction above; the implementation
  currently requires crisp edges and should either subdivide internally or state the
  restriction.
- Empirical certification: exact vs oracle-certified exhaustive margins on three nets
  (gaps 0 / 7.1e-15 / 0); on water k=32, 50,000 Monte Carlo configurations produced zero
  bound violations and attained every bound at every node (validation/cpm_v2/ logs).
