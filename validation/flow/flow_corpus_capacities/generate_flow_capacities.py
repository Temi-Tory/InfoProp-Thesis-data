#!/usr/bin/env python3
"""Generate seeded capacities for the Flow chapter's corpus (reusing the CPM
validation set of 10 DAGs, per validation/flow/flow_corpus_capacities/README.md).

Rule (recorded here and in the README so results are reproducible from the
files alone, not from re-running this script): integer edge capacities drawn
uniformly from [1, 20], one independent draw per edge, seed 20260830. A
second pass additionally draws node capacities the same way (uniform
integers in [1, 20]) for a named subset of networks.

Usage:
    python generate_flow_capacities.py

Reads each network's <name>.EDGES from dag_ntwrk_files/<name>/ and writes
<name>-capacities.json into validation/flow/flow_corpus_capacities/, in the
server's real wire contract (CapacityHandlers.jl's toolkit-edges-array
schema: {data_type: "Float64", edges: [{source,destination,capacity}],
nodes?: [{node,capacity}]}) — Float64 only, matching the server's own
hard rejection of any other data_type for capacities.
"""
import json
import os
import random

REPO = os.path.dirname(os.path.abspath(__file__))
DAG_DIR = os.path.join(REPO, "dag_ntwrk_files")
OUT_DIR = os.path.join(REPO, "validation", "flow", "flow_corpus_capacities")

SEED = 20260830
CAP_LO, CAP_HI = 1, 20

# name -> (folder, edges filename)
NETWORKS = {
    "water": ("water", "water.EDGES"),
    "KarlNetwork": ("KarlNetwork", "KarlNetwork.EDGES"),
    "grid-graph-5x5": ("grid-graph-5x5", "grid-graph-5x5.EDGES"),
    "metro_directed_dag_for_ipm": ("metro_directed_dag_for_ipm", "metro_directed_dag_for_ipm.EDGES"),
    "ergo-proxy-dag-network": ("ergo-proxy-dag-network", "ergo-proxy-dag-network.EDGES"),
    "drone-network-fw-reliant-centralized": ("drone-network-fw-reliant-centralized", "drone-network-fw-reliant-centralized.EDGES"),
    "drone-network-vtol-dense-decentralized": ("drone-network-vtol-dense-decentralized", "drone-network-vtol-dense-decentralized.EDGES"),
    "drone-network-concentrated-minimal": ("drone-network-concentrated-minimal", "drone-network-concentrated-minimal.EDGES"),
    "continental_medical_network": ("continental_medical_network", "continental_medical_network.EDGES"),
    "glasgow_to_shetland_extreme": ("glasgow_to_shetland_extreme", "glasgow_to_shetland_extreme.EDGES"),
    "highland_to_lowland_full_network": ("highland_to_lowland_full_network", "highland_to_lowland_full_network.EDGES"),
    "psplib-j301_1": ("psplib-j301_1", "j301_1.EDGES"),
}

# the subset that also gets a node-capacitated pass (kept small/deliberate,
# not every network, per the requirements doc's "second pass ... on a subset")
NODE_CAP_SUBSET = {"water", "KarlNetwork", "grid-graph-5x5", "psplib-j301_1"}


def read_edges(path):
    with open(path, encoding="utf-8") as fh:
        lines = [ln.strip() for ln in fh if ln.strip()]
    # first line is the header ("source,destination")
    edges = []
    for ln in lines[1:]:
        u, v = ln.split(",")
        edges.append((int(u), int(v)))
    return edges


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    manifest = []
    for name, (folder, fname) in NETWORKS.items():
        edges_path = os.path.join(DAG_DIR, folder, fname)
        if not os.path.isfile(edges_path):
            print(f"SKIP {name}: {edges_path} not found")
            continue
        edges = read_edges(edges_path)
        nodes = sorted(set(u for u, _ in edges) | set(v for _, v in edges))

        # independent RNG per network, seeded off the global seed + name, so
        # adding/removing a network never perturbs any other network's draw
        rng = random.Random(f"{SEED}:{name}")
        edge_caps = [
            {"source": u, "destination": v, "capacity": rng.randint(CAP_LO, CAP_HI)}
            for u, v in edges
        ]
        payload = {
            "data_type": "Float64",
            "edges": edge_caps,
            "description": (
                f"Generated for the Flow chapter corpus: seed {SEED}:{name}, "
                f"integer capacities uniform in [{CAP_LO},{CAP_HI}], one draw per edge."
            ),
        }
        has_node_caps = name in NODE_CAP_SUBSET
        if has_node_caps:
            rng_n = random.Random(f"{SEED}:{name}:nodes")
            payload["nodes"] = [
                {"node": n, "capacity": rng_n.randint(CAP_LO, CAP_HI)} for n in nodes
            ]
            payload["description"] += (
                f" Node capacities also drawn, uniform in [{CAP_LO},{CAP_HI}], "
                f"seed {SEED}:{name}:nodes."
            )

        out_path = os.path.join(OUT_DIR, f"{name}-capacities.json")
        with open(out_path, "w", encoding="utf-8") as fh:
            json.dump(payload, fh, indent=2)

        manifest.append(
            {
                "network": name,
                "nodes": len(nodes),
                "edges": len(edges),
                "node_capacities": has_node_caps,
                "file": os.path.basename(out_path),
            }
        )
        print(f"{name}: {len(nodes)} nodes, {len(edges)} edges"
              f"{' (+ node capacities)' if has_node_caps else ''} -> {out_path}")

    with open(os.path.join(OUT_DIR, "manifest.json"), "w", encoding="utf-8") as fh:
        json.dump({"seed": SEED, "rule": f"uniform integer [{CAP_LO},{CAP_HI}], one draw per edge (and per node for the node-capacity subset)",
                    "networks": manifest}, fh, indent=2)
    print(f"\nwrote manifest.json ({len(manifest)} networks)")


if __name__ == "__main__":
    main()
