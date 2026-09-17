# Flow chapter — findings from validation, 2026-08-30

Three real, precise findings surfaced while validating (not from a
synthetic test — all found while running the real corpus and the RTS-24
case study). Two fixed; one investigated and resolved as "not a bug,"
documented below rather than changed.

## 1. Fixed: `build_node_split_graph` node-ID collision on partial node capacities

**Symptom**: `ArgumentError: Node ID collision in split graph...` — thrown
whenever a *subset* (not all) of a network's nodes carry a node capacity and
the node IDs are small/sequential (1..N). First hit on IEEE RTS-24 (**11**
of 24 buses have a generator, hence a node capacity — corrects "10" in the
original write-up here, a miscount; see `rts24/RESULTS.md`); never surfaced
in this
session's earlier corpus validation because every one of those networks
happened to give *every* node a capacity in the generated test data.

**Root cause**: `NodeCapacitatedFlowModule.jl`'s split-graph construction
assigned synthetic "in"/"out" IDs to a capacitated node `v` as `v_in=2v`,
`v_out=2v+1`. For a graph with nodes 1..N, this only avoids collision with
*unsplit* nodes' own (unchanged) IDs when either (a) every node is split, or
(b) the ID range is sparse enough that `2v`/`2v+1` never lands on another
real ID. Neither holds for a typical small network with node capacities on
some but not all nodes.

**Is partial node-capacity coverage actually a supported, intended case, or
an edge case?** Checked against the Network Model chapter
(`Complex_Processes_Chapter.tex`) before concluding anything, per the
project's own "read the chapter first" discipline — initially skipped that
step and was corrected mid-investigation. The chapter is explicit: *"Flow
capacity inputs are given in one file as a list of edge records... with an
**optional** list of node capacities... Unconstrained capacity is written
with an infinity token."* A node without a stated capacity is documented,
intended semantics for infinite/unconstrained, not an omission — checked the
code matches (an unsplit node keeps its original ID and no internal
capacity-limiting edge is added, exactly implementing "unconstrained"). So
this is a real bug in a normal, chapter-documented use case, not a design
question about whether partial coverage is valid.

**Fix** (`InfoPropFrmwrk/src/Algorithms/FlowCapacity/NodeCapacitatedFlowModule.jl`):
replaced the multiplicative `2v`/`2v+1` scheme with an offset-based one —
`_split_id_map` computes `M = maximum(all node IDs)` once, then assigns each
split node a consecutive `(M+2i-1, M+2i)` pair in sorted order. Every
synthetic ID lands strictly above every real ID, so collision with an
unsplit node is impossible, and each split node's own pair is unique, so
split-vs-split collision is impossible too — correct regardless of how
dense or small the original ID range is. `_detect_collisions` kept as an
explicit (now mathematically unreachable, but cheap) sanity assertion rather
than removed. The synthetic IDs were never part of the public contract —
callers translate through `NodeSplitGraph`'s own mapping dicts, not by
re-deriving the formula — so this is behavior-preserving for every case that
already worked.

**Verified**: RTS-24's node-capacitated flow, previously throwing, now
succeeds (1135 MVA vs. 2725 MVA edge-only — generator limits are the real
binding constraint). Re-ran `run_flow_validation_extended.jl` item 9 on
every previously-passing network (water, KarlNetwork, grid-graph-5x5,
psplib-j301_1) — identical results before and after, zero regressions.

## 2. Resolved (not a bug): global edge/node connectivity (λ/κ) is always 0 on a DAG

**Update, 2026-08-30**: this was originally flagged below as a "design-
intent question, needs your call." Revisited with the explicit go-ahead to
change it if warranted (RTS-24 net-injection rerun). Checked
`FlowCapacity/README.md` §6.9 before touching any code, per this project's
own "read the domain material first" discipline: it documents
`edge_connectivity`/`node_connectivity` as **"exact directed edge/node
connectivity"** at `O(V)` solver calls each — a complexity that only
matches a search over every node, not a search restricted to declared
source/sink pairs. So `source_nodes`/`sink_nodes` being accepted and
validated but not used to scope the search (the observation the "flagged"
note below was originally based on) is not an oversight — it's consistent
with the documented, intended definition: connectivity over the whole
graph, source/sink lists only enforced for the framework's standard call
contract. Under that definition, 0 on any DAG with a real sink is
**mathematically correct**, not a bug — every DAG has a zero-out-degree
node by definition of being acyclic, and global connectivity over every
ordered pair is trivially 0 there no matter how the rest of the algorithm
is implemented. **Decision: not changed.** A genuinely useful "source set
to sink set" connectivity metric would be a legitimately different
computation under a new name, not a fix to this one — out of scope here.
Full account and the RTS-24-specific numbers: `rts24/RESULTS.md`.

A separate, real bug *was* found and fixed while exercising this on
RTS-24's 0-indexed net-injection model — see finding 3 below; unrelated to
the always-0 question, purely an internal ID-collision defect.

### Original flag (2026-08-30, superseded above; kept for the record)

**Symptom**: every network in the corpus (12 of 12) reports
`edge_connectivity().lambda = 0`, at an "achieving" source/sink pair with no
apparent relationship to the network's actual source/sink structure.

**Root cause**: `GlobalConnectivityModule.jl`'s `edge_connectivity` searches
over *every node in the graph* as a candidate source (`for s in
sorted_nodes`), not just the declared source nodes, looking for the global
minimum unit-capacity max-flow to a super-sink over all other nodes. Any
node with zero out-degree — which is any sink, and every DAG has at least
one — trivially achieves λ=0 (it has no outgoing capacity to send flow
anywhere). The global minimum over all nodes is therefore always 0 for any
DAG with a genuine sink, which is every DAG this framework analyses. Verified
independently: recomputed λ for the achieving pair via GraphsFlows.jl on a
plain unit-capacity graph, confirmed 0 in every case — the framework's own
number is arithmetically correct for what it's currently defined to compute;
the definition itself doesn't produce a useful value for a DAG.

**Not fixed** — this is a design-intent question, not an implementation bug
the way the node-split issue was: should "global" connectivity restrict the
search to declared source→sink pairs, or to pairs where the sink is actually
reachable from the source, rather than all ordered pairs? Either change
alters what the metric means, and this exact metric already ships in the
front end as "Edge connectivity λ" / "Node connectivity κ" stat tiles
(`flow-bottlenecks.page.ts`) built earlier this session — a decision on
intended semantics affects both the thesis's own reported numbers and that
already-shipped UI copy, so it needs your call, not mine. Per your own
note: this is presumably why the chapter doesn't currently discuss this
metric as a headline claim — worth a footnote acknowledging the degenerate
value on a DAG, at minimum.

## 3. Fixed: `GlobalConnectivityModule.jl` internal remap-ID collision on a 0-indexed graph

**Symptom**: `ArgumentError: Node IDs -1 or -3 are reserved for internal
remapping in node_connectivity...` — thrown when a graph's minimum node ID
is 0 (or −2). Hit building the RTS-24 net-injection model, whose
super-source is node 0 (the natural, minimal choice).

**Root cause**: `node_connectivity` computes an *outer* super-sink ID via
`_super_sink_id` = `minimum(nodes) - 1`, then calls
`_remap_for_node_connectivity`, which used **hardcoded** inner sentinel IDs
(`-1` for its remapped source, `-3` for its remapped sink) for a second,
separate internal remapping. When the caller's minimum node ID is 0, the
outer super-sink lands exactly on `-1` — colliding with the inner
hardcoded `-1`. Unrelated to finding 2 above (that's about what the metric
means; this is a plain internal ID clash) and unrelated to finding 1 (a
different module, a different synthetic-ID scheme) — same *family* of bug,
though: a hardcoded synthetic ID assumed "small/negative enough to never be
real," true for every 1-indexed graph this session had tested against
until a 0-indexed one showed up.

**Fix** (`InfoPropFrmwrk/src/Algorithms/FlowCapacity/GlobalConnectivityModule.jl`,
`_remap_for_node_connectivity`): inner sentinel IDs are now derived from
the call's own node range (`minimum(nodes) - 1`, `minimum(nodes) - 2`,
`Base.checked_sub`-guarded against underflow) instead of fixed constants —
the same "offset from the real range, not a magic number" pattern already
used for finding 1's fix. Provably collision-free: both derived IDs are
strictly less than every node in the augmented graph (which already
includes the outer super-sink by the time this function runs), by
construction of `minimum(...)`.

**Verified**: (a) a minimal 0-indexed 4-node diamond (`0->1,0->2,1->3,2->3`)
that previously threw now runs cleanly, returning λ=κ=0 — the correct
value per finding 2's definition, not a crash; (b)
`run_flow_validation_extended.jl` re-run in full on all 12 corpus
networks — identical results before and after (water=48.0,
grid-graph-5x5=14.0, psplib-j301_1=1.0, all λ=0 as before) — zero
regression, since every existing corpus network has minimum node ID ≥ 1
and was never exercising the collision. Full account: `rts24/RESULTS.md`.

## Bibliography entries needed (per the Flow requirements doc's own section 6 ask)

- **Grigg, C., et al. (1999).** "The IEEE Reliability Test System-1996. A
  report prepared by the Reliability Test System Task Force of the
  Application of Probability Methods Subcommittee." *IEEE Transactions on
  Power Systems*, 14(3), 1010-1020. — RTS-96, the successor Grigg et al.
  citation the requirements doc names.
- **The original RTS the MATPOWER case file traces to**: IEEE Reliability
  Test System, *IEEE Transactions on Power Apparatus and Systems*, Vol. 98,
  No. 6, Nov./Dec. 1979, pp. 2047-2054 — worth citing directly alongside
  Grigg 1999 since the MATPOWER case file's own header cites this one, not
  only the 1996/99 successor.
- **MATPOWER** itself, as the data source actually used: Zimmerman, R. D.,
  Murillo-Sánchez, C. E., & Thomas, R. J. (2011). "MATPOWER: Steady-State
  Operations, Planning, and Analysis Tools for Power Systems Research and
  Education." *IEEE Transactions on Power Systems*, 26(1), 12-19. Data file:
  `data/case24_ieee_rts.m`, https://github.com/MATPOWER/matpower.
  Attribution inside the file: case data provided by Bruce Wollenberg
  (Georgia Tech Power Systems Control and Automation Laboratory).
- **DIMACS / genrmf benchmark family**: Goldberg, A. V., Johnson, D. S., &
  McGeoch, C. C. (Eds.). (1993). *Network Flows and Matching: First DIMACS
  Implementation Challenge*. DIMACS Series in Discrete Mathematics and
  Theoretical Computer Science, Vol. 12. American Mathematical Society. —
  note in the citing text that the instances generated here
  (`generate_genrmf_dag.py`) are a DAG-respecting *variant* of the genrmf
  mesh generator's topology (every edge forced forward so the result is
  acyclic), not the literal genrmf binary's own output — the requirements
  doc itself anticipated this ("record that this is a different instance
  from the published one").
- **GraphsFlows.jl**, used as the independent oracle throughout: Besançon,
  M. et al., `GraphsFlows.jl` (Julia package), https://github.com/JuliaGraphs/GraphsFlows.jl.
