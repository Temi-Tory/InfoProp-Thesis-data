#!/usr/bin/env python3
"""Regenerate fig04_floats.pdf from the toolkit's interval critical-path result.

Usage:
    python make_fig04_floats.py time-longest-path-interval-result.json [out.pdf]

Reads critical_path_result.time_result from the server response JSON and draws
the exact float range of every node. Nodes in possibly_critical are black,
others grey; nodes in necessarily_critical (both bounds zero) are drawn as a
point at zero.
"""
import json
import sys

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt


def main():
    src = sys.argv[1]
    out = sys.argv[2] if len(sys.argv) > 2 else "fig04_floats.pdf"
    r = json.load(open(src))["critical_path_result"]["time_result"]
    margin = {int(k): (v["lower"], v["upper"]) for k, v in r["margin"].items()}
    nec = set(r["necessarily_critical"])
    pos = set(r["possibly_critical"])
    nodes = sorted(margin)

    fig, ax = plt.subplots(figsize=(7.2, 3.6))
    for i, n in enumerate(nodes):
        lo, hi = margin[n]
        if n in nec:
            ax.plot(i, 0, marker="s", color="black", ms=5)
        else:
            ax.plot([i, i], [lo, hi], color="black" if n in pos else "0.6",
                    lw=3, solid_capstyle="butt")
    ax.set_xticks(range(len(nodes)))
    ax.set_xticklabels(nodes, fontsize=7)
    ax.set_xlabel("Node")
    ax.set_ylabel("Float (time units)")
    ax.set_ylim(-1, max(hi for _, hi in margin.values()) * 1.05)
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)
    plt.tight_layout()
    plt.savefig(out)


if __name__ == "__main__":
    main()
