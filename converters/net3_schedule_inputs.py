#!/usr/bin/env python3
"""Net3 case study, section 4: schedule (critical path) inputs.

Interpretation chosen (of the two the requirements doc offers): the RESTORATION PROGRAMME
after a shutdown -- activities are the recommissioning of each pipe, pump and tank, with
durations for isolate, flush, pressure test and return to service. (net3_case_study_
requirements.md calls this option "(a)"; thesis_working_notes.md's section 3b describes the
same choice under the label "(b)" -- the two documents' lettering is swapped, but both steer
the same way: this is "closer to the CPM literature" per the working notes, and the doc's own
text calls the transit-time alternative the fallback "if (a) is not wanted".)

Model: pipes and pumps are the graph's EDGES (their recommissioning is what takes time on a
route); reservoirs and junctions are not physical assets being recommissioned (a reservoir is
a source, a junction is a demand point with no component of its own) and get NODE duration 0;
tanks get a NODE duration (an assumed value, see below). Edge delays carry the pipe/pump work;
node durations carry only the tank's own work, else 0.

GROUNDING, pipe activity (isolate + pressure test + flush + disinfect + bacteriological
sampling), from City of Aurora, "Testing and Disinfecting Requirements for New Water Mains"
(engineering specification, undated PDF, retrieved 30 August 2026), which itself cites AWWA
C600-17 (ductile iron mains), AWWA C605-13/17 (PVC/PVCO mains) for testing, and AWWA C651-14
for disinfection -- the standard national references for this exact procedure, not this one
city's own invention:
  - Isolate: NOT given a duration by the source (implied as setup, not timed). Assumed: 1 hour
    for valve operation to isolate a section. Stated as assumed because no published figure was
    found for this specific step.
  - Pressure/leak test: 2 hours, fixed (Aurora spec, "Test Duration" section, citing AWWA
    C600-17/C605-17).
  - Flush: computed per pipe, not assumed -- minimum scour velocity 3.0 ft/s (Aurora spec,
    citing AWWA C600-17/C605-13), time = (3 pipe-volumes at that velocity) / (pipe's own cross-
    sectional area * 3.0 ft/s) = 3 * length / velocity, independent of diameter algebraically
    (the area cancels), so flush time = 3 * length_ft / (3.0 ft/s), in seconds, then to hours.
    (Preliminary and final flush combined into this one computed figure -- a stated
    simplification; the source calls for both but does not separately quantify the final one.)
  - Chlorination hold: 24 hours minimum, fixed (Aurora spec citing AWWA C651-14: "the
    chlorinated water shall be retained in the main for at least 24 hours").
  - Bacteriological sampling: 24 hours (first sample, undisturbed) + 16 hours (resample,
    undisturbed) = 40 hours minimum, fixed (Aurora spec, "Bacteriological Samples" section).
  Total per real pipe = 1 + 2 + flush(pipe-specific) + 24 + 40 = 67 hours + flush.
  This total is dominated by the two fixed regulatory hold times (64 of the 67 fixed hours),
  which is realistic, not a modelling artefact: real water-main restoration is gated by
  disinfection procedure far more than by any one pipe's own geometry. Stated as a finding for
  RESULTS.md, not engineered around.

GROUNDING, pump activity: the Aurora source's own scope statement names "pressure reducing and
pump stations" as covered by the same procedure, but gives no pump-specific duration distinct
from the main testing sequence. Assumed: 8 hours total (isolate/lock-out, inspect, re-energise
and verify) -- stated as assumed, no published figure found for this specific step.

GROUNDING, tank node duration: the Aurora source explicitly excludes tanks from its own scope
("This section does not include disinfecting procedures for water storage tanks", page 1).
Assumed: 24 hours (inspection, cleaning, refill cycle) -- stated as assumed, explicitly outside
the cited source's own coverage.

Edge delays for the 3 dummy tank-connector pipes (see net3_reliability_inputs.py) and for pump
edges that are ALSO a reservoir's own edge: no special case is needed here (unlike reliability
and capacity, a schedule duration is not physically tied to "being a reservoir edge"), so dummy
connectors get the ordinary computed pipe value like any other short pipe (their flush time is
near-zero at their placeholder length, so their total is close to the 67-hour fixed floor);
pump 10 gets the pump total like any other pump.

Interval scenario: +/-20% relative half-width on every non-zero duration, matching this
session's established convention for CPM interval scenarios elsewhere in the thesis.

Usage:
    python net3_schedule_inputs.py --outdir dag_ntwrk_files/net3/net3-scenarios
"""
import argparse
import json
import os
import re

NET3DIR_DEFAULT = "dag_ntwrk_files/net3"
DUMMY_CONNECTOR_LENGTH = 99
DUMMY_CONNECTOR_DIAMETER = 99

ISOLATE_H = 1.0
PRESSURE_TEST_H = 2.0
CHLORINATION_HOLD_H = 24.0
BACT_SAMPLING_H = 24.0 + 16.0
FLUSH_VELOCITY_FTPS = 3.0
PUMP_TOTAL_H = 8.0
TANK_NODE_DURATION_H = 24.0
RELATIVE_HALF_WIDTH = 0.20


def flush_hours(length_ft):
    seconds = 3.0 * length_ft / FLUSH_VELOCITY_FTPS
    return seconds / 3600.0


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


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--net3dir", default=NET3DIR_DEFAULT)
    ap.add_argument("--outdir", required=True)
    args = ap.parse_args()

    id_of, node_type = load_node_mapping(args.net3dir)
    edges = load_edges(args.net3dir)
    pipes, pumps = parse_inp(os.path.join(args.net3dir, "Net3.inp"))

    node_pair_to_link = {}
    for link_id, rec in pipes.items():
        u, v = id_of[rec["node1"]], id_of[rec["node2"]]
        node_pair_to_link[frozenset((u, v))] = ("pipe", link_id, rec)
    for link_id, rec in pumps.items():
        u, v = id_of[rec["node1"]], id_of[rec["node2"]]
        node_pair_to_link[frozenset((u, v))] = ("pump", link_id, rec)

    nodes = sorted(id_of.values())
    node_duration = {n: (TANK_NODE_DURATION_H if node_type[n] == "tank" else 0.0) for n in nodes}

    edge_duration = {}
    for (u, v) in edges:
        kind, link_id, rec = node_pair_to_link[frozenset((u, v))]
        if kind == "pump":
            edge_duration[(u, v)] = PUMP_TOTAL_H
        else:
            total = ISOLATE_H + PRESSURE_TEST_H + flush_hours(rec["length_ft"]) + CHLORINATION_HOLD_H + BACT_SAMPLING_H
            edge_duration[(u, v)] = total

    def val(x, interval):
        if not interval or x == 0.0:
            return x
        return {"lower": round(x * (1 - RELATIVE_HALF_WIDTH), 4), "upper": round(x * (1 + RELATIVE_HALF_WIDTH), 4)}

    def build(name, interval=False):
        nd = {str(n): val(node_duration[n], interval) for n in nodes}
        ed = {f"({u},{v})": val(edge_duration[(u, v)], interval) for (u, v) in edges}
        write(os.path.join(args.outdir, name, f"{name}-cpm-inputs.json"),
              {"data_type": "Interval" if interval else "Float64",
               "time_analysis": {"node_durations": nd, "edge_delays": ed, "initial_time": 0.0}})

    build("Baseline", interval=False)
    build("Interval", interval=True)
    # Degraded reuses Baseline's schedule (its own scenario story is a flow event, a derated
    # trunk main and a failed pump, not a schedule change) -- write the same file so the folder
    # is complete for a CPM run if wanted.
    build("Degraded", interval=False)

    durations = list(edge_duration.values())
    print(f"pipe/pump edge durations: n={len(durations)} min={min(durations):.2f}h "
          f"max={max(durations):.2f}h mean={sum(durations)/len(durations):.2f}h")
    print(f"tank node duration = {TANK_NODE_DURATION_H}h ({sum(1 for t in node_duration.values() if t>0)} tanks)")
    print(f"Baseline / Interval / Degraded cpm-inputs written to {args.outdir}")


if __name__ == "__main__":
    main()
