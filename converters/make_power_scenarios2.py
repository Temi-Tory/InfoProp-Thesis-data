#!/usr/bin/env python3
"""Generate the power-network scenario folders for Chapter 5 (probability reproduction),
Chapter 6 (RTS-24 is separate; this network is Chapter 5's reliability case) and Chapter 9
(the interface demonstration network).

This replaces make_power_scenarios.py entirely. It consolidates every decision made across
prior rounds:

  - Network: the directed 23-node, 27-edge power distribution network of Tong and Tien
    (2019, ASCE-ASME J. Risk Uncertainty Eng. Syst. A 5(3):04019011), Figure 11. Edge list
    below traced from the figure and cross-checked against the framework's own diamond
    analysis (source set {1,7,18}, sink {23}, fork/join sets all consistent).
  - Reliability: NO perfectly-reliable-link list. That convention belonged to the
    undirected RESS-paper version of this network and does not apply here. Every link
    carries the same reliability R_l; node priors are 1. Published_R090/R099/R030
    reproduce Table 5 of the source (expected exact sink-23 reliability: 0.85741, 0.98969,
    0.00221).
  - Flow: capacities into sinks are UNBOUNDED (fixed; previously flat 60, which made the
    single sink edge the trivial whole-network bottleneck and gave the bottleneck page
    nothing interesting to show upstream). Degraded derates one INTERIOR line, not every
    terminal edge.
  - Schedule: durations are ROLE-BASED (source/sink = 0, fork = 0.5, regular = 1.0,
    join = 2.0), computed from the graph's own fork/join/source/sink sets, not a flat
    value. This produces a real critical chain (10 of 23 nodes critical, project value
    12.5, chain 1-2-3-4-5-13-14-21-22-23) instead of the flat-duration tie (17 of 23
    nodes tied) the earlier flat-1.5 convention produced. Confirmed by direct computation,
    2026-08-30.
  - p-box: file-level data_type "pbox"; each value is an object naming its own
    construction_type, per InputProcessingModule.jl's actual deserialiser.

Usage:
    python make_power_scenarios2.py --outdir dag_ntwrk_files/power-network-scenarios
"""
import argparse
import json
import os


# --- The network, traced from Tong and Tien (2019) Figure 11 and cross-checked against ---
# --- the framework's own diamond/fork/join analysis. 23 nodes, 27 edges.                ---
EDGES = [
    (1, 2), (2, 3), (2, 6), (2, 10), (3, 4), (4, 5), (5, 13), (6, 5), (7, 8), (8, 9),
    (8, 12), (9, 10), (10, 11), (11, 19), (12, 11), (13, 14), (14, 21), (15, 13),
    (16, 15), (16, 17), (17, 14), (18, 16), (19, 20), (19, 22), (20, 21), (21, 22),
    (22, 23),
]
SOURCES = {1, 7, 18}
SINK = 23


def structural_sets(edges):
    nodes = sorted(set([u for u, v in edges] + [v for u, v in edges]))
    out = {n: [] for n in nodes}
    inn = {n: [] for n in nodes}
    for u, v in edges:
        out[u].append(v)
        inn[v].append(u)
    sources = {n for n in nodes if not inn[n]}
    sinks = {n for n in nodes if not out[n]}
    forks = {n for n in nodes if len(out[n]) >= 2}
    joins = {n for n in nodes if len(inn[n]) >= 2}
    return nodes, out, inn, sources, sinks, forks, joins


def write(path, obj):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as fh:
        json.dump(obj, fh, indent=2)


def write_edges_file(path, edges):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as fh:
        fh.write("source,destination\n")
        for u, v in edges:
            fh.write(f"{u},{v}\n")


# --- Reliability -------------------------------------------------------------------------

def reliability_files(outdir, scen, nodes, edges, link_value, data_type="Float64",
                       prior_value=1.0):
    priors = {str(n): prior_value for n in nodes}
    links = {f"({u},{v})": link_value for u, v in edges}
    write(os.path.join(outdir, scen, f"{scen}-nodepriors.json"),
          {"data_type": data_type, "nodes": priors})
    write(os.path.join(outdir, scen, f"{scen}-linkprobabilities.json"),
          {"data_type": data_type, "links": links})


def reliability_interval(outdir, scen, nodes, edges, lo, hi):
    # FIX (caught by a live 500/KeyError, "key \"type\" not found", in deserialize_probability_value):
    # every interval value object needs its own "type":"interval" tag -- the already-validated
    # make_power_scenarios.py's Interval scenario carries it; this function had dropped it.
    priors = {str(n): {"type": "interval", "lower": 1.0, "upper": 1.0} for n in nodes}
    links = {f"({u},{v})": {"type": "interval", "lower": lo, "upper": hi} for u, v in edges}
    write(os.path.join(outdir, scen, f"{scen}-nodepriors.json"),
          {"data_type": "Interval", "nodes": priors})
    write(os.path.join(outdir, scen, f"{scen}-linkprobabilities.json"),
          {"data_type": "Interval", "links": links})


def reliability_pbox(outdir, scen, nodes, edges, a_lo, a_hi, b_lo, b_hi):
    # File-level data_type "pbox"; each value names its own construction_type, per the
    # real deserialiser (InputProcessingModule.jl create_parametric_interval_pbox).
    # FIX (caught before running, re-read the deserialiser directly): the real contract is
    # "shape"/"params" (a positional array), not "distribution"/"parameters" -- and shape
    # must be "uniform", not "normal": a normal distribution has unbounded tails, so its
    # discretised p-box range runs past 1.0 and is_valid_probability correctly refuses it
    # (a real modelling error, not a bug). This is the exact same fix already applied to and
    # server-confirmed against make_power_scenarios.py's Pbox scenario, 2026-08-30 -- reused
    # here rather than re-deriving. a/b are the uniform distribution's own [lower,upper]
    # bounds, each itself given as an interval (the "imprecise uniform" construction).
    priors = {str(n): {"type": "pbox", "construction_type": "scalar", "value": 1.0}
              for n in nodes}
    links = {f"({u},{v})": {"type": "pbox", "construction_type": "parametric_interval",
                            "shape": "uniform",
                            "params": [
                                {"type": "interval", "lower": a_lo, "upper": a_hi},
                                {"type": "interval", "lower": b_lo, "upper": b_hi},
                            ]}
             for u, v in edges}
    write(os.path.join(outdir, scen, f"{scen}-nodepriors.json"),
          {"data_type": "pbox", "nodes": priors})
    write(os.path.join(outdir, scen, f"{scen}-linkprobabilities.json"),
          {"data_type": "pbox", "links": links})


# --- Flow ----------------------------------------------------------------------------------

def capacity_file(outdir, scen, edges, sources, sinks, base=60.0, derate_edge=None,
                   derate_to=None):
    recs = []
    for u, v in edges:
        if v in sinks:
            cap = "Inf"  # fixed: was flat 60, made the sink edge the trivial bottleneck
        elif derate_edge is not None and (u, v) == derate_edge:
            cap = derate_to
        else:
            cap = base
        recs.append({"source": u, "destination": v, "capacity": cap})
    write(os.path.join(outdir, scen, f"{scen}-capacities.json"),
          {"data_type": "Float64", "edges": recs})


# --- Schedule --------------------------------------------------------------------------------

ROLE_DURATION = {"source": 0.0, "sink": 0.0, "fork": 0.5, "join": 2.0, "regular": 1.0}


def role_of(n, sources, sinks, forks, joins):
    if n in sources or n in sinks:
        return "source" if n in sources else "sink"
    if n in forks:
        return "fork"
    if n in joins:
        return "join"
    return "regular"


def cpm_file(outdir, scen, nodes, edges, sources, sinks, forks, joins, interval=False,
             half_width=0.2):
    def val(x):
        if not interval:
            return x
        return {"lower": round(x * (1 - half_width), 4) if x > 0 else 0.0,
                "upper": round(x * (1 + half_width), 4) if x > 0 else 0.0}

    nd = {}
    for n in nodes:
        role = role_of(n, sources, sinks, forks, joins)
        nd[str(n)] = val(ROLE_DURATION[role])
    ed = {f"({u},{v})": (val(0.0)) for u, v in edges}
    write(os.path.join(outdir, scen, f"{scen}-cpm-inputs.json"),
          {"data_type": "Interval" if interval else "Float64",
           "time_analysis": {"node_durations": nd, "edge_delays": ed,
                             "initial_time": val(0.0)}})


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--outdir", required=True)
    args = ap.parse_args()

    nodes, out, inn, sources, sinks, forks, joins = structural_sets(EDGES)
    assert sources == SOURCES, f"source mismatch: got {sources}"
    assert sinks == {SINK}, f"sink mismatch: got {sinks}"
    print(f"{len(nodes)} nodes, {len(EDGES)} edges")
    print(f"sources {sorted(sources)}, sink {sorted(sinks)}")
    print(f"forks {sorted(forks)}, joins {sorted(joins)}")

    os.makedirs(args.outdir, exist_ok=True)
    write_edges_file(os.path.join(args.outdir, "power-network.EDGES"), EDGES)

    # Published reproduction cases (ASCE 2019, Table 5): every link at R_l, no reliable list
    for rl, tag in [(0.9, "090"), (0.99, "099"), (0.3, "030")]:
        reliability_files(args.outdir, f"Published_R{tag}", nodes, EDGES, rl)

    # Baseline: reliability at R_l=0.95, flow with unbounded sink capacity, schedule role-based
    reliability_files(args.outdir, "Baseline", nodes, EDGES, 0.95)
    capacity_file(args.outdir, "Baseline", EDGES, sources, sinks, base=60.0)
    cpm_file(args.outdir, "Baseline", nodes, EDGES, sources, sinks, forks, joins)

    # Degraded: reliability at R_l=0.80, one interior line derated, schedule scaled x2
    reliability_files(args.outdir, "Degraded", nodes, EDGES, 0.80)
    # interior line: 13->14 (a join-to-join edge on the critical chain), derated to 20
    capacity_file(args.outdir, "Degraded", EDGES, sources, sinks, base=60.0,
                  derate_edge=(13, 14), derate_to=20.0)
    nd_degraded = {}
    for n in nodes:
        role = role_of(n, sources, sinks, forks, joins)
        nd_degraded[str(n)] = ROLE_DURATION[role] * 2.0
    ed_degraded = {f"({u},{v})": 0.0 for u, v in EDGES}
    write(os.path.join(args.outdir, "Degraded", "Degraded-cpm-inputs.json"),
          {"data_type": "Float64",
           "time_analysis": {"node_durations": nd_degraded, "edge_delays": ed_degraded,
                             "initial_time": 0.0}})

    # Interval: reliability [0.90,0.97], schedule durations +/-20% of the role-based values
    reliability_interval(args.outdir, "Interval", nodes, EDGES, 0.90, 0.97)
    capacity_file(args.outdir, "Interval", EDGES, sources, sinks, base=60.0)
    cpm_file(args.outdir, "Interval", nodes, EDGES, sources, sinks, forks, joins,
             interval=True, half_width=0.2)

    # Pbox: reliability only. Bounds reused from make_power_scenarios.py's own server-
    # confirmed Pbox scenario (2026-08-30), not re-derived: uniform lower bound imprecisely
    # in [0.88,0.92], upper bound imprecisely in [0.95,0.98].
    reliability_pbox(args.outdir, "Pbox", nodes, EDGES, 0.88, 0.92, 0.95, 0.98)

    print("Done. Scenarios: Published_R090, Published_R099, Published_R030, "
          "Baseline, Degraded, Interval, Pbox")
    print("Expected reliability (Table 5, Tong and Tien 2019): "
          "R090 -> 0.85741, R099 -> 0.98969, R030 -> 0.00221 (sink 23)")
    print("Expected Baseline schedule: project value 12.5, critical chain "
          "1-2-3-4-5-13-14-21-22-23, 10 of 23 nodes critical")


if __name__ == "__main__":
    main()
