#!/usr/bin/env python3
"""Build the power-network scenario folders for the interface chapter.

Usage:
    python make_power_scenarios.py power-network.EDGES --outdir dag_ntwrk_files/power-network
        [--reliable 1-2,3-10,5-13,7-8,11-19,14-21,16-18] [--seed 7]

Produces, under outdir:
    power-network.EDGES                     copy of the structure file
    Published_R090/ Published_R099/ Published_R030/
                                            reliability only: the three published cases of Tong and
                                            Tien (2019, ASCE), every link at R_l, node priors 1
    Baseline/                               all three toolkits, deterministic
    Degraded/                               all three toolkits, deterministic, one feeder derated
    Interval/                               reliability and schedule as intervals, flow deterministic
    Pbox/                                   reliability as parametric p-boxes

Reliability inputs follow Tong and Tien (2019), ASCE-ASME J. Risk Uncertainty Eng.
Syst. A 5(3):04019011, Fig. 11 and Table 5: node priors 1.0 and every link at the
same reliability R_l, with published exact sink-23 reliabilities 0.85741 (R_l 0.9),
0.98969 (0.99) and 0.00221 (0.3). There are NO perfectly reliable links in this
directed version; the seven such links belong to the undirected network of the
authors' RESS paper and are not used here. --reliable is kept for that variant only. Flow capacities and schedule durations
are ASSIGNED for the demonstration and must be described as such in the thesis:
    capacities: links out of a source 100, listed equipment-free links unbounded,
                all other links 60; no node capacities.
                Degraded: every link into the terminal at 30.
    schedule:   an energisation sequence: source nodes 0, the terminal 0, every
                other node 1.5 (switching and checks); edges 0.
                Degraded: every node 2.5. Interval: [1.0, 2.0].
Edit the constants below if different assigned values are wanted, and record
what was used in Appendix A.

File shapes are the server's contracts (checked 30 August 2026):
    *-nodepriors.json         {"data_type": ..., "nodes": {id: value}}
    *-linkprobabilities.json  {"data_type": ..., "links": {"(u,v)": value}}
    *-capacities.json         {"data_type": "Float64", "edges": [{"source","destination","capacity"}]}
    *-cpm-inputs.json         {"data_type": ..., "time_analysis": {"node_durations", "edge_delays", "initial_time"}}
Interval values are {"lower": a, "upper": b}. P-box values follow the
per-value object form with "construction_type".
"""
import argparse
import json
import os
import shutil


def read_edges(path):
    edges = []
    with open(path) as fh:
        for line in fh:
            line = line.strip()
            if not line or not line[0].isdigit():
                continue
            u, v = line.split(",")[:2]
            edges.append((int(u), int(v)))
    return edges


def write(path, obj):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as fh:
        json.dump(obj, fh, indent=2)


def reliability_files(outdir, scen, edges, nodes, reliable, link_value, prior_value=1.0,
                      data_type="Float64"):
    priors = {str(n): prior_value for n in nodes}
    links = {}
    for u, v in edges:
        key = f"({u},{v})"
        links[key] = 1.0 if (u, v) in reliable else link_value
    write(os.path.join(outdir, scen, f"{scen}-nodepriors.json"),
          {"data_type": data_type, "nodes": priors})
    write(os.path.join(outdir, scen, f"{scen}-linkprobabilities.json"),
          {"data_type": data_type, "links": links})


def capacity_file(outdir, scen, edges, sources, sinks, reliable, derate_into_sink=None):
    recs = []
    for u, v in edges:
        if u in sources:
            c = 100.0
        elif (u, v) in reliable:
            c = float("inf")
        else:
            c = 60.0
        if derate_into_sink is not None and v in sinks:
            c = derate_into_sink
        recs.append({"source": u, "destination": v,
                     "capacity": "Inf" if c == float("inf") else c})
    write(os.path.join(outdir, scen, f"{scen}-capacities.json"),
          {"data_type": "Float64", "edges": recs})


def cpm_file(outdir, scen, edges, nodes, sources, sinks, dur, interval=False):
    def val(x):
        return {"lower": x[0], "upper": x[1]} if interval else x
    nd = {}
    for n in nodes:
        if n in sources or n in sinks:
            nd[str(n)] = val((0.0, 0.0)) if interval else 0.0
        else:
            nd[str(n)] = val(dur)
    ed = {f"({u},{v})": (val((0.0, 0.0)) if interval else 0.0) for u, v in edges}
    write(os.path.join(outdir, scen, f"{scen}-cpm-inputs.json"),
          {"data_type": "Interval" if interval else "Float64",
           "time_analysis": {"node_durations": nd, "edge_delays": ed,
                             "initial_time": val((0.0, 0.0)) if interval else 0.0}})


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("edges_file")
    ap.add_argument("--outdir", required=True)
    ap.add_argument("--reliable", default="",
                    help="optional perfectly reliable links as u-v pairs (RESS undirected variant only; default none)")
    args = ap.parse_args()

    edges = read_edges(args.edges_file)
    nodes = sorted(set([u for u, _ in edges] + [v for _, v in edges]))
    sources = {n for n in nodes if not any(v == n for _, v in edges)}
    sinks = {n for n in nodes if not any(u == n for u, _ in edges)}
    reliable = set()
    for tok in [t for t in args.reliable.split(",") if t]:
        a, b = tok.split("-")
        a, b = int(a), int(b)
        if (a, b) in edges:
            reliable.add((a, b))
        elif (b, a) in edges:
            reliable.add((b, a))
        else:
            print(f"warning: reliable link {tok} not in edge list; check node numbering")

    os.makedirs(args.outdir, exist_ok=True)
    shutil.copy(args.edges_file, os.path.join(args.outdir, os.path.basename(args.edges_file)))
    print(f"{len(nodes)} nodes, {len(edges)} edges, sources {sorted(sources)}, sinks {sorted(sinks)}, "
          f"{len(reliable)} reliable links")

    # Published reproduction cases (ASCE 2019, Table 5): all links at R_l, no reliable links
    for rl, tag in [(0.9, "090"), (0.99, "099"), (0.3, "030")]:
        reliability_files(args.outdir, f"Published_R{tag}", edges, nodes, set(), rl)

    # Baseline: all three toolkits at pf = 0.05
    reliability_files(args.outdir, "Baseline", edges, nodes, reliable, 0.95)
    capacity_file(args.outdir, "Baseline", edges, sources, sinks, reliable)
    cpm_file(args.outdir, "Baseline", edges, nodes, sources, sinks, 1.5)

    # Degraded: pf = 0.20, links into the terminal derated, slower switching
    reliability_files(args.outdir, "Degraded", edges, nodes, reliable, 0.80)
    capacity_file(args.outdir, "Degraded", edges, sources, sinks, reliable, derate_into_sink=30.0)
    cpm_file(args.outdir, "Degraded", edges, nodes, sources, sinks, 2.5)

    # Interval: link probabilities [0.90, 0.97], durations [1.0, 2.0]
    # Reliability (nodepriors/linkprobabilities) interval values need an explicit "type":
    # "interval" tag -- InputProcessingModule.jl's deserialize_probability_value reads
    # data["type"] unconditionally before branching on it, so a bare {"lower","upper"} throws
    # KeyError: key "type" not found. (Confirmed against a live server call, 2026-08-30. The
    # CPM/schedule contract below is different and genuinely takes a bare {"lower","upper"}
    # with no "type" -- only the reliability contract needs this wrapper.)
    priors = {str(n): {"type": "interval", "lower": 1.0, "upper": 1.0} for n in nodes}
    links = {f"({u},{v})": ({"type": "interval", "lower": 1.0, "upper": 1.0} if (u, v) in reliable
                            else {"type": "interval", "lower": 0.90, "upper": 0.97}) for u, v in edges}
    write(os.path.join(args.outdir, "Interval", "Interval-nodepriors.json"),
          {"data_type": "Interval", "nodes": priors})
    write(os.path.join(args.outdir, "Interval", "Interval-linkprobabilities.json"),
          {"data_type": "Interval", "links": links})
    capacity_file(args.outdir, "Interval", edges, sources, sinks, reliable)
    cpm_file(args.outdir, "Interval", edges, nodes, sources, sinks, (1.0, 2.0), interval=True)

    # Pbox: link probabilities as parametric p-boxes with interval mean
    priors = {str(n): {"type": "pbox", "construction_type": "scalar", "value": 1.0} for n in nodes}
    links = {}
    for u, v in edges:
        if (u, v) in reliable:
            links[f"({u},{v})"] = {"type": "pbox", "construction_type": "scalar", "value": 1.0}
        else:
            # Real contract (InputProcessingModule.jl create_parametric_interval_pbox): "shape"
            # (not "distribution"), "params" as a positional array (not a "parameters" dict),
            # each interval-valued param wrapped as {"type":"interval","lower","upper"}.
            # shape="normal" was tried first and rejected: a normal distribution has unbounded
            # tails, so its discretized p-box range runs past 1.0 and is_valid_probability
            # correctly refuses it -- a real modeling error, not a bug. shape="uniform" is
            # naturally bounded by its own [a,b] params. Confirmed against a live server call,
            # 2026-08-30.
            links[f"({u},{v})"] = {"type": "pbox", "construction_type": "parametric_interval",
                                   "shape": "uniform",
                                   "params": [
                                       {"type": "interval", "lower": 0.88, "upper": 0.92},
                                       {"type": "interval", "lower": 0.95, "upper": 0.98},
                                   ]}
    write(os.path.join(args.outdir, "Pbox", "Pbox-nodepriors.json"),
          {"data_type": "pbox", "nodes": priors})
    write(os.path.join(args.outdir, "Pbox", "Pbox-linkprobabilities.json"),
          {"data_type": "pbox", "links": links})
    print("done; check the p-box value objects against InputProcessingModule.jl before use")


if __name__ == "__main__":
    main()
