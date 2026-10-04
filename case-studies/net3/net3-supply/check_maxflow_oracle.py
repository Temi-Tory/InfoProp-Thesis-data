#!/usr/bin/env python3
"""Independent max-flow check for the Net3 capacity scenarios.

Plain Edmonds-Karp (BFS augmenting paths) in pure Python, sharing no code with the toolkit.
Reads net3-supply.EDGES and each scenario's capacity file, takes the indegree-0 nodes as
sources and the capacity file's target_nodes (node 98, the demand super-sink) as the sink,
and prints the maximum flow next to the total demand (the capacity of the edges into 98).

Usage: python check_maxflow_oracle.py   (writes check_maxflow_oracle_output.txt beside it)
"""
import json
import os
from collections import deque

HERE = os.path.dirname(os.path.abspath(__file__))
BIG = 1e18  # stands in for "Inf" capacities


def read_edges(path):
    with open(path) as f:
        rows = [line.strip() for line in f if line.strip()]
    return [tuple(int(x) for x in r.split(",")) for r in rows[1:]]


def max_flow(edges, cap, sources, sinks):
    S, T = -1, -2
    res = {}
    adj = {}

    def add(u, v, c):
        res[(u, v)] = res.get((u, v), 0.0) + c
        res.setdefault((v, u), 0.0)
        adj.setdefault(u, set()).add(v)
        adj.setdefault(v, set()).add(u)

    for e in edges:
        add(e[0], e[1], cap[e])
    for s in sources:
        add(S, s, BIG)
    for t in sinks:
        add(t, T, BIG)

    total = 0.0
    while True:
        parent = {S: None}
        q = deque([S])
        while q and T not in parent:
            u = q.popleft()
            for v in adj.get(u, ()):
                if v not in parent and res[(u, v)] > 1e-12:
                    parent[v] = u
                    q.append(v)
        if T not in parent:
            return total
        bottleneck, v = BIG, T
        while parent[v] is not None:
            bottleneck = min(bottleneck, res[(parent[v], v)])
            v = parent[v]
        v = T
        while parent[v] is not None:
            res[(parent[v], v)] -= bottleneck
            res[(v, parent[v])] += bottleneck
            v = parent[v]
        total += bottleneck


def main():
    edges = read_edges(os.path.join(HERE, "net3-supply.EDGES"))
    heads = {v for _, v in edges}
    sources = sorted({u for u, _ in edges} - heads)
    lines = [f"edges={len(edges)}  sources={sources}"]
    for scen in ("Baseline", "Degraded", "Interval"):
        with open(os.path.join(HERE, scen, f"{scen}-capacities.json")) as f:
            data = json.load(f)
        cap = {}
        for e in data["edges"]:
            c = e["capacity"]
            cap[(int(e["source"]), int(e["destination"]))] = BIG if isinstance(c, str) else float(c)
        assert set(cap) == set(edges), f"{scen}: capacity edges differ from the edge list"
        sinks = data["target_nodes"]
        demand = sum(c for (u, v), c in cap.items() if v in sinks)
        f_star = max_flow(edges, cap, sources, sinks)
        lines.append(f"{scen:9s} sink={sinks}  max_flow={f_star:.4f}  total_demand={demand:.4f}"
                     f"  share={100 * f_star / demand:.1f}%")
    out = "\n".join(lines)
    print(out)
    with open(os.path.join(HERE, "check_maxflow_oracle_output.txt"), "w") as f:
        f.write(out + "\n")


if __name__ == "__main__":
    main()
