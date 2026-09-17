# Speaker notes — pbox_talk.pdf (one section per slide, in plain words)

Jargon is translated inline the first time it appears, marked with →. The most-asked-about term first:

> **"Vacuous"** = a bound so wide it tells you nothing. If I say "the probability is somewhere
> between 0 and 1" — that's *true* (sound!) but useless. A vacuous p-box is the honest way of saying
> "I have no information", and the danger with the Fréchet operator is that on hard networks it can
> drift toward that. Sound-but-vacuous is the failure mode of *conservative* methods, the mirror image
> of wrong-but-confident, which is the failure mode of *naive* methods.

---

## Slide 1 — Title
"This talk is about one algorithm doing three jobs of increasing difficulty: exact reliability with
ordinary probabilities, exact reliability when you only know bounds, and bounded reliability when you
only partly know the distributions. The third one contains an open maths problem I'd genuinely like
help with — that's slide 11, and it's the real reason I'm giving this talk."

## Slide 2 — The problem, and why the obvious thing is wrong
The quantity we want, for every node in a network: the chance that *at least one working path* reaches
it from a supply source. There's a tempting local rule — multiply your way down the graph, combine
parents as if independent. The picture shows why it fails: both routes into the join pass through the
same fork. If the fork is dead, *both* routes are dead **together**. Treating them as independent
double-counts the good cases and you get 0.749 when the truth is 0.675. That's not a rounding issue —
it's a 7% overestimate of a reliability, i.e. exactly the kind of error that makes a safety case wrong
in the dangerous direction.

- → "signals independent": knowing one route works tells you nothing about the other. Untrue here,
  because they share the fork.

## Slide 3 — The fix: condition on the fork
The oldest trick in probability: if a shared thing is causing the correlation, *freeze it*. Split the
world into "fork works" and "fork doesn't", solve each simple world separately (inside each world the
routes really are independent), then average the two answers, weighted by how likely each world is.
That weighted average is the W·A + (1−W)·B everyone will see again later. The general version freezes a
small *set* of shared ancestors — you pay 2^(set size) sub-computations. Last bullet is positioning:
this is not a brand-new idea, it's Pearl's cutset conditioning, specialised — we condition *locally* at
each trouble spot instead of globally, and recurse.

- → "separating set / cutset": the smallest set of upstream nodes you must freeze so the routes stop
  sharing anything random.

## Slide 4 — Nesting: diamonds inside diamonds
Real networks have diamonds inside diamonds. The rule: solve inner ones first, store the answer as a
little lookup table ("if my fork is up, my join delivers with probability X; if down, Y"), and let
outer diamonds use that table instead of re-deriving the inner structure. The table on the right is a
*real machine trace* of this network, not an illustration. Two honesty points to say out loud: the
final answer agrees with brute-force path enumeration to 16 decimal places (i.e. exactly — that's
floating-point round-off, the smallest difference a computer can represent); and even on this toy the
caching matters — 68 sub-problems instead of 145.

- → "supernode": the stored lookup table standing in for a solved diamond.

## Slide 5 — What it costs, honestly
Two claims. Nice one: the cost isn't a vague big-O — you can *compute your bill before you run*,
because the freezing-sets are found before any enumeration. Humbling one: the scatter shows our cost
parameter against the size of the best competing exact method (a well-ordered BDD — think of it as a
compressed truth-table of the whole network). The points straddle the diagonal: sometimes we're
cheaper, sometimes they are, and both track the same underlying property of the network — its "width",
roughly how tangled its shared ancestry is. So we do **not** claim to beat exact competitors at their
own game. The value must come from what follows.

- → "treewidth/pathwidth": formal measures of that tangledness. Bigger width = every exact method
  suffers exponentially, ours included.
- → "sifted ROBDD": the competitor with its variable ordering optimised — i.e. we compare against the
  competitor at its best, not a strawman.

## Slide 6 — One recursion, three number types
The pivot slide. Everything so far is just adds, multiplies, and "1 minus". So you can run the *same*
algorithm with fancier kinds of number: plain probabilities; intervals ("somewhere between 0.75 and
0.85, that's all I know"); and p-boxes. A p-box is two CDF curves with the promise that the true
distribution lies between them — "partial knowledge of a distribution" made precise. The point of the
whole enterprise: real component data is often exactly this shape (sparse data, expert opinion,
manufacturer tolerance), and we'd rather carry that honesty through the computation than pretend a
point value.

## Slide 7 — Intervals: the easy case
The magic word is **monotone**: making any component more reliable can never *hurt* the network. So the
worst case of the whole network is every component at its worst, best case everything at its best — run
the algorithm twice and you have the *exact* range. No dependence subtleties survive. Two support
points: validated to machine precision, and the naive alternative (ignore the reconvergence) inflates
the range by up to 0.45 — nearly half the scale — so the diamond machinery is doing real work here too.
The closing line sets up the drama: intervals were free; p-boxes will not be.

- → "corner": the input setting where every component simultaneously takes its lower (or upper) bound.
- → "one-shot": the comparison counts the competitor's construction time. If you re-query one network
  thousands of times, their build cost amortises and could win — we say so.

## Slide 8 — Where p-boxes break
Same formula, W·A + (1−W)·B, but now the three ingredients are distributions, and A and B are
**dependent on each other** — both were computed from the same upstream components, so whatever those
truly are pushes A and B up or down *together*. Adding dependent things as if independent is the
classic sin of probability, and our first implementation committed it: it produced "distributions" with
more than 100% total probability (mass leak 0.34). Say the last bullet with feeling: a *plausible but
wrong* certified bound is worse than none — it launders your uncertainty into false confidence.

## Slide 9 — The correct operator
Plain-words version of the formula: "for each possible value the weight W could take, mix the two
branch distributions in that ratio; then take the envelope — the outer hull — over all values of W that
its own p-box allows." The one open ingredient is the **blend**: how the mixing handles the unknown
A–B dependence. Engineering footnote worth 15 seconds: results get clipped to [0,1] (a probability
can't leave [0,1], so clipping only ever *removes impossible values*, never truth), but the clip is
*guarded* — if the excursion is more than would-be rounding noise, the code refuses and raises an
error, so a future real bug can't hide inside the clamp.

## Slide 10 — The dilemma: provable vs tight
Two blends on the menu. **cvxF** assumes *nothing* about the dependence — its soundness is a classical
theorem from the 1990 literature (Fréchet–Hoeffding bounds), so it's bulletproof, but on hard networks
it can drift toward vacuous (see the definition at the top of these notes). **cvxP** uses one extra
physical fact — the branches can only move *together*, never oppositely, because both are monotone in
the same inputs — and is much tighter, has never once violated ground truth in testing… and has no
theorem. Paper policy: every "guaranteed" sentence in the manuscript rests on cvxF only; cvxP is
described as validated, proof pending. That's the honest split between what we *know* and what we
*believe with evidence*.

- → "comonotone": perfectly moving together — the extreme positive dependence.
- → "copula": maths jargon for "a full specification of how two random things co-move".

## Slide 11 — The open problem (the ask)
The literature covers three situations: independence; a *fully known* dependence; and *totally
unknown* dependence. Our situation — "positive, but otherwise unknown" — sits in between and has,
as far as a genuine search can establish, no theorem. The natural proof route (an ordering argument:
"more positively dependent ⇒ the blend can only widen in one direction") fails, and fails for a real
reason: with two uniform quantities, the independent and perfectly-dependent versions of the
combination produce distribution curves that *cross* — neither is uniformly on the safe side of the
other. So a proof needs a different idea, or the claim is false and there's a counterexample to find.
Either outcome is a publishable result — this is the slide where I'd love an argument to start.

- → "supermodular / Tchen ordering": the standard formal way of saying "more positively dependent
  than"; the tool that failed.

## Slide 12 — Sound is not tight
Two different virtues that must not be confused. **Sound** = the truth is always inside the band —
never wrong. **Tight** = the band is narrow — actually informative. We are sound *everywhere*, in
every regime tested, no exceptions. Tightness varies: on realistic high-reliability systems the band
pins answers to roughly ±10–20%; on the deliberately-nasty stress test (every component maximally
uncertain, deep reconvergence) it degrades to roughly ±30% — honest, but not decision-grade *at the
worst threshold*. Crucial nuance in the last line: "band" is the *worst* gap across all possible
questions; the two curves squeeze together at the ends of the scale — and real requirements ("is it
above 0.95?") live at the ends. Next slide is exactly that.

## Slide 13 — The payoff
The concrete deliverable: from *one* run, a certified statement like "the probability this node fails
its 0.95 requirement is between 0 and 12%" — and note it stays narrow (0.02!) even in the regime whose
overall band was 0.68, because 0.95 sits where the curves pinch. Comparators: Monte Carlo needs up to
~10,000 samples to *estimate* the same number, with statistical error and no guarantee; decision
diagrams simply have no route to it — they'd run the Monte Carlo too. Then the map makes it human: on
the Scottish medical drone network, the analysis names its most at-risk facility — Islay Hospital, an
island — reachable with probability between 56% and 72% under the acknowledged input uncertainty.
That interval *is* the decision-relevant answer: it says "this is where more redundancy or better data
buys the most".

## Slide 14 — Limitations and takeaways
Say the limitations without flinching — they're the credibility of everything before. Cost: p-box
precision is a dial, and turning it up is quadratic; big networks get intervals + sampling for now.
Imprecision is *not* a get-out-of-exponential-free card: same conditioning depth as the exact case.
And the cvxP proof is open. Then the three takeaways, one line each — recursion + local cutsets; no
free lunch on point values; intervals free; p-boxes = guaranteed distributional bounds nobody else
produces analytically, with one clean open problem.

## Slide 15 — Close
Leave the open problem on screen and stop talking. If the room engages with anything, it'll be this.

---

## Likely questions, one-line answers
- *"Why not just Monte Carlo everything?"* — MC estimates, never guarantees; and to even *plan* the
  sample size you need the answer you don't have. The p-box bound is analytic and certain.
- *"Is cvxP maybe just wrong?"* — Possibly! That's why no guaranteed claim rests on it. Zero violations
  across every test, but a crossing-curves obstruction blocks the obvious proof. Counterexample hunting
  is a legitimate project.
- *"Why did the old convolution bug matter if you fixed it?"* — Because it shows the failure mode is
  silent: the output *looked* like a fine p-box while leaking 34% mass. Hence the guarded clamp.
- *"Couldn't the BDD do intervals too?"* — Yes, by evaluating at both corners; that's exactly the
  comparison we ran (we're faster one-shot). What it can't do at all is the distributional bound.
- *"Does the interval trick (corners) work for p-boxes?"* — No: corners bound the *range*, but a p-box
  asks for the whole distribution of outcomes, and the branch dependence enters there.
