#!/usr/bin/env python3
"""Orient IEEE RTS-24 into a DAG for the framework, by a DC power flow at
peak load (the case file's own bus Pd values, which are the RTS's published
peak-load case) — same orientation argument used for Net3.

DC power flow (standard linear approximation, r and shunt b ignored, only
branch reactance x used): B*theta = P_injection, slack bus 13 (bus type 3)
fixed at theta=0. Generation dispatch at peak: each generator's Pg is scaled
uniformly (same participation factor for every unit) so that total generation
exactly equals total demand — a standard, documented simplifying assumption
for an illustrative DC solve, not the file's own (unscaled) base-case Pg.

Each branch's real-power flow sign gives its physical direction at peak load;
edges are oriented that way. RTS-24 is meshed, so orienting by flow direction
can still leave directed cycles — any that remain are broken by dropping the
smallest-magnitude-flow edge in the cycle (logged, not silently discarded),
repeated until acyclic, exactly as specified.

Output: dag_ntwrk_files-shaped files (this network's own home is
validation/flow/rts24/, not dag_ntwrk_files/, since it's a case study, not a
corpus network) plus a full log of every decision made.

Usage: python orient_rts24.py
"""
import json
import os

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
with open(os.path.join(HERE, "rts24_raw_data.json")) as f:
    DATA = json.load(f)

bus_rows = DATA["bus"]["rows"]
gen_rows = DATA["generator"]["rows"]
branch_rows = DATA["branch"]["rows"]

bus_ids = [r[0] for r in bus_rows]
bus_type = {r[0]: r[1] for r in bus_rows}
bus_pd = {r[0]: r[2] for r in bus_rows}
slack_bus = next(r[0] for r in bus_rows if r[1] == 3)

# --- peak-load generator dispatch: uniform participation factor -----------
total_pd = sum(bus_pd.values())
total_pmax = sum(r[3] for r in gen_rows)
scale = total_pd / total_pmax
gen_pg_scaled = [(r[0], r[3] * scale) for r in gen_rows]  # (bus, dispatched MW)
gen_by_bus = {}
for bus, pg in gen_pg_scaled:
    gen_by_bus[bus] = gen_by_bus.get(bus, 0.0) + pg

# --- DC power flow ----------------------------------------------------------
n = len(bus_ids)
idx = {b: i for i, b in enumerate(bus_ids)}
B = np.zeros((n, n))
branches = []  # (fbus, tbus, x, rateA)
for fbus, tbus, r, x, b, rateA, rateB, rateC, status in branch_rows:
    if status != 1:
        continue
    branches.append((fbus, tbus, x, rateA))
    y = 1.0 / x
    fi, ti = idx[fbus], idx[tbus]
    B[fi, fi] += y
    B[ti, ti] += y
    B[fi, ti] -= y
    B[ti, fi] -= y

P = np.zeros(n)
for b in bus_ids:
    P[idx[b]] = gen_by_bus.get(b, 0.0) - bus_pd.get(b, 0.0)

# slack reference: drop its row/col, solve reduced system, theta_slack = 0
keep = [i for i in range(n) if bus_ids[i] != slack_bus]
B_red = B[np.ix_(keep, keep)]
P_red = P[keep]
theta_red = np.linalg.solve(B_red, P_red)
theta = np.zeros(n)
for j, i in enumerate(keep):
    theta[i] = theta_red[j]

# --- orient every branch by its solved flow sign ---------------------------
oriented = []  # (u, v, capacity_MVA, flow_MW, original_fbus, original_tbus)
for fbus, tbus, x, rateA in branches:
    flow = (theta[idx[fbus]] - theta[idx[tbus]]) / x  # MW, fbus->tbus positive
    if flow >= 0:
        oriented.append((fbus, tbus, rateA, flow, fbus, tbus))
    else:
        oriented.append((tbus, fbus, rateA, -flow, fbus, tbus))

log_lines = []
log_lines.append(f"total_pd = {total_pd} MW, total_pmax = {total_pmax} MW, dispatch scale = {scale:.6f}")
log_lines.append(f"slack bus = {slack_bus}")
log_lines.append("")
log_lines.append("oriented branches (u -> v, capacity MVA, |flow| MW, original file fbus/tbus):")
for u, v, cap, flow, ofb, otb in sorted(oriented, key=lambda t: (t[0], t[1])):
    reversed_flag = " (REVERSED from file order)" if (u, v) != (ofb, otb) else ""
    log_lines.append(f"  {u:>3} -> {v:<3} cap={cap:>5.0f} MVA  |flow|={flow:8.3f} MW{reversed_flag}")

# --- break any directed cycles: drop the weakest-flow edge in each cycle --
# RTS-24 has 4 pairs of parallel (double-circuit) lines between the same bus
# pair, oriented identically (equal-impedance lines split flow equally, so
# both members of a pair land on the same direction) — the framework's own
# capacity representation is Dict{(u,v),Float64}, one scalar per ordered
# pair, so parallel lines combine into one edge with SUMMED capacity and
# SUMMED flow, not one silently overwriting the other.
edges = {}
n_parallel = 0
for u, v, cap, flow, _, _ in oriented:
    if (u, v) in edges:
        n_parallel += 1
        prev_cap, prev_flow = edges[(u, v)]
        edges[(u, v)] = (prev_cap + cap, prev_flow + flow)
    else:
        edges[(u, v)] = (cap, flow)
dropped = []


def find_cycle(edge_keys):
    adj = {}
    for (u, v) in edge_keys:
        adj.setdefault(u, []).append(v)
    color = {}  # 0=unvisited,1=in-stack,2=done
    parent = {}

    def dfs(u, path):
        color[u] = 1
        path.append(u)
        for v in adj.get(u, []):
            if color.get(v, 0) == 0:
                parent[v] = u
                cyc = dfs(v, path)
                if cyc:
                    return cyc
            elif color.get(v) == 1:
                # found a cycle: v is an ancestor on the current path
                start = path.index(v)
                return path[start:] + [v]
        path.pop()
        color[u] = 2
        return None

    for node in list(adj.keys()):
        if color.get(node, 0) == 0:
            cyc = dfs(node, [])
            if cyc:
                return cyc
    return None


edge_keys = set(edges.keys())
while True:
    cyc = find_cycle(edge_keys)
    if cyc is None:
        break
    cyc_edges = [(cyc[i], cyc[i + 1]) for i in range(len(cyc) - 1)]
    weakest = min(cyc_edges, key=lambda e: edges[e][1])
    edge_keys.discard(weakest)
    dropped.append((weakest, edges[weakest], cyc))

log_lines.append("")
if dropped:
    log_lines.append(f"{len(dropped)} edge(s) dropped to break directed cycles found after DC-flow orientation:")
    for (u, v), (cap, flow), cyc in dropped:
        log_lines.append(f"  dropped {u} -> {v} (cap={cap} MVA, |flow|={flow:.3f} MW, weakest in cycle {cyc})")
else:
    log_lines.append("No directed cycles remained after DC-flow orientation — nothing dropped.")

final_edges = sorted(edge_keys)
log_lines.append("")
log_lines.append(f"final DAG: {n} nodes, {len(final_edges)} edges (from {len(oriented)} oriented, {len(dropped)} dropped)")

with open(os.path.join(HERE, "orientation_log.txt"), "w") as f:
    f.write("\n".join(log_lines) + "\n")
print("\n".join(log_lines))

# --- write the .EDGES + capacities/inputs in the real server contract -----
with open(os.path.join(HERE, "rts24.EDGES"), "w") as f:
    f.write("source,destination\n")
    for u, v in final_edges:
        f.write(f"{u},{v}\n")

edge_caps = [
    {"source": u, "destination": v, "capacity": edges[(u, v)][0]} for (u, v) in final_edges
]
# node capacities: generator buses get their true nameplate Pmax (not the
# scaled peak-load dispatch used only for the DC solve) as a node capacity;
# load buses get no node capacity (an inbound cap on a sink is not meaningful
# here). Computed as a clean dict first — a single comprehension that both
# builds and filters on the same per-bus total inside its own iterable
# expression is a real Python scoping bug (the inner `b` isn't bound yet
# when the iterable is evaluated, and silently falls back to whatever `b`
# is left over in the enclosing scope from an earlier plain `for` loop).
gen_pmax_by_bus = {}
for bus, pg, qg, pmax, pmin, status in gen_rows:
    gen_pmax_by_bus[bus] = gen_pmax_by_bus.get(bus, 0.0) + pmax
node_caps = [
    {"node": bus, "capacity": total}
    for bus, total in sorted(gen_pmax_by_bus.items())
    if total > 0
]
payload = {
    "data_type": "Float64",
    "edges": edge_caps,
    "nodes": node_caps,
    "description": (
        "IEEE RTS-24 (MATPOWER case24_ieee_rts.m), oriented by a DC power flow "
        f"at peak load (dispatch scale {scale:.6f}, uniform participation factor). "
        f"{len(dropped)} line(s) dropped to break directed cycles — see orientation_log.txt. "
        "Edge capacities are branch rateA (MVA); node capacities on generator buses are "
        "total nameplate Pmax (MW)."
    ),
}
with open(os.path.join(HERE, "rts24-capacities.json"), "w") as f:
    json.dump(payload, f, indent=2)

print(f"\nwrote rts24.EDGES, rts24-capacities.json, orientation_log.txt in {HERE}")

# --- net-injection super-source/super-sink model ---------------------------
# Every bus's net injection = nameplate generation capacity minus local peak
# demand. Positive => the bus can export beyond its own local demand once
# served locally first; negative => the bus needs to import from the network
# beyond what its own (if any) local generation can cover. A mixed bus (both
# local generation and local load) appears ONCE, under its net sign alone —
# e.g. bus 15 has 215 MW of local generation but 317 MW of local load, so it
# nets to a SINK (-102 MW) despite having a generator. The graph stays the
# same oriented DAG (post cycle-break); S and T are the only additions.
#
# This closes both limitations noted for the structural-subset model:
# (1) deliverable throughput is now measured against the true system-wide
#     balance (self-served local demand nets out before ever touching the
#     network, exactly as physical net injection accounting requires), not
#     just the buses with zero local demand or zero local generation; and
# (2) a generator failure is now literally an S->bus edge failure, so the
#     existing single-edge-failure ranking covers it directly — no separate
#     machinery needed, "generator failures become node removals" in the
#     sense that losing bus b's generation removes (or shrinks) edge (S, b).
S_NODE, T_NODE = 0, 25  # outside 1..24 — no collision with any real bus ID
net_injection = {b: gen_pmax_by_bus.get(b, 0.0) - bus_pd.get(b, 0.0) for b in bus_ids}
net_export = {b: v for b, v in sorted(net_injection.items()) if v > 0}   # S -> b
net_import = {b: -v for b, v in sorted(net_injection.items()) if v < 0}  # b -> T (net load, positive)

netinj_edges = dict(edges)  # same oriented line DAG, keyed (u,v) -> (cap, flow)
for b, v in net_export.items():
    netinj_edges[(S_NODE, b)] = (v, None)
for b, v in net_import.items():
    netinj_edges[(b, T_NODE)] = (v, None)
netinj_final_edges = sorted(netinj_edges.keys())

UNCONSTRAINED_GEN_CAP = 1.0e6  # MVA sentinel, far above anything the lines could carry —
# stands in for "generation is not itself the limit" in the comparison scenario below.

with open(os.path.join(HERE, "rts24-netinjection.EDGES"), "w") as f:
    f.write("source,destination\n")
    for u, v in netinj_final_edges:
        f.write(f"{u},{v}\n")


def _write_netinjection_capacities(path, unconstrained_generation):
    edge_caps = []
    for (u, v) in netinj_final_edges:
        if unconstrained_generation and u == S_NODE:
            cap = UNCONSTRAINED_GEN_CAP
        else:
            cap = netinj_edges[(u, v)][0]
        edge_caps.append({"source": u, "destination": v, "capacity": cap})
    payload = {
        "data_type": "Float64",
        "edges": edge_caps,
        "nodes": [],
        "description": (
            f"IEEE RTS-24 net-injection model: super-source {S_NODE} -> each net-export bus "
            "(capacity = generator nameplate Pmax minus local peak load), each net-import bus "
            f"-> super-sink {T_NODE} (capacity = local peak load minus local generation). "
            + ("Generation-side (S->bus) edges use a large sentinel capacity here — the "
               "unconstrained-generation comparison scenario. "
               if unconstrained_generation else
               "Generation-side (S->bus) edges are capped at generator nameplate Pmax net of "
               "local load — the primary, generator-limited scenario. ")
            + "Line edges unchanged from rts24-capacities.json (branch rateA, MVA)."
        ),
    }
    with open(path, "w") as f:
        json.dump(payload, f, indent=2)


_write_netinjection_capacities(os.path.join(HERE, "rts24-netinjection-capacities.json"), unconstrained_generation=False)
_write_netinjection_capacities(os.path.join(HERE, "rts24-netinjection-unconstrained-capacities.json"), unconstrained_generation=True)

net_log = []
net_log.append("IEEE RTS-24 net-injection accounting (generator nameplate Pmax - local peak Pd)")
net_log.append(f"super-source node = {S_NODE}, super-sink node = {T_NODE}")
net_log.append("")
net_log.append(f"{'bus':>4} {'gen_Pmax':>10} {'Pd':>8} {'net':>10}  role")
for b in bus_ids:
    gen = gen_pmax_by_bus.get(b, 0.0)
    pd = bus_pd.get(b, 0.0)
    net = net_injection[b]
    role = f"S -> {b}  (net export)" if net > 0 else (f"{b} -> T  (net import)" if net < 0 else "neither (net = 0)")
    net_log.append(f"{b:>4} {gen:>10.1f} {pd:>8.1f} {net:>10.1f}  {role}")
net_log.append("")
sum_export = sum(net_export.values())
sum_import = sum(net_import.values())
net_log.append(f"total system peak demand (all 17 load buses)      = {total_pd:.1f} MW")
net_log.append(f"total generator nameplate capacity (all 33 units) = {sum(gen_pmax_by_bus.values()):.1f} MW")
net_log.append(f"sum of positive net injections (S-side, export)   = {sum_export:.1f} MW across {len(net_export)} buses")
net_log.append(f"sum of negative net injections (T-side, net import demand) = {sum_import:.1f} MW across {len(net_import)} buses")
net_log.append(f"locally self-served demand (nameplate availability, no network needed) = total_pd - net_import_sum = {total_pd - sum_import:.1f} MW")
net_log.append(f"=> S-T max-flow is capped above by min(export_sum, import_sum) = {min(sum_export, sum_import):.1f} MW before any line/generator capacity binds")
net_log.append(f"=> deliverable throughput as a share of total system peak demand = flow / {total_pd:.1f} MW; self-served portion is delivered unconditionally as long as each net-export bus's own local generation covers its own local load")
with open(os.path.join(HERE, "net_injection_log.txt"), "w") as f:
    f.write("\n".join(net_log) + "\n")
print("\n".join(net_log))
print(f"\nwrote rts24-netinjection.EDGES, rts24-netinjection-capacities.json, "
      f"rts24-netinjection-unconstrained-capacities.json, net_injection_log.txt in {HERE}")
