# IEEE RTS-24 — Flow case study, 2026-08-30 (updated with the net-injection rerun)

Source: MATPOWER `case24_ieee_rts.m` (fetched from the official MATPOWER
GitHub repository, 2026-08-30). Original system: IEEE Reliability Test
System, *IEEE Transactions on Power Apparatus and Systems*, Vol. 98, No. 6,
Nov./Dec. 1979, pp. 2047-2054 (Grigg et al. is the RTS-96 successor; the
MATPOWER case file traces to the 1979 original). Raw tables in
`rts24_raw_data.json`. 24 buses, **11** generator buses (33 generating
units — corrects the "10" in the first pass of this write-up, a miscount;
verified by direct enumeration of `generator.rows`' distinct `gen_bus`
values), 38 transmission lines (4 pairs double-circuit), 17 load buses,
slack bus 13.

## Orienting the mesh into a DAG

Unchanged from the first pass — see `orientation_log.txt`. DC power flow at
peak load, uniform-participation-factor dispatch (2850 MW total), slack bus
13. 24 nodes, 34 edges, no directed cycles remained, nothing dropped. Four
double-circuit line pairs combined into one edge each with summed capacity.

## Net-injection model (primary answer — closes both limitations below)

**Construction** (`orient_rts24.py`, net-injection section): every bus's net
injection = generator nameplate Pmax − local peak load. A super-source
(node 0) gets an edge to every net-**export** bus (net injection > 0),
capacity = that net injection; every net-**import** bus (net injection < 0)
gets an edge to a super-sink (node 25), capacity = its net load. A bus with
both local generation and local load appears **once**, under its net sign —
e.g. bus 15 has 215 MW of local generation but 317 MW of local load, so it
nets to an **import** bus (−102 MW) despite having a generator. The 34 line
edges are unchanged; 0 and 25 are the only additions, and become the graph's
only zero-in-degree / zero-out-degree nodes once added (every former
structural source/sink bus — 7, 21, 22, 23 / 4, 5, 6, 8, 19 — gains the
opposite-direction S/T edge). Full per-bus table: `net_injection_log.txt`.

| | MW |
|---|---|
| Total system peak demand (all 17 load buses) | 2850.0 |
| Total generator nameplate capacity (33 units) | 3405.0 |
| Sum of positive net injections (9 export buses, S-side) | 2162.0 |
| Sum of negative net injections (11 import buses, T-side = net import demand) | 1607.0 |
| Locally self-served demand (nets out at export buses, never touches the network) | 1243.0 |

**Result** (`run_rts24_netinjection_analysis.jl`, direct framework call —
server not running this session, see note below):

- **Deliverable throughput = 1607.0 MVA = 100% of net import demand**, i.e.
  **100% of total system peak demand is met**: 1243 MW self-served locally
  (unconditional, as long as each export bus's own generation covers its own
  load) + 1607 MW delivered over the network = 2850 MW = the whole system.
  This is the same number under generator-nameplate-limited **and**
  unconstrained-generation capacities — neither generation nor transmission
  is actually the constraint here; total available capacity on both sides
  exceeds total demand, so the max-flow saturates at the only thing it
  structurally can't exceed: the import side's own demand ceiling.
- **Binding cut**: exactly the 11 bus→T (demand-side) edges, capacity =
  1607.0 MVA. This is real and correct, not a placeholder: it says every
  net-import bus is fully served, and no line or generator is what's
  stopping any of them from getting more. It is a *trivial* cut in the
  sense that it's always going to be the sink side once nothing upstream
  binds — see the headroom analysis below for the informative version of
  "how close is this system to a real constraint".
- **Single points of failure**: none (`identify_spof_nodes` returns empty).
- **Single-line and single-generator failure rankings: both empty.** Not a
  gap — a real finding, confirmed by the same oracle-validated machinery
  used across this whole corpus: every line and every generator has slack
  in the max-flow that achieves 1607 MVA, so removing any *one* of them,
  alone, does not reduce total deliverable throughput at all. The system is
  fully N-1 secure for **aggregate throughput** at these nameplate/thermal-
  rating capacity levels. (This does not mean N-1 secure in every
  operational sense — e.g. a specific remaining path could still overload
  in a real redispatch; that's outside what a max-flow model captures, and
  is exactly the kind of caveat the framework's own scope already implies.)
- **Real-asset headroom** (capacity − flow on the actual max-flow found;
  since generation/transmission have slack overall, *which* specific edges
  end up saturated is one valid optimal allocation among possibly several —
  not necessarily how a real merit-order dispatch would allocate it):
  - Least-headroom **generators**: bus 1 (84.0/84.0, headroom 0), bus 2
    (95.0/95.0, headroom 0), bus 13 (326.0/326.0, headroom 0), bus 16
    (55.0/55.0, headroom 0), bus 7 (175.0 cap/171.0 flow, headroom 4.0).
    The three big exporters (21, 22, 23 — 400/300/660 MW nameplate) are not
    near their caps in this allocation; the smaller export buses are used
    to their fullest first. **Confirmed structural, not an artifact of one
    arbitrary max-flow solution**: the server-side `min_cut_analysis.
    edges_in_every_cut` (below) independently reports exactly these same
    four S-edges — `(0,1)`, `(0,2)`, `(0,13)`, `(0,16)` — as present in
    *every* optimal min-cut, i.e. generators 1, 2, 13, 16 are saturated in
    every valid max-flow achieving 1607 MVA, not just the one this
    particular solve happened to find.
  - Least-headroom **line**: `(7,8)`, capacity 175.0, flow 171.0, headroom
    4.0 — the closest real transmission asset to becoming a constraint.
    Next closest: `(10,6)` headroom 73.0, `(2,4)` headroom 101.0.
- **Upgrade-threshold framing changes**: since the binding cut is
  demand-side, "upgrade this line/generator by X to hit +10% flow" isn't a
  meaningful question here (there's nothing to upgrade — nothing upstream
  is capacity-constrained). The two limitations this rerun closes:
  1. **Deliverable throughput vs. total system demand** — now directly
     answered: 100% (2850/2850 MW, split 1243 self-served + 1607
     delivered), not the earlier structural-subset placeholder.
  2. **Generator failures as node removals** — now directly answered: the
     single-edge-failure ranking already covers S→bus edges by
     construction (a generator failure literally *is* one), and the answer
     is "none is individually critical to aggregate throughput" — a real,
     specific, checkable result, not a "not run" placeholder.

## Structural-subset model (first pass, kept for contrast — see note)

Kept as-is (`rts24.EDGES` / `rts24-capacities.json`, `run_rts24_analysis.jl`,
unchanged), since it still answers a different, also-legitimate question:
"how much can flow between buses with **zero local demand** and buses with
**zero local generation**", ignoring net-injection accounting at mixed
buses. Not the headline number any more — the net-injection model above is
the correct treatment for "deliverable throughput against total system
demand" — but left in place, unmodified, as the smaller and more
transmission-constrained of the two questions:

- Edge capacities only, unconstrained generation: **2725 MVA**.
- Generator-nameplate-limited (node-capacitated): **1135 MVA**.
- Binding cut (9 lines: `(3,1)`, `(7,8)`, `(9,4)`, `(9,8)`, `(10,5)`,
  `(10,6)`, `(10,8)` each 175 MVA, plus `(16,19)` 500 MVA, `(23,20)` 1000
  MVA) — a genuine transmission bottleneck, unlike the net-injection
  model's trivial demand-side cut, and the more visually interesting one if
  a line-cut figure is wanted (see "For the figure" below).
- Five most damaging single-line failures: `(20,19)` and `(23,20)` (drop
  1000 MVA each), `(16,19)` (drop 500), `(3,1)` and `(7,8)` (drop 175 each).

## For the figure

Two different cuts are available, answering two different questions —
picking depends on what the figure is meant to show:

- **Net-injection model's actual binding cut** (the literal answer to "what
  currently limits RTS-24's deliverable throughput"): the 11 bus→T edges at
  buses 3, 4, 5, 6, 8, 9, 10, 14, 15, 19, 20 — i.e., every import bus, fully
  saturated. As a figure this reads as "every demand node is maxed out,
  nothing upstream is" — correct, but it's a statement about every sink at
  once, not a cut *through* the network interior, so it may not render as
  an interesting mid-network line.
- **Structural-subset model's binding cut** (visually the more informative
  transmission bottleneck, unchanged from the first pass): 9 lines —
  `(3,1)`, `(7,8)`, `(9,4)`, `(9,8)`, `(10,5)`, `(10,6)`, `(10,8)` (175 MVA
  each), `(16,19)` (500 MVA), `(23,20)` (1000 MVA, a double-circuit pair).
  This is the one that looks like a real min-cut through the middle of
  `rts24.EDGES`'s topology, in the PSPLIB figure style.
- If a third option is wanted: the **closest-to-binding real assets** in
  the net-injection model — line `(7,8)` (4.0 MVA headroom) and generators
  at buses 1, 2, 13, 16 (0 headroom each) — could be highlighted instead of
  a formal cut, to show "here's where the system would bind next if demand
  grew," which the trivial demand-side cut can't show on its own.

## On λ (edge connectivity) and κ (node connectivity) — decided not to change

Asked whether to restrict `GlobalConnectivityModule.jl`'s search to declared
source/sink pairs (which would give a non-degenerate, non-zero λ/κ for
RTS-24 and the rest of the corpus). Checked the module's own documentation
(`FlowCapacity/README.md` §6.9) before touching anything, per this
project's own discipline of reading the domain material first rather than
inferring intent from the code alone: it explicitly documents `lambda`/
`kappa` as global directed connectivity **"exact directed edge/node
connectivity"** over the whole graph, with `edge_connectivity`/
`node_connectivity` each documented at `O(V)` solver calls — a complexity
that only matches searching over every node, not a restricted source/sink
subset. `source_nodes`/`sink_nodes` are accepted and validated purely for
the framework's standard call contract, not to scope this particular
search.

Given that, **0 on any DAG with a genuine sink is the mathematically
correct value for this metric as documented and implemented** — not a bug.
Any DAG has at least one zero-out-degree node by definition of being
acyclic, and "global connectivity over every ordered pair" is trivially 0
at that node regardless of how carefully the rest of the algorithm is
implemented. Restricting the search to declared source/sink pairs would
compute a *different*, genuinely useful metric (multi-terminal
source-to-sink connectivity) — but that's a new metric under a new name,
not a fix to this one, and changing `GlobalConnectivityModule.jl`'s
existing behavior in place would silently break its own documented
contract and its existing (oracle-validated) regression coverage's meaning.
**Not changed.** `FINDINGS.md` updated with this more definitive
conclusion, replacing the earlier "design-intent question, needs your
call" framing — it's resolved now, just not in the direction of a fix. No
corpus rerun of λ/κ follows from this, since nothing changed; the existing
corpus values (all 0, `flow_validation_extended_summary.csv`) already are
the correct answer to the metric as documented.

A **separate, real bug** surfaced while testing this on RTS-24's net-
injection model regardless (0-indexed: super-source id 0): fixed, see
"A real bug found and fixed" below — unrelated to the λ/κ question, purely
an internal ID-collision defect.

## Known limitations, now resolved

~~1. Deliverable throughput vs. total system demand~~ — resolved by the
net-injection model above.
~~2. Generator failures~~ — resolved by the net-injection model above (S→bus
edge failures ARE generator failures; ranking is empty, which is itself the
answer).

Remaining, genuinely open: this is a **peak-load, single-snapshot** DC
power flow — no time-varying load, no N-1 contingency redispatch (a real
grid operator would redispatch generation after a line trip; this model
just recomputes max-flow on the same fixed topology), no reactive power /
voltage constraints (DC flow only). All pre-existing, documented framing
choices, not new gaps from this rerun.

## Two real bugs found and fixed by this case study

**1. `build_node_split_graph` node-ID collision** (first pass) — see
`FINDINGS.md` §1. Unchanged, still fixed, still verified.

**2. `GlobalConnectivityModule.jl` internal remap-ID collision on a
0-indexed graph** (this rerun) — `node_connectivity`'s
`_remap_for_node_connectivity` used **hardcoded** sentinel node
IDs (`-1`, `-3`) for its own internal source/sink remapping, on top of an
*outer* super-sink ID (`_super_sink_id` = `minimum(nodes) - 1`) computed by
its caller. When the net-injection model's super-source is node **0** (the
natural choice, and what this rerun uses), the outer super-sink lands
exactly on `-1` — colliding with the inner hardcoded `-1`. Fixed: the inner
sentinel IDs are now derived from the call's own node range
(`minimum(nodes) - 1`, `minimum(nodes) - 2`, overflow-checked) instead of
fixed constants, so they can never collide with a real (or outer-synthetic)
node ID regardless of numbering — the same "offset from the real range,
not a magic number" fix pattern already used for bug 1. Verified: (a) a
minimal 0-indexed 4-node diamond that previously threw now runs cleanly
(returns λ=κ=0, the mathematically correct — if degenerate, see above —
value for that graph's global connectivity, not a crash); (b)
`run_flow_validation_extended.jl` re-run in full on all 12 corpus
networks — identical results before and after (water=48.0, grid-graph-5x5=
14.0, psplib-j301_1=1.0, all λ=0 as before, all still PASS) — zero
regression, since this only changes internal IDs that already worked for
every network with `minimum(node ID) >= 1`.

## Reproducing / extending

```bash
python orient_rts24.py                                       # rts24*.EDGES + capacities + net_injection_log.txt
julia --project=InfoPropFrmwrk run_rts24_analysis.jl               # structural-subset model (first pass)
julia --project=InfoPropFrmwrk run_rts24_netinjection_analysis.jl  # net-injection model (this rerun, primary numbers)
```

## Server-side run — done (literal JSON, for the interface)

Once the user started the server themselves, `POST /flow-analysis` was
called directly against `rts24-netinjection.EDGES` +
`rts24-netinjection-capacities.json` via `networkPath` pointed at the
`rts24/` folder — no `/upload` step needed, matching the established
`resolve_network_file_path` behaviour. Request/response saved verbatim:
`rts24_netinjection_server_request.json` / `rts24_netinjection_server_response.json`
(34.5 KB). Exact match to the direct-framework numbers above: `flow.max_flow
= 1607.0`, the same 11-edge demand-side min cut, the same empty
single-line/single-generator failure rankings (`failure_impact.
single_edge_failures` contains only the 11 bus→T edges), `global_
connectivity.edge_connectivity.lambda = 0` / `node_connectivity.kappa = 0`
(consistent with the "not a bug" conclusion above), `structure.spof_nodes =
[]`. `computation_time` reported by the server: 12.0s (first call on this
process — JIT/precompilation cost, not a steady-state timing; see this
repo's own warm-vs-cold timing convention elsewhere if a timed figure is
wanted). One thing the server-side run adds that the direct call didn't
surface on its own: `min_cut_analysis.edges_in_every_cut` = the four S-edges
to buses 1, 2, 13, 16 — confirming those four generators are saturated in
*every* optimal max-flow, not just the allocation this session's direct
call happened to find (folded into the headroom section above).

Server-side run for the first-pass structural-subset model
(`rts24.EDGES`/`rts24-capacities.json`) was **not** repeated — the direct-
framework numbers for that model are unchanged from the first pass and
weren't in question here.
