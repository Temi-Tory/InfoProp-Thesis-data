import argparse
import json
import os
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent

# Layer colours
LAYER_COLORS = {
    1: ("#4C72B0", "black"),
    2: ("#55A868", "black"),
    3: ("#C44E52", "black"),
    4: ("#8172B2", "black"),
    5: ("#937860", "black"),
    6: ("#C44E52", "black"),
    7: ("#DA8BC3", "black"),
    8: ("#B0B0B0", "black"),
}

BYPASS_NODES = {118, 119}
BOOSTED_FEEDERS = {
    (128, 134): 5.0,
    (128, 135): 2.0,
    (129, 134): 4.0,
    (129, 135): 4.0,
    (130, 134): 3.0,
    (130, 135): 5.0,
    (131, 134): 5.0,
    (131, 135): 3.0,
    (132, 134): 4.0,
    (132, 135): 4.0,
    (133, 134): 2.0,
    (133, 135): 5.0,
}


def load_inputs() -> tuple[dict, dict, dict]:
    edge_data = json.loads((SCRIPT_DIR / "edge_capacities_flagship.json").read_text(encoding="utf-8"))
    node_data = json.loads((SCRIPT_DIR / "node_capacities_flagship.json").read_text(encoding="utf-8"))
    meta_data = json.loads((SCRIPT_DIR / "flagship_node_metadata.json").read_text(encoding="utf-8"))
    return edge_data, node_data, meta_data


def cap_label(value: float) -> str:
    return str(int(value)) if float(value).is_integer() else f"{value:.2f}"


def build_config_edges(base_edges: dict[tuple[int, int], float], mode: str) -> dict[tuple[int, int], float]:
    edges = dict(base_edges)

    if mode in {"A", "B"}:
        edges[(132, 140)] = 3.0

    if mode == "B":
        for e, c in BOOSTED_FEEDERS.items():
            edges[e] = c

    return edges


def make_dot(mode: str, edge_caps: dict[tuple[int, int], float], node_caps: dict[int, float], node_labels: dict[int, str], layers: dict[int, list[int]]) -> str:
    lines: list[str] = []
    lines.append("digraph FlagshipBenchmark {")
    lines.append('  graph [rankdir=TB, splines=polyline, fontsize=11,')
    lines.append('         fontname="Times-Roman", nodesep=0.3, ranksep=0.6, margin=0];')
    lines.append('  node [shape=box, style="rounded,filled", fontsize=9,')
    lines.append('        fontname="Times-Roman", width=1.4, height=0.4, fixedsize=true];')
    lines.append('  edge [fontsize=7, fontname="Times-Roman", arrowsize=0.6, color="#444444"];')
    lines.append("")

    for layer, nodes in sorted(layers.items()):
        fill, font = LAYER_COLORS[layer]
        lines.append(f"  // Layer {layer}")
        lines.append("  { rank=same;")
        for n in nodes:
            label_name = node_labels.get(n, str(n))
            cap_str = f"\\n[b={node_caps[n]}]" if n in node_caps else ""
            fill_color = "#DD8452" if n in BYPASS_NODES else fill
            lines.append(
                f'    {n} [label="{label_name}\\n({n}){cap_str}", fillcolor="{fill_color}", fontcolor="{font}"];'
            )
        lines.append("  }")
        lines.append("")

    lines.append("  // Edges")
    for (u, v) in sorted(edge_caps.keys()):
        c = edge_caps[(u, v)]
        attrs = [f'label="{cap_label(c)}"']

        if (u, v) in {(134, 136), (135, 136)}:
            attrs.append('penwidth=2.5')
            attrs.append('color="#C44E52"')
        elif (u, v) == (132, 140):
            attrs.append('penwidth=2.2')
            attrs.append('color="#4C72B0"')
        elif mode == "B" and (u, v) in BOOSTED_FEEDERS:
            attrs.append('penwidth=2.0')
            attrs.append('color="#DD8452"')

        lines.append(f"  {u} -> {v} [{', '.join(attrs)}];")

    lines.append("}")
    return "\n".join(lines)


def write_mode(mode: str, base_edges: dict[tuple[int, int], float], node_caps: dict[int, float], node_labels: dict[int, str], layers: dict[int, list[int]]) -> Path:
    edge_caps = build_config_edges(base_edges, mode)
    dot = make_dot(mode, edge_caps, node_caps, node_labels, layers)
    out_path = SCRIPT_DIR / f"flagship_network_{mode.lower()}.dot"
    out_path.write_text(dot, encoding="utf-8")
    return out_path


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate flagship DOT diagrams for Base/A/B configurations.")
    parser.add_argument("--mode", choices=["BASE", "A", "B", "ALL"], default=os.getenv("FLAGSHIP_CONFIG", "ALL").upper())
    args = parser.parse_args()

    edge_data, node_data, meta_data = load_inputs()
    base_edges = {(int(e["source"]), int(e["destination"])): float(e["capacity"]) for e in edge_data["edges"]}
    node_caps = {int(n["node"]): float(n["capacity"]) for n in node_data["nodes"]}
    node_labels = {int(k): str(v) for k, v in meta_data["node_labels"].items()}
    layers = {int(k): list(v) for k, v in meta_data["layers"].items()}

    modes = [args.mode] if args.mode != "ALL" else ["BASE", "A", "B"]
    written = []
    for mode in modes:
        out = write_mode(mode, base_edges, node_caps, node_labels, layers)
        written.append(out.name)

        # Keep backward-compatible single-file output for the selected mode.
        if args.mode != "ALL":
            (SCRIPT_DIR / "flagship_network_generated.dot").write_text(out.read_text(encoding="utf-8"), encoding="utf-8")

    print("Generated:", ", ".join(written))


if __name__ == "__main__":
    main()
