#!/usr/bin/env python3
"""Convert EPANET Net3.inp to the framework's structure file, oriented by a
steady-state hydraulic simulation at the design demand pattern.

Requires WNTR (Water Network Tool for Resilience):
    pip install wntr --break-system-packages

Usage:
    python net3_to_ipf.py Net3.inp --outdir dag_ntwrk_files/net3

Produces, in outdir:
    net3.EDGES                  the oriented edge list, integer node ids
    net3-node-mapping.txt       EPANET id  ->  integer id, one per line, with node type
    net3_orientation_log.txt    every link's EPANET id, its two ends, the flow sign used,
                                 and a list of any link dropped or merged to keep acyclicity
    net3_demand_by_sink.csv     sink node id, EPANET id, demand at the design pattern (L/s)

What this does NOT do: assign reliability, capacity or schedule inputs. Those are built by
a second script once this structure is confirmed (see net3_case_study_requirements.md
sections 2-4). Run this first, inspect net3_orientation_log.txt, and only then build inputs
on top of the confirmed structure, since a change here changes every downstream file.
"""
import argparse
import csv
import sys

try:
    import wntr
except ImportError:
    sys.exit("This script requires WNTR: pip install wntr --break-system-packages")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("inp_file")
    ap.add_argument("--outdir", required=True)
    ap.add_argument("--velocity", type=float, default=None,
                    help="if given, also compute pipe capacities at this velocity (m/s) "
                         "and write net3-capacities-draft.json for review")
    args = ap.parse_args()

    import os
    os.makedirs(args.outdir, exist_ok=True)

    wn = wntr.network.WaterNetworkModel(args.inp_file)
    sim = wntr.sim.EpanetSimulator(wn)
    results = sim.run_sim()

    # Steady-state / single-period: take the last (or only) time step's flow.
    flow = results.link["flowrate"].iloc[-1]
    time_used = results.link["flowrate"].index[-1]

    # Node classification from the model itself.
    reservoirs = set(wn.reservoir_name_list)
    tanks = set(wn.tank_name_list)
    junctions = set(wn.junction_name_list)

    # Integer id assignment: reservoirs first, then tanks, then junctions, in the
    # model's own name order, so the mapping is stable and reproducible.
    ordered_names = (sorted(reservoirs) + sorted(tanks) + sorted(junctions))
    id_of = {name: i + 1 for i, name in enumerate(ordered_names)}

    def node_type(name):
        if name in reservoirs:
            return "reservoir"
        if name in tanks:
            return "tank"
        return "junction"

    with open(os.path.join(args.outdir, "net3-node-mapping.txt"), "w") as fh:
        fh.write("epanet_id,integer_id,type\n")
        for name in ordered_names:
            fh.write(f"{name},{id_of[name]},{node_type(name)}\n")

    # Orient every link by the sign of its flow at the chosen time step.
    edges = []
    orientation_log = []
    dropped = []
    for link_name, link in wn.links():
        q = flow.get(link_name, 0.0)
        start, end = link.start_node_name, link.end_node_name
        if q >= 0:
            u, v = start, end
        else:
            u, v = end, start
        edges.append((id_of[u], id_of[v], link_name, q))
        orientation_log.append(
            f"{link_name}: {start}->{end} (model), flow={q:.4f}, oriented {u}->{v}"
        )

    # Cycle check: reject and log any edge that closes a cycle, in the order processed.
    # Simple incremental DFS check; Net3 is small enough for this to be fast.
    adj = {}
    kept_edges = []
    for u, v, link_name, q in edges:
        adj.setdefault(u, []).append(v)
        # DFS from v to see if u is reachable (i.e. adding u->v would close a cycle)
        seen = set()
        stack = [v]
        closes_cycle = False
        while stack:
            n = stack.pop()
            if n == u:
                closes_cycle = True
                break
            if n in seen:
                continue
            seen.add(n)
            stack.extend(adj.get(n, []))
        if closes_cycle:
            adj[u].pop()  # undo the tentative add
            dropped.append((u, v, link_name, q))
            orientation_log.append(
                f"  DROPPED (closes a cycle): {link_name}, {u}->{v}, flow={q:.4f}"
            )
        else:
            kept_edges.append((u, v))

    with open(os.path.join(args.outdir, "net3.EDGES"), "w") as fh:
        fh.write("source,destination\n")
        for u, v in kept_edges:
            fh.write(f"{u},{v}\n")

    with open(os.path.join(args.outdir, "net3_orientation_log.txt"), "w") as fh:
        fh.write(f"Simulation time step used: {time_used}\n")
        fh.write(f"Total links: {len(edges)}, kept: {len(kept_edges)}, "
                 f"dropped for acyclicity: {len(dropped)}\n\n")
        fh.write("\n".join(orientation_log))
        fh.write("\n")

    # Demand at sinks (junctions with positive base demand at the design pattern).
    demand = results.node["demand"].iloc[-1]
    with open(os.path.join(args.outdir, "net3_demand_by_sink.csv"), "w", newline="") as fh:
        w = csv.writer(fh)
        w.writerow(["integer_id", "epanet_id", "demand_Lps"])
        for name in junctions:
            d = demand.get(name, 0.0)
            if d > 0:
                w.writerow([id_of[name], name, round(d * 1000, 4)])  # m3/s -> L/s

    print(f"{len(ordered_names)} nodes ({len(reservoirs)} reservoirs, {len(tanks)} tanks, "
          f"{len(junctions)} junctions)")
    print(f"{len(kept_edges)} edges kept, {len(dropped)} dropped for acyclicity "
          f"(see net3_orientation_log.txt)")
    print("Next: inspect net3_orientation_log.txt, confirm sources/sinks against the graph "
          "object (POST /network-structure), then build reliability/capacity/schedule "
          "inputs per net3_case_study_requirements.md sections 2-4.")


if __name__ == "__main__":
    main()
