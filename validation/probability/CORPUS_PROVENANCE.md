# Corpus provenance table — Probability Propagation Toolkit (Chapter 5)

Section 3 item 6 of the data-pack requirements. Assembled from
`notes/CORPUS_INVENTORY.md`, `notes/CORPUS_CAMPAIGN_HANDBACK.md`, and your own stated
provenance facts. Column "source confirmed here" marks what I independently found in the
dump's own notes vs. what rests on your original statement (not independently re-derivable
from anything in the repo, but not contradicted by anything in it either).

| Network | V/E | What it models | What was assigned | Source | Confirmed here? |
|---|---|---|---|---|---|
| `power-network` | 23/27 | Four-substation power distribution network | Reliability from Tong & Tien's own case; capacities/schedule are this thesis's own assigned demonstration values | Tong & Tien (2019), ASCE-ASME J. Risk Uncertainty Eng. Syst. A, Fig. 11 | Confirmed directly against the paper PDF this session (Fig. 11, "solid black circles are three source nodes, sink node is Node 23") |
| `KarlNetwork` | 26/74 | Synthetic 18-diamond stress-test network | Reliability values are demonstration-assigned | Colleague-generated | Per your statement; `CORPUS_INVENTORY.md` corroborates it's treated as synthetic/non-real-infrastructure throughout |
| `metro_directed_dag_for_ipm` | 306/351 | Berlin metro network | Structure only; reliabilities assigned | Berlin transit network, derived by breadth-first search from node 18 | Per your statement — not independently found in the dump's own notes (checked `CORPUS_INVENTORY.md`/`CORPUS_CAMPAIGN_HANDBACK.md` directly for "Berlin"/"BFS"/"node 18", no match); `CORPUS_INVENTORY.md` does confirm it ran "end-to-end... through `new_identify`" |
| `munin-dag`, `munin-sub1` | 1398E / 273E | Medical diagnostic Bayesian network (Munin, EMG diagnosis) | Structure from bnlearn; synthetic Float64 reliabilities assigned (explicitly *not* a decision-relevant claim, per `PAPER_GUIDE.md`) | bnlearn.com/bnrepository | Confirmed — `CORPUS_INVENTORY.md` §5 documents the bnlearn conversion pipeline (BIF-topology parser) directly |
| `water` | 32/67 | Water distribution network | Structure from bnlearn; synthetic reliabilities assigned | bnlearn.com/bnrepository — `CORPUS_INVENTORY.md` notes this network's node/arc count matches bnlearn's own `water` network, "likely the same source, converted twice via different pipelines" | Confirmed, with the caveat above already flagged in the dump itself |
| `Net3` | — | EPANET water distribution benchmark (`Net3.inp`) | Edges oriented by dominant DC/steady-state flow direction (see your own separate Net3 case-study note) | EPANET (US EPA water distribution simulator), standard example network | Confirmed — `CORPUS_INVENTORY.md` logs it as "added this session (2026-08-17)"; `CORPUS_CAMPAIGN_HANDBACK.md` notes a "Net3 water feasibility check" as pending/user-approved |
| Drone designs (`drone-network-concentrated-minimal`, `drone-network-fw-reliant-centralized`, `drone-network-vtol-dense-decentralized`, + K-variants) | 217-289V, 263-6166E | Medical drone logistics network, Scotland | Structure from the cited study; reliabilities are this thesis's own demonstration values | Jones et al., Scotland medical drone logistics paper | Per your statement; `CORPUS_INVENTORY.md` calls these "real-infrastructure-grounded (Jones et al. Scotland medical drone paper)" for all 3 official designs |
| `mlgw-gas-network` | — | Memphis Light, Gas and Water (MLGW) gas network, Shelby County | Structure real; reliabilities assigned | University of Illinois IDEALS repository, item 5302 (MAE study) | Confirmed directly — `CORPUS_CAMPAIGN_HANDBACK.md`: "provenance: Univ. Illinois IDEALS 5302, MLGW Shelby County gas network — user-supplied" |
| bnlearn corpus (17 networks: asia, alarm, andes, barley, cancer, child, diabetes, earthquake, hailfinder, hepar2, insurance, link, mildew, pathfinder, pigs, sachs, survey, win95pts) | 8/8 to 724/1125 | Cited Bayesian-network repository benchmarks (medical diagnosis, agriculture, etc. — not physical infrastructure) | Structure only; synthetic Float64 reliabilities, explicitly not decision-relevant | bnlearn.com/bnrepository | Confirmed — `CORPUS_INVENTORY.md` §5 |
| `counterexample-n15` | 15/23 | Hand-constructed adversarial diamond structure (not real infrastructure) | Synthetic by design | This project's own validation corpus | N/A — synthetic, not real infrastructure |
| `random_nX_pY_sZ` family (120 graphs), `mutant_rand28_sN` (8 graphs) | 10-28V | Synthetic random/mutated DAGs, the bulk of the 129-graph exactness corpus | Fully synthetic (`graph_gen.jl`, seeded `MersenneTwister`) | This project's own validation harness | N/A — synthetic by design, not real infrastructure |

## What this table is for

Distinguishes the **real-infrastructure-grounded** networks (power, Karl, metro, munin, water,
Net3, the drone designs, mlgw) — where the topology is real even though reliability/capacity/
schedule values are frequently assigned for demonstration — from the **purely synthetic**
networks (bnlearn structural benchmarks, the 129-graph exactness corpus) used to validate
correctness and scaling rather than to claim anything about a physical system.
