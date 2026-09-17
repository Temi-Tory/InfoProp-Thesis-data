from __future__ import annotations

import json
from pathlib import Path

OUTDIR = Path(__file__).resolve().parent
SHIFT = 100


def s(node: int) -> int:
    return node + SHIFT


# Unreduced multi-source / multi-sink benchmark DAG.
# The toolkit should perform the super-source / super-sink reduction internally.
# Node IDs are intentionally offset so the node-splitting transform used by
# NodeCapacitatedFlowModule does not collide with original node IDs.
LAYER_NODES = {
    1: [s(n) for n in [1, 2, 3, 4, 5]],
    2: [s(n) for n in [6, 7, 8, 9, 10, 11, 12, 13]],
    3: [s(n) for n in [14, 15, 16, 17, 18, 19]],
    4: [s(n) for n in [20, 21, 22, 23, 24, 25, 26, 27]],
    5: [s(n) for n in [28, 29, 30, 31, 32, 33]],
    6: [s(34), s(35)],
    7: [s(36)],
    8: [s(n) for n in [37, 38, 39, 40, 41, 42, 43]],
}

NODE_LABELS = {
    s(1): "origin_northwest",
    s(2): "origin_north",
    s(3): "origin_central",
    s(4): "origin_east",
    s(5): "origin_southwest",
    s(6): "hub_alpha",
    s(7): "hub_beta",
    s(8): "hub_gamma",
    s(9): "hub_delta",
    s(10): "hub_epsilon",
    s(11): "hub_zeta",
    s(12): "hub_eta",
    s(13): "hub_theta",
    s(14): "processing_A",
    s(15): "processing_B",
    s(16): "processing_C",
    s(17): "processing_D",
    s(18): "bypass_E",
    s(19): "bypass_F",
    s(20): "trunk_n1",
    s(21): "trunk_n2",
    s(22): "trunk_c1",
    s(23): "trunk_c2",
    s(24): "trunk_s1",
    s(25): "trunk_s2",
    s(26): "trunk_w1",
    s(27): "trunk_w2",
    s(28): "secondary_a",
    s(29): "secondary_b",
    s(30): "secondary_c",
    s(31): "secondary_d",
    s(32): "secondary_e",
    s(33): "secondary_f",
    s(34): "dispatch_gateway_west",
    s(35): "dispatch_gateway_east",
    s(36): "distribution_combiner",
    s(37): "sink_1",
    s(38): "sink_2",
    s(39): "sink_3",
    s(40): "sink_4",
    s(41): "sink_5",
    s(42): "sink_6",
    s(43): "sink_7",
}

EDGE_CAPACITIES: dict[tuple[int, int], float] = {}


def add(u: int, v: int, cap: float) -> None:
    if u >= v:
        raise ValueError(f"Edge ({u},{v}) violates DAG ordering.")
    key = (u, v)
    if key in EDGE_CAPACITIES:
        raise ValueError(f"Duplicate edge {key}")
    EDGE_CAPACITIES[key] = float(cap)


# Layer 1 -> Layer 2
for u, v, c in [
    (1, 6, 8), (1, 7, 7), (1, 8, 6), (1, 9, 5), (1, 18, 1),
    (2, 7, 8), (2, 8, 7), (2, 9, 6), (2, 10, 5), (2, 18, 1),
    (3, 9, 8), (3, 10, 7), (3, 11, 6), (3, 12, 5), (3, 19, 1),
    (4, 10, 8), (4, 11, 7), (4, 12, 6), (4, 13, 5), (4, 19, 1),
    (5, 6, 6), (5, 7, 5), (5, 12, 7), (5, 13, 8), (5, 18, 1), (5, 19, 1),
]:
    add(s(u), s(v), c)

# Layer 2 -> Layer 3
for u, v, c in [
    (6, 14, 3), (6, 16, 3), (6, 18, 2),
    (7, 14, 3), (7, 16, 3), (7, 18, 2),
    (8, 15, 3), (8, 16, 2), (8, 19, 2),
    (9, 15, 3), (9, 17, 3), (9, 18, 2),
    (10, 14, 2), (10, 17, 3), (10, 19, 2),
    (11, 15, 2), (11, 17, 2), (11, 19, 2),
    (12, 15, 3), (12, 19, 2),
    (13, 14, 2), (13, 18, 2), (13, 19, 3),
]:
    add(s(u), s(v), c)

# Lightweight bypasses from sources into weaker mid-network options
for u, v, c in [
    (1, 18, 1), (2, 18, 1), (3, 19, 1), (4, 19, 1), (5, 18, 1), (5, 19, 1),
]:
    # already added above, so skip duplicates here intentionally
    pass

# Layer 3 -> Layer 4
for u, v, c in [
    (14, 20, 3), (14, 21, 2), (14, 22, 1),
    (15, 21, 1), (15, 22, 3), (15, 23, 2),
    (16, 20, 4), (16, 22, 4),
    (17, 21, 4), (17, 23, 4),
    (18, 24, 2), (18, 25, 2), (18, 26, 1),
    (19, 25, 1), (19, 26, 2), (19, 27, 2),
]:
    add(s(u), s(v), c)

# Layer 4 -> Layer 5
for u, v, c in [
    (20, 28, 4), (20, 29, 3), (20, 30, 2),
    (21, 29, 4), (21, 30, 3), (21, 31, 2),
    (22, 30, 4), (22, 31, 3), (22, 32, 2),
    (23, 31, 4), (23, 32, 3), (23, 33, 2),
    (24, 32, 2), (24, 33, 2),
    (25, 32, 1), (25, 33, 2),
    (26, 28, 2), (26, 33, 2),
    (27, 29, 2), (27, 33, 2),
]:
    add(s(u), s(v), c)

# Layer 5 -> Layer 6 (paired dispatch gateways to encourage a richer min-cut story)
for u, v, c in [
    (28, 34, 4), (28, 35, 1),
    (29, 34, 3), (29, 35, 3),
    (30, 34, 2), (30, 35, 4),
    (31, 34, 4), (31, 35, 2),
    (32, 34, 3), (32, 35, 3),
    (33, 34, 1), (33, 35, 4),
]:
    add(s(u), s(v), c)

# Layer 6 -> Layer 7 (two equal parallel branches into a common downstream combiner)
for u, v, c in [
    (34, 36, 17),
    (35, 36, 17),
]:
    add(s(u), s(v), c)

# Layer 7 -> Layer 8 (fan-out from the common combiner to the true sinks)
for u, v, c in [
    (36, 37, 6), (36, 38, 6), (36, 39, 6), (36, 40, 6),
    (36, 41, 6), (36, 42, 6), (36, 43, 6),
]:
    add(s(u), s(v), c)

# Scale the early and middle layers upward so the late-stage parallel-branch region
# is the governing throughput bottleneck and can support a richer minimum-cut story.
PRE_LATTICE_SCALE = 2.0
for (u, v), cap in list(EDGE_CAPACITIES.items()):
    if v <= s(33):
        EDGE_CAPACITIES[(u, v)] = PRE_LATTICE_SCALE * cap

NODE_CAPACITIES = {
    s(14): 5.0,
    s(15): 5.0,
    s(16): 7.0,
    s(17): 7.0,
    s(18): 3.0,
    s(19): 3.0,
    s(34): 20.0,
    s(35): 20.0,
}

SOURCE_NODES = [s(n) for n in [1, 2, 3, 4, 5]]
SINK_NODES = [s(n) for n in [37, 38, 39, 40, 41, 42, 43]]


def write_edges_file(path: Path) -> None:
    lines = ["source,destination"]
    for u, v in sorted(EDGE_CAPACITIES):
        lines.append(f"{u},{v}")
    lines += [
        "",
        "# Flagship unreduced benchmark DAG for CapacityAnalysisKit.",
        "# Purpose: demonstrate the toolkit on a true multi-source / multi-sink network.",
        f"# Sources: {SOURCE_NODES}",
        f"# Sinks: {SINK_NODES}",
        "# Super-source / super-sink augmentation should be handled internally by the toolkit.",
    ]
    path.write_text("\n".join(lines), encoding="utf-8")


write_edges_file(OUTDIR / "network_flagship.edges")

edge_json = {
    "comment": (
        "Flagship unreduced benchmark DAG for CapacityAnalysisKit. Designed to contain "
        "multiple corridors, shared bottlenecks, a structurally important dispatch gateway, "
        "and several near-tie cut regions for rich exact analysis."
    ),
    "source_nodes": SOURCE_NODES,
    "sink_nodes": SINK_NODES,
    "edges": [
        {"source": u, "destination": v, "capacity": cap}
        for (u, v), cap in sorted(EDGE_CAPACITIES.items())
    ],
}
(OUTDIR / "edge_capacities_flagship.json").write_text(json.dumps(edge_json, indent=2), encoding="utf-8")

node_json = {
    "comment": (
        "Node capacities chosen so the node-capacitated solve binds at selected processing nodes, "
        "reducing throughput below the edge-only baseline while leaving the dispatch gateway non-binding."
    ),
    "nodes": [
        {"node": node, "capacity": capacity}
        for node, capacity in sorted(NODE_CAPACITIES.items())
    ],
}
(OUTDIR / "node_capacities_flagship.json").write_text(json.dumps(node_json, indent=2), encoding="utf-8")

metadata = {
    "comment": "Node labels and layer assignments for the unreduced flagship benchmark DAG.",
    "source_nodes": SOURCE_NODES,
    "sink_nodes": SINK_NODES,
    "layers": {str(layer): nodes for layer, nodes in LAYER_NODES.items()},
    "node_labels": {str(node): label for node, label in NODE_LABELS.items()},
}
(OUTDIR / "flagship_node_metadata.json").write_text(json.dumps(metadata, indent=2), encoding="utf-8")

print(f"Wrote {len(NODE_LABELS)} nodes and {len(EDGE_CAPACITIES)} directed edges to {OUTDIR}")
