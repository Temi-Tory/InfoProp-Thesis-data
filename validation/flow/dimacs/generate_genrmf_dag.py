#!/usr/bin/env python3
"""Generate DIMACS-style max-flow benchmark instances, in the mesh-network
style of Goldberg/Cherkassky's `genrmf` generator from the DIMACS 1991
Network Flows Implementation Challenge (Goldberg et al., "Network flows and
matching: First DIMACS implementation challenge", DIMACS Series in Discrete
Mathematics, 1993).

IMPORTANT — this is NOT the literal genrmf binary output: genrmf's own mesh
has bidirectional grid edges within a frame (needed for its own max-flow
benchmarking, which does not require acyclicity), and this framework's graph
object rejects cycles. This generator keeps genrmf's mesh topology (an a x a
grid of nodes per frame, `depth` frames in series, source at one corner of
the first frame, sink at the opposite corner of the last) but *orients every
edge forward* (within a frame: only +row and +col neighbours, never -row/-col;
between frames: only frame i -> frame i+1) so the result is acyclic by
construction — a DAG-respecting variant, not the original generator, and
documented as such per the requirements doc's own instruction ("orient the
instance by a BFS layering and record that this is a different instance from
the published one").

Capacities: integer, uniform in [1, cap_max], one independent draw per edge
(same convention as the rest of the corpus — see
validation/flow/flow_corpus_capacities/README.md), seeded off (seed, name).

Usage:
    python generate_genrmf_dag.py
"""
import json
import os
import random

HERE = os.path.dirname(os.path.abspath(__file__))
SEED = 20260830
CAP_MAX = 1000

# (name, grid side a, depth/frame count b) -> roughly 3*a*a*b edges
INSTANCES = [
    ("genrmf_dag_small", 6, 10),      # 6*6*10=360 nodes,  ~1.0e3 edges
    ("genrmf_dag_medium", 14, 17),    # 14*14*17=3332 nodes, ~1.0e4 edges
    ("genrmf_dag_large", 26, 40),     # 26*26*40=27040 nodes, ~8.1e4 edges
    ("genrmf_dag_xlarge", 34, 32),    # 34*34*32=36992 nodes, ~1.1e5 edges
]


def node_id(frame, row, col, a):
    return frame * a * a + row * a + col + 1  # 1-based, contiguous


def generate(name, a, b, cap_max=CAP_MAX, seed=SEED):
    rng = random.Random(f"{seed}:{name}")
    edges = []  # (u, v)
    for f in range(b):
        for r in range(a):
            for c in range(a):
                u = node_id(f, r, c, a)
                # within-frame forward grid edges: +row, +col only
                if r + 1 < a:
                    edges.append((u, node_id(f, r + 1, c, a)))
                if c + 1 < a:
                    edges.append((u, node_id(f, r, c + 1, a)))
                # cross-frame forward edge: same (row,col) in the next frame
                if f + 1 < b:
                    edges.append((u, node_id(f + 1, r, c, a)))
    source = node_id(0, 0, 0, a)
    sink = node_id(b - 1, a - 1, a - 1, a)
    n_nodes = a * a * b
    caps = [rng.randint(1, cap_max) for _ in edges]
    return source, sink, n_nodes, edges, caps


def main():
    manifest = []
    for name, a, b in INSTANCES:
        source, sink, n_nodes, edges, caps = generate(name, a, b)
        edges_path = os.path.join(HERE, f"{name}.EDGES")
        with open(edges_path, "w") as f:
            f.write("source,destination\n")
            for (u, v) in edges:
                f.write(f"{u},{v}\n")
        cap_path = os.path.join(HERE, f"{name}-capacities.json")
        payload = {
            "data_type": "Float64",
            "edges": [
                {"source": u, "destination": v, "capacity": c}
                for (u, v), c in zip(edges, caps)
            ],
            "description": (
                f"DAG-respecting genrmf-style mesh, a={a} b={b} (grid side x frame "
                f"count), seed {SEED}:{name}, capacities uniform integer [1,{CAP_MAX}]. "
                f"Source={source} (frame 0 corner), sink={sink} (frame {b-1} opposite "
                "corner). Not the literal genrmf binary's output — grid edges are "
                "forward-oriented only (framework graph object rejects cycles); see "
                "generate_genrmf_dag.py for the exact construction."
            ),
        }
        with open(cap_path, "w") as f:
            json.dump(payload, f, indent=2)
        manifest.append({
            "name": name, "grid_a": a, "frames_b": b,
            "nodes": n_nodes, "edges": len(edges),
            "source": source, "sink": sink,
            "generator_cmdline": f"python generate_genrmf_dag.py  # {name}: a={a} b={b} seed={SEED}:{name}",
        })
        print(f"{name}: a={a} b={b} -> {n_nodes} nodes, {len(edges)} edges")

    with open(os.path.join(HERE, "manifest.json"), "w") as f:
        json.dump({"seed": SEED, "cap_max": CAP_MAX, "instances": manifest}, f, indent=2)
    print("\nwrote manifest.json")


if __name__ == "__main__":
    main()
