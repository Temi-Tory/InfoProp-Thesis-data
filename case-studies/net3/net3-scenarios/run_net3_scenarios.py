#!/usr/bin/env python3
"""Net3 case study, section 5: run every toolkit on every scenario it supports through the
live server, save request + response JSON per run, and write a summary CSV.

Baseline: reliability, flow, schedule (LongestPath), MaxScaling (multiplicative, using the
          Baseline reliability edge probabilities as the CPM factors -- see build_maxscaling_
          payload below).
Degraded: reliability, flow (Baseline schedule reused, not a schedule scenario).
Interval: reliability, schedule (LongestPath with the domination split).

Usage: python run_net3_scenarios.py
(server must already be running on localhost:8080)
"""
import json
import os
import urllib.request

REPO = r"C:\Development\Info_Prop_Framework_Project\Info_Prop_Framework_Project"
NET_DIR = os.path.join(REPO, "dag_ntwrk_files", "net3")
SCEN_DIR = os.path.join(NET_DIR, "net3-scenarios")
OUT_DIR = os.path.dirname(os.path.abspath(__file__))
BASE = "http://localhost:8080"


def post(path, payload, timeout=120):
    data = json.dumps(payload).encode()
    req = urllib.request.Request(BASE + path, data=data, headers={"Content-Type": "application/json"}, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return resp.status, json.loads(resp.read())
    except urllib.error.HTTPError as e:
        body = e.read()
        try:
            return e.code, json.loads(body)
        except Exception:
            return e.code, {"raw": body.decode(errors="replace")}


def save(name, payload, resp):
    write_json(os.path.join(OUT_DIR, "responses", f"{name}_request.json"), payload)
    write_json(os.path.join(OUT_DIR, "responses", f"{name}_response.json"), resp)


def write_json(path, obj):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        json.dump(obj, f, indent=2)


rows = []


def run_reliability(scen):
    payload = {
        "networkPath": NET_DIR,
        "nodepriorsPath": f"net3-scenarios/{scen}/{scen}-nodepriors.json",
        "linkprobsPath": f"net3-scenarios/{scen}/{scen}-linkprobabilities.json",
        "includeExactInference": True,
        "includeDiamondAnalysis": True,
    }
    status, resp = post("/probability-propagation", payload)
    save(f"{scen}_reliability", payload, resp)
    ok = status == 200 and resp.get("success", False)
    print(f"{scen:10s} reliability  HTTP {status}  success={ok}")
    rows.append({"scenario": scen, "toolkit": "reliability", "http": status, "success": ok})


def run_flow(scen):
    payload = {
        "networkPath": NET_DIR,
        "capacitiesPath": f"net3-scenarios/{scen}/{scen}-capacities.json",
        "analysisOptions": {"kFailure": 2, "cutLimit": 200},
    }
    status, resp = post("/flow-analysis", payload)
    save(f"{scen}_flow", payload, resp)
    ok = status == 200 and resp.get("success", False)
    max_flow = resp.get("capacity_result", {}).get("flow", {}).get("max_flow") if ok else None
    print(f"{scen:10s} flow         HTTP {status}  success={ok}  max_flow={max_flow}")
    rows.append({"scenario": scen, "toolkit": "flow", "http": status, "success": ok, "max_flow": max_flow})


def run_schedule(scen):
    payload = {
        "networkPath": NET_DIR,
        "cpmPath": f"net3-scenarios/{scen}/{scen}-cpm-inputs.json",
    }
    status, resp = post("/critical-path-analysis", payload)
    save(f"{scen}_schedule", payload, resp)
    ok = status == 200 and resp.get("success", False)
    pv = resp.get("critical_path_result", {}).get("time_result", {}).get("project_value") if ok else None
    print(f"{scen:10s} schedule     HTTP {status}  success={ok}  project_value={pv}")
    rows.append({"scenario": scen, "toolkit": "schedule", "http": status, "success": ok, "project_value": pv})


def run_maxscaling():
    """MaxScaling (multiplicative CPM mode): the requirements doc asks for the reliability edge
    probabilities to be used AS the CPM multiplicative factors, reporting the most reliable
    supply route to each demand node. Built as its own cpm-inputs file (not reusing Baseline's
    time-additive one): edge_delays = Baseline reliability link probabilities (the factors to
    multiply along a route), node_durations = 1.0 (multiplicative identity) everywhere, so a
    route's combined value is the product of its edge reliabilities -- the standard reliability-
    of-best-path reading. initial_time = 1.0 (multiplicative identity), not 0.0.
    """
    with open(os.path.join(SCEN_DIR, "Baseline", "Baseline-linkprobabilities.json")) as f:
        rel = json.load(f)
    edgelist_path = os.path.join(NET_DIR, "net3.EDGES")
    nodes = set()
    with open(edgelist_path) as f:
        next(f)
        for line in f:
            u, v = line.strip().split(",")
            nodes.add(int(u)); nodes.add(int(v))

    node_durations = {str(n): 1.0 for n in nodes}
    edge_delays = {k: v for k, v in rel["links"].items()}
    ms_path = os.path.join(SCEN_DIR, "MaxScaling", "MaxScaling-cpm-inputs.json")
    write_json(ms_path, {"data_type": "Float64",
                          "time_analysis": {"node_durations": node_durations,
                                            "edge_delays": edge_delays,
                                            "initial_time": 1.0}})

    payload = {
        "networkPath": NET_DIR,
        "cpmPath": "net3-scenarios/MaxScaling/MaxScaling-cpm-inputs.json",
        "mode": "max_scaling",
    }
    status, resp = post("/critical-path-analysis", payload)
    save("MaxScaling_schedule", payload, resp)
    ok = status == 200 and resp.get("success", False)
    print(f"MaxScaling schedule     HTTP {status}  success={ok}")
    if not ok:
        print("  MaxScaling error:", resp.get("error"))
    rows.append({"scenario": "MaxScaling", "toolkit": "schedule-multiplicative", "http": status, "success": ok})


run_reliability("Baseline")
run_flow("Baseline")
run_schedule("Baseline")
run_maxscaling()

# No Degraded reliability scenario -- the requirements doc's section 2 defines only Baseline
# and Interval reliability value forms; Degraded is a flow/capacity scenario only (one trunk
# main derated, one pump out), matching its own section-3 definition.
run_flow("Degraded")

run_reliability("Interval")
run_schedule("Interval")

import csv
with open(os.path.join(OUT_DIR, "net3_scenarios_summary.csv"), "w", newline="") as f:
    fieldnames = sorted({k for r in rows for k in r.keys()})
    w = csv.DictWriter(f, fieldnames=fieldnames)
    w.writeheader()
    for r in rows:
        w.writerow(r)

print(f"\nwrote {len(rows)} rows to net3_scenarios_summary.csv, raw request/response JSON in responses/")
