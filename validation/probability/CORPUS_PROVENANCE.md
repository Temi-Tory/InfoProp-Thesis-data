# Corpus provenance table — Probability Propagation Toolkit (Chapter 5)

Per-network provenance for the probability-propagation corpus. The "Confirmed here?" column
marks what is independently documented elsewhere versus what rests on the author's own stated
provenance (not independently re-derivable from anything in this repository, but not
contradicted by anything in it either).

| Network | V/E | What it models | What was assigned | Source | Confirmed here? |
|---|---|---|---|---|---|
| `power-network` | 23/27 | Four-substation power distribution network | Reliability from Tong & Tien's own case; capacities/schedule are this thesis's own assigned demonstration values | Tong & Tien (2019), ASCE-ASME J. Risk Uncertainty Eng. Syst. A, Fig. 11 | Confirmed directly against the paper PDF (Fig. 11, "solid black circles are three source nodes, sink node is Node 23") |
| `KarlNetwork` | 26/74 | Synthetic 18-diamond stress-test network | Reliability values are demonstration-assigned | Colleague-generated | Author-stated; treated as synthetic/non-real-infrastructure throughout the corpus |
| `metro_directed_dag_for_ipm` | 306/351 | Berlin metro network | Structure only; reliabilities assigned | Berlin transit network, derived by breadth-first search from node 18 | Author-stated |
| `munin-dag`, `munin-sub1` | 1398E / 273E | Medical diagnostic Bayesian network (Munin, EMG diagnosis) | Structure from bnlearn; synthetic Float64 reliabilities assigned (not a decision-relevant claim) | bnlearn.com/bnrepository | Confirmed — converted via the project's bnlearn BIF-topology parser |
| `water` | 32/67 | Water distribution network | Structure from bnlearn; synthetic reliabilities assigned | bnlearn.com/bnrepository | Confirmed; node/arc count matches bnlearn's own `water` network, likely the same source converted twice via different pipelines |
| `Net3` | — | EPANET water distribution benchmark (`Net3.inp`) | Edges oriented by dominant DC/steady-state flow direction (see `case-studies/net3/RESULTS.md`) | EPANET (US EPA water distribution simulator), standard example network | Confirmed |
| Drone designs (`drone-network-concentrated-minimal`, `drone-network-fw-reliant-centralized`, `drone-network-vtol-dense-decentralized`, + K-variants) | 217-289V, 263-6166E | Medical drone logistics network, Scotland | Structure from the cited study; reliabilities are this thesis's own demonstration values | Jones et al., Scotland medical drone logistics paper | Author-stated; treated as real-infrastructure-grounded for all 3 official designs |
| `mlgw-gas-network` | — | Memphis Light, Gas and Water (MLGW) gas network, Shelby County | Structure real; reliabilities assigned | University of Illinois IDEALS repository, item 5302 (MAE study) | Confirmed — provenance: Univ. Illinois IDEALS 5302, MLGW Shelby County gas network |
| bnlearn corpus (17 networks: asia, alarm, andes, barley, cancer, child, diabetes, earthquake, hailfinder, hepar2, insurance, link, mildew, pathfinder, pigs, sachs, survey, win95pts) | 8/8 to 724/1125 | Cited Bayesian-network repository benchmarks (medical diagnosis, agriculture, etc. — not physical infrastructure) | Structure only; synthetic Float64 reliabilities, explicitly not decision-relevant | bnlearn.com/bnrepository | Confirmed |
| `counterexample-n15` | 15/23 | Hand-constructed adversarial diamond structure (not real infrastructure) | Synthetic by design | This project's own validation corpus | N/A — synthetic, not real infrastructure |
| `random_nX_pY_sZ` family (120 graphs), `mutant_rand28_sN` (8 graphs) | 10-28V | Synthetic random/mutated DAGs, the bulk of the 129-graph exactness corpus | Fully synthetic (`graph_gen.jl`, seeded `MersenneTwister`) | This project's own validation harness | N/A — synthetic by design, not real infrastructure |

## What this table is for

Distinguishes the **real-infrastructure-grounded** networks (power, Karl, metro, munin, water,
Net3, the drone designs, mlgw) — where the topology is real even though reliability/capacity/
schedule values are frequently assigned for demonstration — from the **purely synthetic**
networks (bnlearn structural benchmarks, the 129-graph exactness corpus) used to validate
correctness and scaling rather than to claim anything about a physical system.
