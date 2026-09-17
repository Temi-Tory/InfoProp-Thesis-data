#!/usr/bin/env python3
"""Net3 case study, section 2: reliability (probability) inputs.

Builds Baseline (deterministic) and Interval scenarios on top of the structure produced by
net3_to_ipf.py. p-box is deliberately NOT built for this case study: the total conditioning-
state cost (sum 2^|C| over the network's 307 diamonds) is 5.47e4, past the point where a
comparable network (drone concentrated-minimal K=8, sum 2^|C|=7,758) failed to complete within
budget in this session's own earlier testing, and the probability chapter already carries the
full p-box tractability-boundary story in depth (decided with the user, 2026-08-30).

GROUNDING (every number below is either from the .inp file itself, a cited published source, or
an explicitly flagged assumption -- no unstated values):

1. Node priors: ALL nodes (reservoirs, tanks, junctions) = 1.0, exact. Reliability in this model
   lives entirely on the edges: reservoirs and tanks have no failure mode of their own in this
   graph (Net3.inp has no failure data for them either), and a junction is a demand point, not a
   component (matches the requirements doc's own reasoning, section 2).

2. Edge probabilities -- three classes, all edges accounted for:
   a. PUMPS (2 edges: link 10 Lake->10, link 335 60->61): P = 0.99, an availability figure for
      critical water-utility pumping assets from Butts, E. (2022), "Reliability in Water and
      Pumping Systems," Water Well Journal, 25 July 2022 -- the article frames 90/95/99% as the
      levels appropriate when a failure during the interval between rebuilds is unacceptable,
      and states availability for a critical asset "should be very high, preferably above 99%".
      General water-pumping-system literature, not Net3-specific data -- recorded as such.
   b. DUMMY TANK-CONNECTOR PIPES (3 edges: links 20, 40, 50, each Length=99 ft, Diameter=99 in,
      Roughness=199 in the .inp file -- confirmed by inspection: each connects a tank directly to
      its adjacent junction with placeholder, non-physical dimensions, a standard EPANET modelling
      device to avoid an artificial headloss bottleneck at a tank connection, not a real pipe).
      Treated as P = 1.0, exact, on the grounds that they represent the tank's own boundary, not
      a length of transmission main -- an explicit modelling simplification, stated as such.
   c. REAL PIPES (114 edges): probability of no failure over ONE YEAR, from an annual break-rate
      model. Break rate by diameter class (breaks per 100 mile-years), from Barfuss, S. L. (2023),
      "Water Main Break Rates in the USA and Canada: A Comprehensive Study," Utah Water Research
      Laboratory, Utah State University, December 2023, Figure 38/39 ("Total", all materials
      combined -- Net3.inp does not carry pipe material, so a material-averaged, diameter-
      differentiated rate is used; diameter is in the .inp file and drives the split directly):
        3-12 in  (Net3 has 8,10,12 in): 13.3 breaks / (100 mi . yr)
        14-24 in (Net3 has 14,16,18,20,24 in): 3.1 breaks / (100 mi . yr)
        30-36 in (Net3 has 30 in): 0.2 breaks / (100 mi . yr)   [Figure 37, "Total" bar]
      Converted to a per-pipe annual probability of no failure via the standard Poisson/
      exponential reliability model: lambda_pipe = (rate_per_100mi_yr / 100) * length_miles
      (breaks/year for this specific pipe, at this rate, over this length); P(no failure in
      1 year) = exp(-lambda_pipe). Length is read directly from the .inp file (feet, EPANET
      GPM unit system) and converted to miles (1 mi = 5280 ft). Horizon: 1 year, stated once.

3. Value forms:
   - Baseline: the point values above (data_type Float64).
   - Interval: every non-degenerate probability (i.e. every edge probability computed from a
     break-rate or availability figure, NOT the exact-1.0 node priors or the exact-1.0 dummy
     connector pipes) widened by +/-5% relative half-width, matching the flow/CPM chapters'
     own convention for this exact kind of scenario. Interval = [p*(1-0.05), p*(1+0.05)],
     clipped to [0,1] (never triggered here since no base value is within 5% of 1.0 except the
     already-degenerate ones, which are excluded from widening by construction).

Usage:
    python net3_reliability_inputs.py --outdir dag_ntwrk_files/net3/net3-scenarios
"""
import argparse
import json
import math
import os
import re

NET3DIR_DEFAULT = "dag_ntwrk_files/net3"

PUMP_AVAILABILITY = 0.99          # Butts 2022, Water Well Journal
DUMMY_CONNECTOR_LENGTH = 99       # ft -- the .inp file's own placeholder marker
DUMMY_CONNECTOR_DIAMETER = 99     # in -- ditto
HORIZON_YEARS = 1.0
RELATIVE_HALF_WIDTH = 0.05

# breaks / (100 mile . year), Barfuss 2023 Fig 38/39/37 "Total" bars
BREAK_RATE_BY_DIAMETER_CLASS = [
    (12, 13.3),   # 3-12 in
    (24, 3.1),    # 14-24 in
    (36, 0.2),    # 30-36 in
]


def break_rate_for_diameter(d_in):
    for upper, rate in BREAK_RATE_BY_DIAMETER_CLASS:
        if d_in <= upper:
            return rate
    return BREAK_RATE_BY_DIAMETER_CLASS[-1][1]  # fall back to the largest class if exceeded


def parse_inp_pipes_and_pumps(inp_path):
    """Returns {link_id: {"node1":..,"node2":..,"length_ft":..,"diameter_in":..}} for pipes,
    and a set of pump link ids with their two node names."""
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
    id_of = {}
    node_type = {}
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


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--net3dir", default=NET3DIR_DEFAULT)
    ap.add_argument("--outdir", required=True)
    args = ap.parse_args()

    id_of, node_type = load_node_mapping(args.net3dir)
    edges = load_edges(args.net3dir)
    pipes, pumps = parse_inp_pipes_and_pumps(os.path.join(args.net3dir, "Net3.inp"))

    # Map each (u,v) integer edge back to its EPANET link, to classify it.
    node_pair_to_link = {}
    dummy_links, pump_links, real_pipe_links = set(), set(), set()
    for link_id, rec in pipes.items():
        u, v = id_of[rec["node1"]], id_of[rec["node2"]]
        node_pair_to_link[frozenset((u, v))] = ("pipe", link_id, rec)
        if rec["length_ft"] == DUMMY_CONNECTOR_LENGTH and rec["diameter_in"] == DUMMY_CONNECTOR_DIAMETER:
            dummy_links.add(link_id)
        else:
            real_pipe_links.add(link_id)
    for link_id, rec in pumps.items():
        u, v = id_of[rec["node1"]], id_of[rec["node2"]]
        node_pair_to_link[frozenset((u, v))] = ("pump", link_id, rec)
        pump_links.add(link_id)

    print(f"classified: {len(real_pipe_links)} real pipes, {len(dummy_links)} dummy tank-connector "
          f"pipes, {len(pump_links)} pumps  (total links = {len(real_pipe_links)+len(dummy_links)+len(pump_links)})")

    edge_prob = {}  # (u,v) -> point probability
    edge_class = {}  # (u,v) -> "pump" | "dummy" | "pipe", for the RESULTS.md table
    for (u, v) in edges:
        kind, link_id, rec = node_pair_to_link[frozenset((u, v))]
        if kind == "pump":
            edge_prob[(u, v)] = PUMP_AVAILABILITY
            edge_class[(u, v)] = ("pump", link_id)
        elif link_id in dummy_links:
            edge_prob[(u, v)] = 1.0
            edge_class[(u, v)] = ("dummy-connector", link_id)
        else:
            length_mi = rec["length_ft"] / 5280.0
            rate = break_rate_for_diameter(rec["diameter_in"])
            lam = (rate / 100.0) * length_mi * HORIZON_YEARS
            p = math.exp(-lam)
            edge_prob[(u, v)] = p
            edge_class[(u, v)] = ("pipe", link_id)

    nodes = sorted(id_of.values())

    # --- Baseline (Float64) ---
    priors = {str(n): 1.0 for n in nodes}
    links = {f"({u},{v})": edge_prob[(u, v)] for (u, v) in edges}
    write(os.path.join(args.outdir, "Baseline", "Baseline-nodepriors.json"),
          {"data_type": "Float64", "nodes": priors})
    write(os.path.join(args.outdir, "Baseline", "Baseline-linkprobabilities.json"),
          {"data_type": "Float64", "links": links})

    # --- Interval (+/- 5% relative half-width on every non-degenerate edge probability) ---
    priors_iv = {str(n): {"type": "interval", "lower": 1.0, "upper": 1.0} for n in nodes}
    links_iv = {}
    for (u, v) in edges:
        p = edge_prob[(u, v)]
        key = f"({u},{v})"
        if p >= 1.0:  # degenerate (dummy connectors) -- stays exact, not widened
            links_iv[key] = {"type": "interval", "lower": 1.0, "upper": 1.0}
        else:
            lo = max(0.0, p * (1 - RELATIVE_HALF_WIDTH))
            hi = min(1.0, p * (1 + RELATIVE_HALF_WIDTH))
            links_iv[key] = {"type": "interval", "lower": lo, "upper": hi}
    write(os.path.join(args.outdir, "Interval", "Interval-nodepriors.json"),
          {"data_type": "Interval", "nodes": priors_iv})
    write(os.path.join(args.outdir, "Interval", "Interval-linkprobabilities.json"),
          {"data_type": "Interval", "links": links_iv})

    # --- record classification + values for RESULTS.md ---
    with open(os.path.join(args.outdir, "reliability_input_classification.csv"), "w") as f:
        f.write("source,destination,epanet_link_id,class,length_ft,diameter_in,probability\n")
        for (u, v) in edges:
            cls, link_id = edge_class[(u, v)]
            rec = pipes.get(link_id) or pumps.get(link_id) or {}
            length_ft = rec.get("length_ft", "")
            diameter_in = rec.get("diameter_in", "")
            f.write(f"{u},{v},{link_id},{cls},{length_ft},{diameter_in},{edge_prob[(u,v)]:.6f}\n")

    n_pumps = sum(1 for c,_ in edge_class.values() if c == "pump")
    n_dummy = sum(1 for c,_ in edge_class.values() if c == "dummy-connector")
    n_pipes = sum(1 for c,_ in edge_class.values() if c == "pipe")
    probs = [edge_prob[e] for e in edges if edge_class[e][0] == "pipe"]
    print(f"Baseline + Interval written to {args.outdir}")
    print(f"edges: {n_pumps} pumps (P={PUMP_AVAILABILITY}), {n_dummy} dummy connectors (P=1.0), "
          f"{n_pipes} real pipes (P range {min(probs):.5f} to {max(probs):.5f})")
    print("classification detail: reliability_input_classification.csv")


if __name__ == "__main__":
    main()
