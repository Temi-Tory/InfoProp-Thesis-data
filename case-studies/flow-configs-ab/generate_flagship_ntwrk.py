"""
Generator for flagship_ntwrk scenario package.

Config A and B share one topology (including bypass edge 132->140).
Scenario files differ by inputs (capacity/probability/CPM), not graph shape.

Run from the flagship_ntwrk folder or any path.
"""
import json
import pathlib
import hashlib
import random
import argparse

# ---------------------------------------------------------------------------
# Root paths
# ---------------------------------------------------------------------------
THIS_DIR = pathlib.Path(__file__).parent
REF_DIR = THIS_DIR.parent / "flagship"

# ---------------------------------------------------------------------------
# Load reference data
# ---------------------------------------------------------------------------
with open(REF_DIR / "edge_capacities_flagship.json") as f:
    ref_caps = json.load(f)

with open(REF_DIR / "node_capacities_flagship.json") as f:
    ref_node_caps = json.load(f)

SOURCE_NODES = [int(n) for n in ref_caps["source_nodes"]]
SINK_NODES   = [int(n) for n in ref_caps["sink_nodes"]]

# Build base edge capacity dict
base_edge_caps: dict[tuple[int,int], float] = {}
BASE_EDGES: list[tuple[int,int]] = []
for entry in ref_caps["edges"]:
    e = (int(entry["source"]), int(entry["destination"]))
    BASE_EDGES.append(e)
    base_edge_caps[e] = float(entry["capacity"])

# Node capacities
base_node_caps: dict[int, float] = {
    int(n["node"]): float(n["capacity"]) for n in ref_node_caps["nodes"]
}

# Config A adds bypass edge
BYPASS_EDGE = (132, 140)
BYPASS_CAP  = 3.0

# Config B boosts feeder edges into gateways 134/135
CONFIG_B_BOOSTS: dict[tuple[int,int], float] = {
    (128, 134): 5.0, (128, 135): 2.0,
    (129, 134): 4.0, (129, 135): 4.0,
    (130, 134): 3.0, (130, 135): 5.0,
    (131, 134): 5.0, (131, 135): 3.0,
    (132, 134): 4.0, (132, 135): 4.0,
    (133, 134): 2.0, (133, 135): 5.0,
}

# ---------------------------------------------------------------------------
# Node label / layer assignment (from flagship_node_metadata.json)
# ---------------------------------------------------------------------------
with open(REF_DIR / "flagship_node_metadata.json") as f:
    meta = json.load(f)

NODE_LABELS: dict[int, str] = {int(k): str(v) for k, v in meta["node_labels"].items()}
LAYERS: dict[int, list[int]] = {int(k): [int(n) for n in v] for k, v in meta["layers"].items()}

ALL_NODES = sorted(set(u for e in BASE_EDGES for u in e))

# Node -> layer index
node_layer: dict[int, int] = {}
for layer_idx, nodes in LAYERS.items():
    for n in nodes:
        node_layer[n] = layer_idx

# ---------------------------------------------------------------------------
# Deterministic random values (seeded by node/edge identity)
# ---------------------------------------------------------------------------
def _seed(s: str) -> int:
    return int(hashlib.md5(s.encode()).hexdigest()[:8], 16)

def _link_prob(u: int, v: int, base: float = 0.87, spread: float = 0.10) -> float:
    rng = random.Random(_seed(f"lp_{u}_{v}"))
    return round(base + rng.uniform(0, spread), 4)

def _node_prior(n: int, base: float = 0.875, spread: float = 0.09) -> float:
    rng = random.Random(_seed(f"np_{n}"))
    return round(base + rng.uniform(0, spread), 4)

def _edge_delay(u: int, v: int, base: float = 1.0, spread: float = 0.5) -> float:
    # longer delay for deeper transitions
    depth = node_layer.get(v, 5) * 0.4
    rng = random.Random(_seed(f"ed_{u}_{v}"))
    return round(base + depth + rng.uniform(0, spread), 4)

def _work_unit(u: int, v: int) -> float:
    rng = random.Random(_seed(f"wu_{u}_{v}"))
    return round(40.0 + rng.uniform(0, 40.0), 4)

# ---------------------------------------------------------------------------
# File format builders
# ---------------------------------------------------------------------------

def edges_file_content(edges: list[tuple[int,int]]) -> str:
    lines = ["source,destination"]
    for u, v in edges:
        lines.append(f"{u},{v}")
    return "\n".join(lines) + "\n"


def capacities_json(
    edges: list[tuple[int,int]],
    edge_caps: dict[tuple[int,int], float],
    node_caps: dict[int, float],
    scenario_intent: str,
    description: str,
) -> dict:
    edge_dict = {f"({u},{v})": edge_caps[(u, v)] for u, v in edges}
    node_dict = {str(n): c for n, c in node_caps.items()}
    return {
        "scenario_intent": scenario_intent,
        "network_type": "capacity_flow",
        "data_type": "Float64",
        "target_nodes": SINK_NODES,
        "capacities": {
            "nodes": node_dict,
            "edges": edge_dict,
        },
        "description": description,
        "generation_info": {
            "total_nodes": len(ALL_NODES),
            "total_edges": len(edges),
            "generator": "generate_flagship_ntwrk.py",
        },
    }


def linkprobs_json(
    edges: list[tuple[int,int]],
    scenario_intent: str,
    description: str,
) -> dict:
    links = {f"({u},{v})": _link_prob(u, v) for u, v in edges}
    return {
        "scenario_intent": scenario_intent,
        "links": links,
        "description": description,
    }


def nodepriors_json(
    nodes: list[int],
    scenario_intent: str,
) -> dict:
    node_dict = {str(n): _node_prior(n) for n in nodes}
    return {
        "scenario_intent": scenario_intent,
        "nodes": node_dict,
    }


def cpm_json(
    edges: list[tuple[int,int]],
    scenario_intent: str,
    description: str,
) -> dict:
    delays = {f"({u},{v})": _edge_delay(u, v) for u, v in edges}
    work   = {f"({u},{v})": _work_unit(u, v) for u, v in edges}
    return {
        "scenario_intent": scenario_intent,
        "time_analysis": {
            "edge_delays": delays,
            "edge_work_units": work,
        },
        "description": description,
    }


def mappings_json(
    scenario: str,
    edge_additions: list[tuple[int,int]],
    capacity_changes: dict[tuple[int,int], float],
) -> dict:
    return {
        "scenario": scenario,
        "node_labels": NODE_LABELS,
        "layers": {str(k): v for k, v in LAYERS.items()},
        "source_nodes": SOURCE_NODES,
        "sink_nodes": SINK_NODES,
        "topology_changes": {
            "edge_additions": [[u, v] for u, v in edge_additions],
        },
        "capacity_changes": {
            f"({u},{v})": c for (u, v), c in capacity_changes.items()
        },
    }


# ---------------------------------------------------------------------------
# Build configs
# ---------------------------------------------------------------------------

# Config A: base + bypass
config_a_edges = BASE_EDGES + [BYPASS_EDGE]
config_a_edge_caps = {**base_edge_caps, BYPASS_EDGE: BYPASS_CAP}

# Config B: same topology, different capacities
config_b_edges = config_a_edges  # same edges
config_b_edge_caps = {**config_a_edge_caps, **CONFIG_B_BOOSTS}

# Config B capacity changes relative to Config A
config_b_changes = {**{BYPASS_EDGE: BYPASS_CAP}, **CONFIG_B_BOOSTS}

# ---------------------------------------------------------------------------
# Write files
# ---------------------------------------------------------------------------

def write(path: pathlib.Path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    if isinstance(data, str):
        path.write_text(data, encoding="utf-8")
    else:
        path.write_text(json.dumps(data, indent=2), encoding="utf-8")
    print(f"  wrote {path.relative_to(THIS_DIR)}")


parser = argparse.ArgumentParser(
    description="Generate flagship_ntwrk scenario package."
)
parser.add_argument(
    "--write-scenario-edges",
    action="store_true",
    help="Also write per-scenario .EDGES files (use only for divergent topology scenarios).",
)
args = parser.parse_args()

print("Generating flagship_ntwrk files...")

# Shared topology for both scenarios: include bypass in the single base .EDGES.
write(THIS_DIR / "flagship.EDGES", edges_file_content(config_a_edges))

# Root: metadata
metadata_doc = {
    "node_labels": NODE_LABELS,
    "layers": {str(k): v for k, v in LAYERS.items()},
    "source_nodes": SOURCE_NODES,
    "sink_nodes": SINK_NODES,
}
write(THIS_DIR / "flagship-metadata.json", metadata_doc)

# ---- Config A ----
a_dir = THIS_DIR / "01 Config A"
intent_a = "Config A: adds direct bypass edge (132->140) with capacity 3.0."
desc_a_cap = "Capacity inputs for flagship benchmark - Config A."
desc_a_lp  = "Link probabilities for flagship benchmark - Config A."
desc_a_cpm = "CPM inputs for flagship benchmark - Config A."

if args.write_scenario_edges:
    write(a_dir / "flagship-a.EDGES",
        edges_file_content(config_a_edges))
write(a_dir / "flagship-a-capacities.json",
      capacities_json(config_a_edges, config_a_edge_caps, base_node_caps, intent_a, desc_a_cap))
write(a_dir / "flagship-a-linkprobabilities.json",
      linkprobs_json(config_a_edges, intent_a, desc_a_lp))
write(a_dir / "flagship-a-nodepriors.json",
      nodepriors_json(ALL_NODES, intent_a))
write(a_dir / "flagship-a-cpm-inputs.json",
      cpm_json(config_a_edges, intent_a, desc_a_cpm))
write(a_dir / "flagship-a-mappings.json",
    mappings_json("Config A", [], {BYPASS_EDGE: BYPASS_CAP}))

# ---- Config B ----
b_dir = THIS_DIR / "02 Config B"
intent_b = "Config B: Config A topology plus relaxed feeder capacities into dispatch gateways 134/135."
desc_b_cap = "Capacity inputs for flagship benchmark - Config B."
desc_b_lp  = "Link probabilities for flagship benchmark - Config B."
desc_b_cpm = "CPM inputs for flagship benchmark - Config B."

if args.write_scenario_edges:
    write(b_dir / "flagship-b.EDGES",
        edges_file_content(config_b_edges))
write(b_dir / "flagship-b-capacities.json",
      capacities_json(config_b_edges, config_b_edge_caps, base_node_caps, intent_b, desc_b_cap))
write(b_dir / "flagship-b-linkprobabilities.json",
      linkprobs_json(config_b_edges, intent_b, desc_b_lp))
write(b_dir / "flagship-b-nodepriors.json",
      nodepriors_json(ALL_NODES, intent_b))
write(b_dir / "flagship-b-cpm-inputs.json",
      cpm_json(config_b_edges, intent_b, desc_b_cpm))
write(b_dir / "flagship-b-mappings.json",
    mappings_json("Config B", [], config_b_changes))

print("\nDone.")
