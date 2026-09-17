#!/usr/bin/env python3
"""Generate thesis-ready tables and figures from flagship benchmark outputs (Config A/B)."""

from __future__ import annotations

import csv
import math
import re
import shutil
import subprocess
from pathlib import Path

import matplotlib.pyplot as plt


def parse_value_map(text: str) -> dict[int, float]:
    pairs = re.findall(r"(\d+)\s*=>\s*([-+]?\d+(?:\.\d+)?)", text)
    return {int(k): float(v) for k, v in pairs}


def parse_output(path: Path) -> dict:
    data: dict = {
        "config_mode": "",
        "baseline_max_flow": math.nan,
        "saturated_edge_count": 0,
        "free_zone_size": 0,
        "mincuts_total": 0,
        "spof_nodes_count": 0,
        "sink_flow": {},
        "node_cap_sink_flow": {},
        "critical_edges": [],
        "mincuts": [],
        "degradation": [],
        "upgrade_ineffective_gateway": False,
    }

    critical_pattern = re.compile(
        r"^critical_edge=\((\d+)->(\d+)\)\s*([^,]+),drop=([-+]?\d+(?:\.\d+)?),perturbed_flow=([-+]?\d+(?:\.\d+)?)"
    )
    cut_pattern = re.compile(r"^mincut_(\d+)_crossing_edges=\[(.*)\]")
    deg_pattern = re.compile(r"^degradation_alpha=([-+]?\d+(?:\.\d+)?),max_flow=([-+]?\d+(?:\.\d+)?)")

    with path.open("r", encoding="utf-8") as f:
        for raw in f:
            line = raw.strip()
            if not line:
                continue

            if line.startswith("config_mode="):
                data["config_mode"] = line.split("=", 1)[1]
            elif line.startswith("baseline_max_flow="):
                data["baseline_max_flow"] = float(line.split("=", 1)[1])
            elif line.startswith("saturated_edge_count="):
                data["saturated_edge_count"] = int(line.split("=", 1)[1])
            elif line.startswith("free_zone_size="):
                data["free_zone_size"] = int(line.split("=", 1)[1])
            elif line.startswith("mincuts_total="):
                data["mincuts_total"] = int(line.split("=", 1)[1])
            elif line.startswith("spof_nodes="):
                payload = line.split("=", 1)[1]
                if payload.endswith("[]"):
                    data["spof_nodes_count"] = 0
                else:
                    data["spof_nodes_count"] = len(re.findall(r"\d+", payload))
            elif line.startswith("sink_flow="):
                data["sink_flow"] = parse_value_map(line)
            elif line.startswith("node_cap_sink_flow="):
                data["node_cap_sink_flow"] = parse_value_map(line)
            elif line.startswith("upgrade_threshold=edge=(134->136)") or line.startswith("upgrade_threshold=edge=(135->136)"):
                if "ineffective=true" in line:
                    data["upgrade_ineffective_gateway"] = True
            else:
                cm = critical_pattern.match(line)
                if cm:
                    u, v, name, drop, pf = cm.groups()
                    data["critical_edges"].append(
                        {
                            "edge": f"({u}->{v})",
                            "label": name.strip(),
                            "drop": float(drop),
                            "perturbed_flow": float(pf),
                        }
                    )
                    continue

                cutm = cut_pattern.match(line)
                if cutm:
                    idx, payload = cutm.groups()
                    crossings = re.findall(r"\((\d+),\s*(\d+)\)", payload)
                    crossing_text = ", ".join([f"({u}->{v})" for u, v in crossings])
                    data["mincuts"].append({"cut": int(idx), "crossing": crossing_text})
                    continue

                dm = deg_pattern.match(line)
                if dm:
                    alpha, flow = dm.groups()
                    data["degradation"].append((float(alpha), float(flow)))

    data["critical_edges"].sort(key=lambda x: x["drop"], reverse=True)
    data["mincuts"].sort(key=lambda x: x["cut"])
    data["degradation"].sort(key=lambda x: x[0], reverse=True)
    return data


def write_csv(path: Path, headers: list[str], rows: list[list]):
    with path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(headers)
        writer.writerows(rows)


def write_markdown(path: Path, tables: list[tuple[str, list[str], list[list]]], fig_notes: list[str]):
    lines: list[str] = []
    for title, headers, rows in tables:
        lines.append(f"## {title}")
        lines.append("")
        lines.append("| " + " | ".join(headers) + " |")
        lines.append("| " + " | ".join(["---"] * len(headers)) + " |")
        for row in rows:
            lines.append("| " + " | ".join(str(x) for x in row) + " |")
        lines.append("")

    lines.append("## Figures")
    lines.append("")
    for note in fig_notes:
        lines.append(f"- {note}")

    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def latex_escape(value: str) -> str:
    repl = {
        "\\": r"\\textbackslash{}",
        "&": r"\\&",
        "%": r"\\%",
        "$": r"\\$",
        "#": r"\\#",
        "_": r"\\_",
        "{": r"\\{",
        "}": r"\\}",
        "~": r"\\textasciitilde{}",
        "^": r"\\textasciicircum{}",
    }
    out = []
    for ch in value:
        out.append(repl.get(ch, ch))
    return "".join(out)


def chunked(seq: list[str], size: int) -> list[list[str]]:
    return [seq[i : i + size] for i in range(0, len(seq), size)]


def write_latex_mincut_table(lines: list[str], caption: str, label: str, rows: list[list]):
    lines.append(r"\begin{table}[htbp]")
    lines.append(r"\centering")
    lines.append(rf"\caption{{{caption}}}")
    lines.append(rf"\label{{{label}}}")
    lines.append(r"\begin{tabular}{lp{10cm}}")
    lines.append(r"\toprule")
    lines.append(r"Cut & Crossing edges \\")
    lines.append(r"\midrule")

    for i, row in enumerate(rows):
        cut = row[0]
        crossing = str(row[1])
        pairs = re.findall(r"\((\d+)->(\d+)\)", crossing)
        edges = [f"({u}$\\rightarrow${v})" for u, v in pairs]
        edge_chunks = chunked(edges, 4)

        for j, edge_chunk in enumerate(edge_chunks):
            chunk_text = ", ".join(edge_chunk)
            if j < len(edge_chunks) - 1:
                chunk_text += ","

            if j == 0:
                lines.append(f"{cut} & {chunk_text} " + r"\\")
            else:
                lines.append(f"  & {chunk_text} " + r"\\")

        if i < len(rows) - 1:
            lines.append(r"\midrule")

    lines.append(r"\bottomrule")
    lines.append(r"\end{tabular}")
    lines.append(r"\end{table}")
    lines.append("")


def write_latex_tables(path: Path, tables: list[tuple[str, str, list[str], list[list]]]):
    lines: list[str] = []
    lines.append("% Auto-generated LaTeX tables for thesis")
    lines.append("% Requires: \\usepackage{booktabs}")
    lines.append("")

    for caption, label, headers, rows in tables:
        if label == "tab:mincut_enumeration_config_a":
            write_latex_mincut_table(lines, caption, label, rows)
            continue

        colspec = "l" + "c" * (len(headers) - 1)
        lines.append(r"\begin{table}[htbp]")
        lines.append(r"\centering")
        lines.append(rf"\caption{{{caption}}}")
        lines.append(rf"\label{{{label}}}")
        lines.append(rf"\begin{{tabular}}{{{colspec}}}")
        lines.append(r"\toprule")
        lines.append("{} \\\\".format(" & ".join(latex_escape(str(h)) for h in headers)))
        lines.append(r"\midrule")
        for row in rows:
            lines.append("{} \\\\".format(" & ".join(latex_escape(str(x)) for x in row)))
        lines.append(r"\bottomrule")
        lines.append(r"\end{tabular}")
        lines.append(r"\end{table}")
        lines.append("")

    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def plot_degradation(path: Path, a_data: dict, b_data: dict):
    ax_vals_a = [x for x, _ in a_data["degradation"]]
    fl_vals_a = [y for _, y in a_data["degradation"]]
    ax_vals_b = [x for x, _ in b_data["degradation"]]
    fl_vals_b = [y for _, y in b_data["degradation"]]

    fig, ax = plt.subplots(figsize=(8, 4.6), dpi=150)
    ax.plot(ax_vals_a, fl_vals_a, marker="o", linewidth=2.2, label="Config A")
    ax.plot(ax_vals_b, fl_vals_b, marker="s", linewidth=2.0, linestyle="--", label="Config B")
    ax.set_xlabel("degradation factor alpha")
    ax.set_ylabel("max flow F*")
    ax.grid(True, alpha=0.25)
    ax.legend(frameon=False)
    fig.tight_layout()
    fig.savefig(path)
    plt.close(fig)


def plot_sensitivity(path: Path, a_data: dict, b_data: dict):
    non_zero_a = [x for x in a_data["critical_edges"] if x["drop"] > 0]
    non_zero_b = [x for x in b_data["critical_edges"] if x["drop"] > 0]

    fig, axes = plt.subplots(1, 2, figsize=(13.5, 5.6), dpi=150, sharey=True)

    labels_a = [e["edge"] for e in non_zero_a]
    drops_a = [e["drop"] for e in non_zero_a]
    bars_a = axes[0].bar(labels_a, drops_a, color="#4C72B0")
    axes[0].set_xlabel("edge")
    axes[0].set_ylabel("delta F*")
    axes[0].grid(axis="y", alpha=0.25)
    axes[0].bar_label(bars_a, fmt="%.1f", padding=2, fontsize=8)
    plt.setp(axes[0].get_xticklabels(), rotation=45, ha="right")

    labels_b = [e["edge"] for e in non_zero_b]
    drops_b = [e["drop"] for e in non_zero_b]
    bars_b = axes[1].bar(labels_b, drops_b, color="#DD8452")
    axes[1].set_xlabel("edge")
    axes[1].grid(axis="y", alpha=0.25)
    axes[1].bar_label(bars_b, fmt="%.1f", padding=2, fontsize=8)
    plt.setp(axes[1].get_xticklabels(), rotation=45, ha="right")

    fig.tight_layout()
    fig.savefig(path)
    plt.close(fig)


def plot_sink_flow_heatmap(path: Path, a_data: dict, b_data: dict):
    sink_ids = [137, 138, 139, 140, 141, 142, 143]
    col_labels = ["edge-only A", "node-cap A", "edge-only B", "node-cap B"]
    matrix = [
        [
            a_data["sink_flow"].get(sid, 0.0),
            a_data["node_cap_sink_flow"].get(sid, 0.0),
            b_data["sink_flow"].get(sid, 0.0),
            b_data["node_cap_sink_flow"].get(sid, 0.0),
        ]
        for sid in sink_ids
    ]

    fig, ax = plt.subplots(figsize=(7.2, 5.0), dpi=150)
    im = ax.imshow(matrix, cmap="cividis", aspect="auto", vmin=0.0, vmax=6.5)

    ax.set_xticks(range(len(col_labels)))
    ax.set_xticklabels(col_labels, rotation=20, ha="right")
    ax.set_yticks(range(len(sink_ids)))
    ax.set_yticklabels([str(s) for s in sink_ids])
    ax.set_xlabel("scenario")
    ax.set_ylabel("sink")

    for i in range(len(sink_ids)):
        for j in range(len(col_labels)):
            value = matrix[i][j]
            text_color = "white" if value >= 3.5 else "black"
            ax.text(j, i, f"{value:.1f}", ha="center", va="center", color=text_color, fontsize=8)

    cbar = fig.colorbar(im, ax=ax)
    cbar.set_label("flow magnitude")
    fig.tight_layout()
    fig.savefig(path)
    plt.close(fig)


def parse_node_names_from_dot(path: Path) -> dict[int, str]:
    names: dict[int, str] = {}
    pattern = re.compile(r'^\s*(\d+)\s*\[label="([^\\"]+)')
    with path.open("r", encoding="utf-8") as f:
        for raw in f:
            m = pattern.match(raw.rstrip("\n"))
            if m:
                nid = int(m.group(1))
                names[nid] = m.group(2)
    return names


def short_edge_label(edge: str) -> str:
    return edge.replace("(", "").replace(")", "")


def build_sensitivity_overlay_dot(base_dot: Path, out_dot: Path, critical_edges: list[dict]):
    drop_by_edge = {
        tuple(int(x) for x in re.findall(r"\d+", e["edge"])): float(e["drop"]) for e in critical_edges if e["drop"] > 0
    }
    if not drop_by_edge:
        out_dot.write_text(base_dot.read_text(encoding="utf-8"), encoding="utf-8")
        return

    max_drop = max(drop_by_edge.values())
    edge_line_pattern = re.compile(r"^(\s*)(\d+)\s*->\s*(\d+)\s*\[(.*)\];\s*$")

    lines_out: list[str] = []
    with base_dot.open("r", encoding="utf-8") as f:
        for raw in f:
            line = raw.rstrip("\n")
            m = edge_line_pattern.match(line)
            if not m:
                lines_out.append(line)
                continue

            indent, u_str, v_str, attrs = m.groups()
            u = int(u_str)
            v = int(v_str)
            edge = (u, v)

            # Split topological context from critical-edge emphasis.
            if edge in drop_by_edge:
                drop = drop_by_edge[edge]
                norm = drop / max_drop if max_drop > 0 else 0.0
                penwidth = 1.2 + 5.0 * norm
                red = 180 + int(70 * norm)
                green = 70 - int(45 * norm)
                blue = 70 - int(45 * norm)
                color = f"#{red:02X}{max(green, 20):02X}{max(blue, 20):02X}"
                attrs = attrs + f', penwidth={penwidth:.2f}, color="{color}", fontcolor="#8A1F1F", xlabel="Δ={drop:.1f}"'
            else:
                attrs = attrs + ', color="#C9CDD2", fontcolor="#999999"'

            lines_out.append(f"{indent}{u} -> {v} [{attrs}];")

    out_dot.write_text("\n".join(lines_out) + "\n", encoding="utf-8")


def render_dot(dot_path: Path, pdf_path: Path) -> tuple[bool, str]:
    dot_exe = shutil.which("dot")
    if dot_exe is None:
        return False, "Graphviz 'dot' executable not found; wrote DOT source only."

    try:
        subprocess.run([dot_exe, "-Tpdf", str(dot_path), "-o", str(pdf_path)], check=True)
        return True, "Rendered PDF from DOT overlay."
    except subprocess.CalledProcessError as ex:
        return False, f"Failed to render overlay with dot: {ex}"


def plot_sensitivity_two_panel(path: Path, a_data: dict, b_data: dict, overlay_png_path: Path | None):
    non_zero_a = [x for x in a_data["critical_edges"] if x["drop"] > 0]
    non_zero_b = [x for x in b_data["critical_edges"] if x["drop"] > 0]

    by_edge_a = {e["edge"]: e for e in non_zero_a}
    by_edge_b = {e["edge"]: e for e in non_zero_b}
    union_edges = sorted(set(by_edge_a.keys()) | set(by_edge_b.keys()), key=lambda e: max(by_edge_a.get(e, {"drop": 0.0})["drop"], by_edge_b.get(e, {"drop": 0.0})["drop"]), reverse=True)

    labels = [short_edge_label(e) for e in union_edges]
    vals_a = [by_edge_a.get(e, {"drop": 0.0})["drop"] for e in union_edges]
    vals_b = [by_edge_b.get(e, {"drop": 0.0})["drop"] for e in union_edges]
    y = list(range(len(union_edges)))

    fig, axes = plt.subplots(1, 2, figsize=(14.5, 7.5), dpi=160, gridspec_kw={"width_ratios": [1.2, 1.0]})

    if overlay_png_path and overlay_png_path.exists():
        img = plt.imread(str(overlay_png_path))
        axes[0].imshow(img)
        axes[0].axis("off")
    else:
        axes[0].text(
            0.5,
            0.5,
            "Overlay image unavailable\n(install Graphviz 'dot' to render)",
            ha="center",
            va="center",
            fontsize=12,
        )
        axes[0].set_xticks([])
        axes[0].set_yticks([])

    bars = axes[1].barh(y, vals_a, color="#4C72B0", alpha=0.9, label="Config A")
    axes[1].scatter(vals_b, y, marker="D", s=44, color="#DD8452", label="Config B", zorder=3)
    axes[1].set_yticks(y)
    axes[1].set_yticklabels(labels, fontsize=9)
    axes[1].invert_yaxis()
    axes[1].set_xlabel("ΔF*")
    axes[1].grid(axis="x", alpha=0.25)
    axes[1].legend(frameon=False, loc="lower right")
    axes[1].bar_label(bars, fmt="%.1f", padding=2, fontsize=8)

    fig.tight_layout()
    fig.savefig(path)
    plt.close(fig)


def plot_sensitivity_bars_only(path: Path, a_data: dict, b_data: dict):
    non_zero_a = [x for x in a_data["critical_edges"] if x["drop"] > 0]
    non_zero_b = [x for x in b_data["critical_edges"] if x["drop"] > 0]

    by_edge_a = {e["edge"]: e for e in non_zero_a}
    by_edge_b = {e["edge"]: e for e in non_zero_b}
    union_edges = sorted(
        set(by_edge_a.keys()) | set(by_edge_b.keys()),
        key=lambda e: max(by_edge_a.get(e, {"drop": 0.0})["drop"], by_edge_b.get(e, {"drop": 0.0})["drop"]),
        reverse=True,
    )

    labels = [short_edge_label(e) for e in union_edges]
    vals_a = [by_edge_a.get(e, {"drop": 0.0})["drop"] for e in union_edges]
    vals_b = [by_edge_b.get(e, {"drop": 0.0})["drop"] for e in union_edges]
    y = list(range(len(union_edges)))

    fig, ax = plt.subplots(figsize=(7.8, 5.8), dpi=160)
    bars = ax.barh(y, vals_a, color="#4C72B0", alpha=0.9, label="Config A")
    ax.scatter(vals_b, y, marker="D", s=44, color="#DD8452", label="Config B", zorder=3)
    ax.set_yticks(y)
    ax.set_yticklabels(labels, fontsize=9)
    ax.invert_yaxis()
    ax.set_xlabel("ΔF*")
    ax.grid(axis="x", alpha=0.25)
    ax.legend(frameon=False, loc="lower right")
    ax.bar_label(bars, fmt="%.1f", padding=2, fontsize=8)
    fig.tight_layout()
    fig.savefig(path)
    plt.close(fig)


def build_appendix_critical_rows(data: dict) -> list[list[str]]:
    non_zero = [x for x in data["critical_edges"] if x["drop"] > 0]
    return [
        [
            str(i + 1),
            e["label"],
            f"{e['drop']:.1f}",
            f"{e['perturbed_flow']:.1f}",
        ]
        for i, e in enumerate(non_zero)
    ]


def write_appendix_sensitivity_tables(path: Path, rows_a: list[list[str]], rows_b: list[list[str]]):
    lines: list[str] = []
    lines.append("% Auto-generated appendix LaTeX tables for sensitivity")
    lines.append("% Requires: \\usepackage{booktabs}")
    lines.append("")

    lines.append(r"\begin{table}[htbp]")
    lines.append(r"\centering")
    lines.append(r"\caption{Full ranked single-edge sensitivity results for Configuration A (all non-zero $\Delta F^*$ edges).}")
    lines.append(r"\label{tab:critical_edges_config_a_appendix}")
    lines.append(r"\begin{tabular}{lccc}")
    lines.append(r"\toprule")
    lines.append(r"Rank & Label & $\Delta F^*$ & \texttt{perturbed\_flow} \\")
    lines.append(r"\midrule")
    for rank, label, drop, perturbed in rows_a:
        escaped_label = label.replace("_", r"\_")
        lines.append(f"{rank} & \\texttt{{{escaped_label}}} & {drop} & {perturbed} " + r"\\")
    lines.append(r"\bottomrule")
    lines.append(r"\end{tabular}")
    lines.append(r"\end{table}")
    lines.append("")

    lines.append(r"\begin{table}[htbp]")
    lines.append(r"\centering")
    lines.append(r"\caption{Full ranked single-edge sensitivity results for Configuration B (all non-zero $\Delta F^*$ edges).}")
    lines.append(r"\label{tab:critical_edges_config_b_appendix}")
    lines.append(r"\begin{tabular}{lccc}")
    lines.append(r"\toprule")
    lines.append(r"Rank & Label & $\Delta F^*$ & \texttt{perturbed\_flow} \\")
    lines.append(r"\midrule")
    for rank, label, drop, perturbed in rows_b:
        escaped_label = label.replace("_", r"\_")
        lines.append(f"{rank} & \\texttt{{{escaped_label}}} & {drop} & {perturbed} " + r"\\")
    lines.append(r"\bottomrule")
    lines.append(r"\end{tabular}")
    lines.append(r"\end{table}")
    lines.append("")

    path.write_text("\n".join(lines), encoding="utf-8")


def wrap_dot_text(text: str, width: int = 88) -> str:
    words = text.split(" ")
    lines: list[str] = []
    current: list[str] = []
    current_len = 0
    for w in words:
        extra = len(w) + (1 if current else 0)
        if current and current_len + extra > width:
            lines.append(" ".join(current))
            current = [w]
            current_len = len(w)
        else:
            current.append(w)
            current_len += extra
    if current:
        lines.append(" ".join(current))
    return "\\n".join(lines)


def write_dot_figure_spec(
    path: Path,
    graph_name: str,
    title: str,
    plot_type: str,
    x_label: str,
    y_label: str,
    series_lines: list[str],
):
    lines: list[str] = []
    lines.append(f"digraph {graph_name} {{")
    lines.append('  graph [rankdir=TB, fontsize=11, fontname="Times-Roman", margin=0.2];')
    lines.append('  node [shape=box, style="rounded", fontsize=10, fontname="Times-Roman"];')
    lines.append('  edge [fontsize=9, fontname="Times-Roman"];')
    lines.append(f'  title [label="{title}", shape=plaintext, fontsize=13];')
    lines.append(
        f'  meta [label="type: {plot_type}\\nx-axis: {x_label}\\ny-axis: {y_label}", fillcolor="#F4F4F4", style="rounded,filled"];'
    )
    lines.append("  title -> meta [arrowhead=none, color=\"#888888\"];")
    prev = "meta"
    for idx, content in enumerate(series_lines, start=1):
        node_name = f"series_{idx}"
        wrapped = wrap_dot_text(content)
        lines.append(f'  {node_name} [label="{wrapped}"];')
        lines.append(f"  {prev} -> {node_name} [arrowhead=none, color=\"#B0B0B0\"];")
        prev = node_name
    lines.append("}")
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> None:
    repo_root = Path(__file__).resolve().parent
    output_a = repo_root / "check_flagship_output_configA.txt"
    output_b = repo_root / "check_flagship_output_configB.txt"

    out_dir = repo_root / "thesis_artifacts"
    out_dir.mkdir(parents=True, exist_ok=True)

    data_a = parse_output(output_a)
    data_b = parse_output(output_b)

    table1_headers = ["Metric", "Config A", "Config B"]
    table1_rows = [
        ["F*", f"{data_a['baseline_max_flow']:.1f}", f"{data_b['baseline_max_flow']:.1f}"],
        ["saturated_edges", data_a["saturated_edge_count"], data_b["saturated_edge_count"]],
        ["free_zone_size", data_a["free_zone_size"], data_b["free_zone_size"]],
        ["min_cuts", data_a["mincuts_total"], data_b["mincuts_total"]],
        ["SPOF_nodes", data_a["spof_nodes_count"], data_b["spof_nodes_count"]],
        [
            "upgrade_ineffective (gateway edges)",
            str(data_a["upgrade_ineffective_gateway"]).lower(),
            str(data_b["upgrade_ineffective_gateway"]).lower(),
        ],
    ]
    write_csv(out_dir / "table1_config_comparison.csv", table1_headers, table1_rows)

    sink_ids = [137, 138, 139, 140, 141, 142, 143]
    table2_headers = [
        "Sink",
        "edge_only_A",
        "node_cap_A",
        "edge_only_B",
        "node_cap_B",
    ]
    table2_rows = [
        [
            sid,
            f"{data_a['sink_flow'].get(sid, 0.0):.1f}",
            f"{data_a['node_cap_sink_flow'].get(sid, 0.0):.1f}",
            f"{data_b['sink_flow'].get(sid, 0.0):.1f}",
            f"{data_b['node_cap_sink_flow'].get(sid, 0.0):.1f}",
        ]
        for sid in sink_ids
    ]
    write_csv(out_dir / "table2_sink_flow_comparison.csv", table2_headers, table2_rows)

    table3_headers = ["Rank", "Edge", "Label", "delta_F*", "perturbed_flow"]
    non_zero_crit = [x for x in data_a["critical_edges"] if x["drop"] > 0]
    table3_rows = [
        [i + 1, e["edge"], e["label"], f"{e['drop']:.1f}", f"{e['perturbed_flow']:.1f}"]
        for i, e in enumerate(non_zero_crit)
    ]
    write_csv(out_dir / "table3_top_critical_edges_configA.csv", table3_headers, table3_rows)

    table4_headers = ["Cut", "Crossing edges"]
    table4_rows = [[c["cut"], c["crossing"]] for c in data_a["mincuts"]]
    write_csv(out_dir / "table4_mincut_enumeration_configA.csv", table4_headers, table4_rows)

    plot_degradation(out_dir / "degradation_trajectory.pdf", data_a, data_b)
    plot_sensitivity(out_dir / "sensitivity_ranking_ab.pdf", data_a, data_b)
    plot_sink_flow_heatmap(out_dir / "sink_flow_heatmap.pdf", data_a, data_b)

    overlay_dot = out_dir / "critical_overlay_config_a.dot"
    overlay_pdf = out_dir / "critical_overlay_config_a.pdf"
    build_sensitivity_overlay_dot(repo_root / "flagship_network_a.dot", overlay_dot, data_a["critical_edges"])
    rendered, render_note = render_dot(overlay_dot, overlay_pdf)
    plot_sensitivity_bars_only(out_dir / "critical_bars_config_ab.pdf", data_a, data_b)

    bars_a = ", ".join([f"{e['edge']}={e['drop']:.1f}" for e in data_a["critical_edges"] if e["drop"] > 0])
    bars_b = ", ".join([f"{e['edge']}={e['drop']:.1f}" for e in data_b["critical_edges"] if e["drop"] > 0])
    write_dot_figure_spec(
        out_dir / "critical_bars_config_ab.dot",
        "FigureCriticalBarsAB",
        "Critical bars: Config A vs Config B",
        "horizontal bar chart",
        "delta F*",
        "ranked edge",
        [f"Config A bars: {bars_a}", f"Config B markers: {bars_b}"],
    )

    deg_a = ", ".join([f"({alpha:.1f}, {flow:.1f})" for alpha, flow in data_a["degradation"]])
    deg_b = ", ".join([f"({alpha:.1f}, {flow:.1f})" for alpha, flow in data_b["degradation"]])
    write_dot_figure_spec(
        out_dir / "degradation_trajectory.dot",
        "Figure2DegradationTrajectory",
        "Figure 2: Degradation trajectory",
        "line chart",
        "degradation factor alpha",
        "max flow F*",
        [f"Config A points: {deg_a}", f"Config B points: {deg_b}"],
    )

    sens_a = ", ".join([f"{e['edge']}={e['drop']:.1f}" for e in data_a["critical_edges"] if e["drop"] > 0])
    sens_b = ", ".join([f"{e['edge']}={e['drop']:.1f}" for e in data_b["critical_edges"] if e["drop"] > 0])
    write_dot_figure_spec(
        out_dir / "sensitivity_ranking_ab.dot",
        "Figure3SensitivityRanking",
        "Figure 3: Sensitivity ranking (A vs B)",
        "two-panel bar chart",
        "edge",
        "delta F*",
        [f"Config A non-zero deltas: {sens_a}", f"Config B non-zero deltas: {sens_b}"],
    )

    sink_ids = [137, 138, 139, 140, 141, 142, 143]
    heat_lines: list[str] = []
    for sid in sink_ids:
        heat_lines.append(
            "sink {}: edge-only A={:.1f}, node-cap A={:.1f}, edge-only B={:.1f}, node-cap B={:.1f}".format(
                sid,
                data_a["sink_flow"].get(sid, 0.0),
                data_a["node_cap_sink_flow"].get(sid, 0.0),
                data_b["sink_flow"].get(sid, 0.0),
                data_b["node_cap_sink_flow"].get(sid, 0.0),
            )
        )
    write_dot_figure_spec(
        out_dir / "sink_flow_heatmap.dot",
        "Figure4SinkFlowHeatmap",
        "Figure 4: Sink flow comparison heatmap",
        "heatmap",
        "scenario columns",
        "sink rows",
        heat_lines,
    )

    markdown_tables = [
        ("Table 1. Configuration comparison summary", table1_headers, table1_rows),
        ("Table 3. Top critical edges (Config A)", table3_headers, table3_rows),
        ("Table 4. Min-cut enumeration (Config A)", table4_headers, table4_rows),
    ]
    figure_notes = [
        "Figure 1: Use flagship_network_a.pdf and flagship_network_b.pdf with caption note: Config A/B include direct edge (132->140).",
        "Figure 2: degradation_trajectory.pdf with source degradation_trajectory.dot.",
        "Figure 3: sensitivity_ranking_ab.pdf with source sensitivity_ranking_ab.dot.",
        f"Figure 3b: critical_overlay_config_a.pdf and critical_bars_config_ab.pdf for subfigure workflow. {render_note}",
        "Figure 4: sink_flow_heatmap.pdf with source sink_flow_heatmap.dot.",
    ]
    write_markdown(out_dir / "thesis_tables_and_figures.md", markdown_tables, figure_notes)

    latex_tables = [
        (
            "Configuration comparison summary.",
            "tab:config_comparison",
            table1_headers,
            table1_rows,
        ),
        (
            "Top critical edges for Config A (non-zero deltas).",
            "tab:critical_edges_config_a",
            table3_headers,
            table3_rows,
        ),
        (
            "Min-cut enumeration for Config A.",
            "tab:mincut_enumeration_config_a",
            table4_headers,
            table4_rows,
        ),
    ]
    write_latex_tables(out_dir / "thesis_tables_latex.txt", latex_tables)

    write_appendix_sensitivity_tables(
        out_dir / "appendix_sensitivity_tables_latex.txt",
        build_appendix_critical_rows(data_a),
        build_appendix_critical_rows(data_b),
    )

    print(f"Wrote artifacts to: {out_dir}")


if __name__ == "__main__":
    main()
