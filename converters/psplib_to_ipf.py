#!/usr/bin/env python3
"""Convert a PSPLIB single-mode (.sm) instance to IPF input files.

Usage:
    python psplib_to_ipf.py j301_1.sm [--halfwidth 0.2] [--outdir .]

Produces, in outdir:
    <name>.EDGES                 edge list: header "source,destination"
                                  then one "u,v" per line, integer ids
    float/<name>-cpm-inputs.json critical path inputs, scalar (Float64) durations
    interval/<name>-cpm-inputs.json critical path inputs, interval durations
                                  [d*(1-h), d*(1+h)] for the real activities;
                                  the dummy start and end keep duration 0

Node ids are the PSPLIB job numbers (1 = dummy start, n+2 = dummy end).
Edge values (transfer delays) are 0, because PSPLIB has no edge durations.
Resource requirements and capacities are read past and ignored: the
framework computes the precedence-only schedule.

File shapes match the server's real contract (Server/Handlers/
CriticalPathHandlers.jl): top-level "data_type" is "Float64" or "Interval",
and durations live under "time_analysis": {"node_durations", "edge_delays",
"initial_time"} -- NOT a flat "node_values"/"edge_values" pair.

Instances: https://www.om-db.wi.tum.de/psplib/  (j30, j60, j90, j120 sets)
"""
import argparse
import json
import os
import re
import sys


def parse_sm(path):
    with open(path, encoding="utf-8", errors="replace") as fh:
        lines = fh.read().splitlines()

    succ = {}
    dur = {}
    section = None
    for raw in lines:
        line = raw.strip()
        if not line:
            continue
        if line.startswith("PRECEDENCE RELATIONS"):
            section = "prec"
            continue
        if line.startswith("REQUESTS/DURATIONS"):
            section = "dur"
            continue
        if line.startswith("RESOURCEAVAILABILITIES"):
            section = None
            continue
        if section == "prec":
            if line.startswith("jobnr") or set(line) <= {"*", "-"}:
                continue
            nums = [int(x) for x in re.findall(r"\d+", line)]
            if len(nums) < 3:
                continue
            job, _modes, nsucc = nums[0], nums[1], nums[2]
            succ[job] = nums[3:3 + nsucc]
        elif section == "dur":
            if line.startswith("jobnr") or set(line) <= {"*", "-"}:
                continue
            nums = [int(x) for x in re.findall(r"\d+", line)]
            if len(nums) < 3:
                continue
            job, _mode, d = nums[0], nums[1], nums[2]
            dur[job] = d

    if not succ or not dur:
        sys.exit("Could not find PRECEDENCE RELATIONS or REQUESTS/DURATIONS in %s" % path)
    missing = set(succ) - set(dur)
    if missing:
        sys.exit("Jobs without duration: %s" % sorted(missing))
    return succ, dur


def write_outputs(name, succ, dur, halfwidth, outdir):
    edges = [(u, v) for u in sorted(succ) for v in succ[u]]

    with open(os.path.join(outdir, name + ".EDGES"), "w") as fh:
        fh.write("source,destination\n")
        for u, v in edges:
            fh.write("%d,%d\n" % (u, v))

    node_scalar = {str(j): float(dur[j]) for j in sorted(dur)}
    edge_zero = {"(%d,%d)" % (u, v): 0.0 for u, v in edges}

    scalar = {
        "data_type": "Float64",
        "description": "PSPLIB %s, precedence-only, resources ignored" % name,
        "time_analysis": {
            "node_durations": node_scalar,
            "edge_delays": edge_zero,
            "initial_time": 0,
        },
    }
    scalar_dir = os.path.join(outdir, "float")
    os.makedirs(scalar_dir, exist_ok=True)
    with open(os.path.join(scalar_dir, name + "-cpm-inputs.json"), "w") as fh:
        json.dump(scalar, fh, indent=2)

    node_interval = {}
    for j in sorted(dur):
        d = float(dur[j])
        if d == 0.0:
            node_interval[str(j)] = {"type": "interval", "lower": 0.0, "upper": 0.0}
        else:
            node_interval[str(j)] = {
                "type": "interval",
                "lower": round(d * (1.0 - halfwidth), 6),
                "upper": round(d * (1.0 + halfwidth), 6),
            }
    edge_zero_iv = {
        k: {"type": "interval", "lower": 0.0, "upper": 0.0} for k in edge_zero
    }
    interval = {
        "data_type": "Interval",
        "description": "PSPLIB %s, durations +/- %g, precedence-only" % (name, halfwidth),
        "time_analysis": {
            "node_durations": node_interval,
            "edge_delays": edge_zero_iv,
            "initial_time": 0,
        },
    }
    interval_dir = os.path.join(outdir, "interval")
    os.makedirs(interval_dir, exist_ok=True)
    with open(os.path.join(interval_dir, name + "-cpm-inputs.json"), "w") as fh:
        json.dump(interval, fh, indent=2)

    n = len(dur)
    sources = [j for j in dur if not any(j in s for s in succ.values())]
    sinks = [j for j in dur if not succ.get(j)]
    print("%s: %d nodes, %d edges, sources %s, sinks %s, real activities %d"
          % (name, n, len(edges), sources, sinks, sum(1 for d in dur.values() if d > 0)))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("sm_file")
    ap.add_argument("--halfwidth", type=float, default=0.2,
                    help="relative half-width for the interval variant (default 0.2)")
    ap.add_argument("--outdir", default=".")
    args = ap.parse_args()
    succ, dur = parse_sm(args.sm_file)
    name = os.path.splitext(os.path.basename(args.sm_file))[0]
    os.makedirs(args.outdir, exist_ok=True)
    write_outputs(name, succ, dur, args.halfwidth, args.outdir)


if __name__ == "__main__":
    main()
