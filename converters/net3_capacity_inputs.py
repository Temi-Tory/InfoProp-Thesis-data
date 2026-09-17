#!/usr/bin/env python3
"""Net3 case study, section 3: capacity (flow) inputs.

Builds a super-sink over every demand junction (same construction as the RTS-24 case study:
one added node, one edge in from every demand junction, capacity equal to that junction's
design-pattern demand) so deliverable throughput can be read against total demand. No super-
source is added: the two reservoirs are already the graph's own sources, matching the
requirements doc's stated simpler option (section 3) when a single-source network is wanted.

GROUNDING:

1. Pipe capacity: hydraulic capacity at a stated maximum velocity, Q = v*A, v = 1.5 m/s (the
   lower, more conservative end of the requirements doc's stated 1.5-2.0 m/s range; a commonly
   cited water-main design velocity to limit head loss and water-hammer risk). Diameter from
   the .inp file (inches, converted to metres). Unit used throughout this pack: L/s.

2. Pump capacity: from the pump curve's own maximum tabulated flow point (the .inp file's
   [CURVES] section, read directly, not assumed):
     Pump 10  (Lake source):  curve 1, max tabulated point (4000 GPM, 63 ft head)  -> 4000 GPM
     Pump 335 (River source): curve 2, max tabulated point (14000 GPM, 86 ft head) -> 14000 GPM
   Converted GPM -> L/s at 1 US gallon = 3.785411784 L (1 GPM = 0.0630902 L/s).

3. Reservoir edges: unbounded (infinity token) -- takes precedence over any other rule, since a
   reservoir is an unlimited source in this model (same convention as the power-network and
   RTS-24 case studies this session). Pump 10 (Lake -> 10) is directly a reservoir's own edge as
   well as a pump edge; the reservoir-edge rule applies (unbounded), not the pump-curve figure.
   Pump 335 is NOT a reservoir edge (River's own edge is the separate pipe "60", River->60,
   which gets the reservoir-edge rule instead); pump 335 keeps its pump-curve capacity.

4. Dummy tank-connector pipes (links 20, 40, 50 -- see net3_reliability_inputs.py for the same
   classification): unbounded, on the same "not a real pipe, represents the tank's own boundary"
   grounds as their reliability treatment.

5. Tanks: no separate node capacity is imposed (stated as unbounded at the node level); the
   tank's own outgoing dummy-connector edge is already unbounded by rule 4, so a node capacity
   would be redundant here.

6. Demand / super-sink: net3_demand_by_sink.csv (from net3_to_ipf.py, L/s already) gives one
   edge, per demand junction, into a new node (id = max existing id + 1) with capacity equal to
   that junction's demand.

7. Scenarios:
   - Baseline: all of the above.
   - Degraded: one trunk main derated, one pump out. Trunk main: EPANET link 329 (integer edge
     97->19), 45,500 ft (8.6 mi) at 30 in diameter -- by a wide margin the longest large-
     diameter pipe in the network (next longest comparable-diameter pipe is under 5,000 ft),
     the network's dominant transmission main by inspection, not an arbitrary pick. Derated to
     50% of its Baseline Q=vA capacity. Pump out: Pump 335 (River source) capacity set to 0,
     simulating a pump failure -- chosen as the larger of the two pumps, so the scenario is a
     genuine stress test rather than a redundant one.

Usage:
    python net3_capacity_inputs.py --outdir dag_ntwrk_files/net3/net3-scenarios
"""
import argparse
import csv
import json
import math
import os
import re

NET3DIR_DEFAULT = "dag_ntwrk_files/net3"
VELOCITY_MPS = 1.5
DUMMY_CONNECTOR_LENGTH = 99
DUMMY_CONNECTOR_DIAMETER = 99
GPM_TO_LPS = 3.785411784 / 60.0  # 0.0630902...
PUMP_MAX_FLOW_GPM = {"10": 4000.0, "335": 14000.0}   # from [CURVES], max tabulated point
TRUNK_MAIN_LINK_ID = "329"        # 97->19, 45,500 ft, 30 in -- the dominant transmission main
TRUNK_MAIN_DERATE_FACTOR = 0.5
PUMP_OUT_LINK_ID = "335"          # River source pump


def parse_inp(inp_path):
    with open(inp_path) as f:
        lines = f.readlines()

    def section_lines(name):
        out, in_sec = [], False
        for line in lines:
            s = line.strip()
            if s.startswith("["):
                in_sec = (s.upper() == f"[{name}]")
                continue
            if in_sec and s and not s.startswith(";"):
                out.append(s)
        return out

    pipes = {}
    for line in section_lines("PIPES"):
        parts = re.split(r"\s+", line.split(";")[0].strip())
        if len(parts) < 5:
            continue
        link_id, n1, n2, length_ft, diameter_in = parts[0], parts[1], parts[2], float(parts[3]), float(parts[4])
        pipes[link_id] = {"node1": n1, "node2": n2, "length_ft": length_ft, "diameter_in": diameter_in}

    pumps = {}
    for line in section_lines("PUMPS"):
        parts = re.split(r"\s+", line.split(";")[0].strip())
        if len(parts) < 3:
            continue
        link_id, n1, n2 = parts[0], parts[1], parts[2]
        pumps[link_id] = {"node1": n1, "node2": n2}

    return pipes, pumps


def load_node_mapping(net3dir):
    id_of, node_type = {}, {}
    with open(os.path.join(net3dir, "net3-node-mapping.txt")) as f:
        next(f)
        for line in f:
            epanet_id, integer_id, ntype = line.strip().split(",")
            id_of[epanet_id] = int(integer_id)
            node_type[int(integer_id)] = ntype
    return id_of, node_type


def load_edges(net3dir):
    edges = []
    with open(os.path.join(net3dir, "net3.EDGES")) as f:
        next(f)
        for line in f:
            u, v = line.strip().split(",")
            edges.append((int(u), int(v)))
    return edges


def write(path, obj):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        json.dump(obj, f, indent=2)


def pipe_capacity_lps(diameter_in, velocity_mps=VELOCITY_MPS):
    d_m = diameter_in * 0.0254
    a_m2 = math.pi * (d_m / 2) ** 2
    return velocity_mps * a_m2 * 1000.0  # m3/s -> L/s


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--net3dir", default=NET3DIR_DEFAULT)
    ap.add_argument("--outdir", required=True)
    args = ap.parse_args()

    id_of, node_type = load_node_mapping(args.net3dir)
    edges = load_edges(args.net3dir)
    pipes, pumps = parse_inp(os.path.join(args.net3dir, "Net3.inp"))
    reservoir_int_ids = {n for n, t in node_type.items() if t == "reservoir"}

    node_pair_to_link = {}
    dummy_links = set()
    for link_id, rec in pipes.items():
        u, v = id_of[rec["node1"]], id_of[rec["node2"]]
        node_pair_to_link[frozenset((u, v))] = ("pipe", link_id, rec)
        if rec["length_ft"] == DUMMY_CONNECTOR_LENGTH and rec["diameter_in"] == DUMMY_CONNECTOR_DIAMETER:
            dummy_links.add(link_id)
    for link_id, rec in pumps.items():
        u, v = id_of[rec["node1"]], id_of[rec["node2"]]
        node_pair_to_link[frozenset((u, v))] = ("pump", link_id, rec)

    def base_capacity(u, v):
        """Returns (capacity_lps_or_'Inf', link_id, kind) for edge (u,v) under Baseline rules."""
        kind, link_id, rec = node_pair_to_link[frozenset((u, v))]
        if u in reservoir_int_ids:                       # rule 3: reservoir edges, highest priority
            return "Inf", link_id, "reservoir-edge"
        if kind == "pipe" and link_id in dummy_links:     # rule 4
            return "Inf", link_id, "dummy-connector"
        if kind == "pump":                                # rule 2
            gpm = PUMP_MAX_FLOW_GPM[link_id]
            return gpm * GPM_TO_LPS, link_id, "pump"
        # rule 1: real pipe
        return pipe_capacity_lps(rec["diameter_in"]), link_id, "pipe"

    demand_by_int_id = {}
    with open(os.path.join(args.net3dir, "net3_demand_by_sink.csv")) as f:
        r = csv.DictReader(f)
        for row in r:
            demand_by_int_id[int(row["integer_id"])] = float(row["demand_Lps"])

    super_sink_id = max(id_of.values()) + 1
    print(f"super-sink node id = {super_sink_id}, {len(demand_by_int_id)} demand edges into it")

    def build_scenario(name, capacity_overrides=None):
        capacity_overrides = capacity_overrides or {}
        recs = []
        for (u, v) in edges:
            if (u, v) in capacity_overrides:
                cap = capacity_overrides[(u, v)]
            else:
                cap, _, _ = base_capacity(u, v)
            recs.append({"source": u, "destination": v, "capacity": cap})
        for junction_id, demand_lps in demand_by_int_id.items():
            recs.append({"source": junction_id, "destination": super_sink_id, "capacity": demand_lps})
        write(os.path.join(args.outdir, name, f"{name}-capacities.json"),
              {"data_type": "Float64", "edges": recs})

    build_scenario("Baseline")

    # Degraded: trunk main (link 329) derated to 50% of its Baseline capacity; pump 335 out (0).
    overrides = {}
    for (u, v) in edges:
        cap, link_id, kind = base_capacity(u, v)
        if link_id == TRUNK_MAIN_LINK_ID:
            overrides[(u, v)] = cap * TRUNK_MAIN_DERATE_FACTOR
            print(f"Degraded: trunk main link {link_id} ({u}->{v}) derated {cap:.2f} -> "
                  f"{cap*TRUNK_MAIN_DERATE_FACTOR:.2f} L/s")
        elif link_id == PUMP_OUT_LINK_ID:
            overrides[(u, v)] = 0.0
            print(f"Degraded: pump {link_id} ({u}->{v}) OUT, capacity 0.0 L/s")
    build_scenario("Degraded", overrides)

    # Interval capacities (same file for both Baseline and Degraded-adjacent Interval reliability
    # scenario; capacity stays point-valued per the requirements doc, "Point-valued only" for
    # capacity across the whole thesis) -- reuse Baseline capacities for the Interval reliability
    # scenario folder so every scenario folder is complete for the toolkits that need it.
    build_scenario("Interval")

    print(f"\nBaseline / Degraded / Interval capacity files written to {args.outdir}")
    print(f"velocity used: {VELOCITY_MPS} m/s; unit: L/s throughout")


if __name__ == "__main__":
    main()
