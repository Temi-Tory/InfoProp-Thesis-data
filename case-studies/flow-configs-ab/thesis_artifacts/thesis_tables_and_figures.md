## Table 1. Configuration comparison summary

| Metric | Config A | Config B |
| --- | --- | --- |
| F* | 37.0 | 37.0 |
| saturated_edges | 41 | 35 |
| free_zone_size | 2 | 0 |
| min_cuts | 4 | 1 |
| SPOF_nodes | 0 | 0 |
| upgrade_ineffective (gateway edges) | true | false |

## Table 3. Top critical edges (Config A)

| Rank | Edge | Label | delta_F* | perturbed_flow |
| --- | --- | --- | --- | --- |
| 1 | (134->136) | dispatch_gateway_west->distribution_combiner | 17.0 | 20.0 |
| 2 | (135->136) | dispatch_gateway_east->distribution_combiner | 17.0 | 20.0 |
| 3 | (128->134) | secondary_a->dispatch_gateway_west | 4.0 | 33.0 |
| 4 | (130->135) | secondary_c->dispatch_gateway_east | 4.0 | 33.0 |
| 5 | (131->134) | secondary_d->dispatch_gateway_west | 4.0 | 33.0 |
| 6 | (133->135) | secondary_f->dispatch_gateway_east | 4.0 | 33.0 |
| 7 | (129->134) | secondary_b->dispatch_gateway_west | 3.0 | 34.0 |
| 8 | (129->135) | secondary_b->dispatch_gateway_east | 3.0 | 34.0 |
| 9 | (132->134) | secondary_e->dispatch_gateway_west | 3.0 | 34.0 |
| 10 | (132->135) | secondary_e->dispatch_gateway_east | 3.0 | 34.0 |
| 11 | (132->140) | secondary_e->sink_4 | 3.0 | 34.0 |
| 12 | (130->134) | secondary_c->dispatch_gateway_west | 2.0 | 35.0 |
| 13 | (131->135) | secondary_d->dispatch_gateway_east | 2.0 | 35.0 |
| 14 | (128->135) | secondary_a->dispatch_gateway_east | 1.0 | 36.0 |
| 15 | (133->134) | secondary_f->dispatch_gateway_west | 1.0 | 36.0 |

## Table 4. Min-cut enumeration (Config A)

| Cut | Crossing edges |
| --- | --- |
| 1 | (128->134), (128->135), (129->134), (129->135), (130->134), (130->135), (131->134), (131->135), (132->134), (132->135), (132->140), (133->134), (133->135) |
| 2 | (128->135), (129->135), (130->135), (131->135), (132->135), (132->140), (133->135), (134->136) |
| 3 | (128->134), (129->134), (130->134), (131->134), (132->134), (132->140), (133->134), (135->136) |
| 4 | (132->140), (134->136), (135->136) |

## Figures

- Figure 1: Use flagship_network_a.pdf and flagship_network_b.pdf with caption note: Config A/B include direct edge (132->140).
- Figure 2: degradation_trajectory.pdf with source degradation_trajectory.dot.
- Figure 3: sensitivity_ranking_ab.pdf with source sensitivity_ranking_ab.dot.
- Figure 3b: critical_overlay_config_a.pdf and critical_bars_config_ab.pdf for subfigure workflow. Rendered PDF from DOT overlay.
- Figure 4: sink_flow_heatmap.pdf with source sink_flow_heatmap.dot.
