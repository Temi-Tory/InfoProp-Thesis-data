# thesis-data

Validation and case-study data for the PhD thesis *Information Propagation Methods for
Reliability, Reachability and Flow Analysis in Directed Acyclic Process Networks*
(T. Ohiani, University of Strathclyde, 2026), and for the companion RESS paper.

Results in this repository were produced with
[`InformationPropagationAnalysis.jl`](https://github.com/Temi-Tory/InformationPropagationAnalysis.jl)
**v0.2.1** (registered in the Julia General registry) and the
[`information-propagation-no-code`](https://github.com/Temi-Tory/information-propagation-no-code)
application v1.0 (DOI [10.5281/zenodo.22180253](https://doi.org/10.5281/zenodo.22180253)).
This repository is archived at **DOI [10.5281/zenodo.22180227](https://doi.org/10.5281/zenodo.22180227)**
at the version cited in the thesis (tag `v1.0`); later commits may extend it.

---

## Layout

```
corpus/            networks used for validation (not headline case studies)
  named-networks/    power-network, grid-graph, KarlNetwork, counterexample-n15, metro
  bnlearn/           munin, water, the 17 bnlearn structural benchmarks (structure only)
  random-and-mutated/ the 129-graph exactness corpus: generator + seeds + provenance
  adversarial/       fan-in-k and mesh-w scaling families
case-studies/      the networks analysed end to end in the thesis
  psplib-j301_1/     PSPLIB project-scheduling benchmark (Critical Path chapter)
  flow-configs-ab/   the 43-node flagship flow benchmark, Configurations A and B
  rts24/             IEEE RTS-24, oriented by DC power flow (Flow chapter case study)
  drone-networks/    the three Scotland medical-drone designs (Probability chapter)
  net3/              EPANET Example Network 3, the integrated case study (Chapter 10)
validation/        oracle scripts, validation summaries, cost/timing tables
  probability/  flow/  critical-path/
figures/           source data + plot scripts for the data-driven figures, by chapter
converters/        the format converters (PSPLIB .sm, EPANET .inp, power scenarios, ...)
_compat/           InfoPropFramework.jl shim (see "Running the scripts" below)
```

**Data, not renders.** Networks are kept as `.EDGES` + input JSON + provenance logs.
The `.dot` / `.png` / `.pdf` diagrams and diamond renders in the thesis are regenerated
from the data, not stored here. Rendered figure PDFs likewise; the CSV/JSON they plot and
the plot script are what this repo carries.

**Large response JSON** (`net3` reliability responses) is gzipped; `gunzip` to use.

---

## Running the scripts

The scripts were written against the working monorepo, where the algorithm code was
loaded as `include(".../Algorithms/InfoPropFramework.jl"); using .InfoPropFramework`.
That code is now the registered package `InformationPropagationAnalysis` v0.2.1. The
`_compat/InfoPropFramework.jl` shim keeps the old flat name backed by the registered
package, so the only change each script needs is its include path:

```julia
include(joinpath(@__DIR__, "..", "..", "_compat", "InfoPropFramework.jl"))
using .InfoPropFramework
```

```
julia --project=_compat -e 'using Pkg; Pkg.instantiate()'
```

`ProbabilityBoundsAnalysis` does not precompile on Julia 1.12 (upstream); scripts load it
interpreted (~40 s) and run normally. The `tab:pp-structured` exactness checks additionally
need the pure-Julia BDD oracle environment in `validation/_bddenv/` (not CUDD).

**Verification status (v1.0):** the data, numbers and recorded server responses are
final. A full re-run of every script below against pinned v0.2.1 is deferred to a
post-viva `v1.1` tag (see `REPRODUCE.md`).

---

## Chapter / figure / table -> script and data

### Appendix A — network specifications

| Network | V/E | Location |
|---|---|---|
| power-network | 23/27 | `corpus/named-networks/power-network/`, scenarios in `power-network-scenarios/` |
| grid-graph | 16/24 | `corpus/named-networks/grid-graph/` |
| KarlNetwork | 26/74 | `corpus/named-networks/KarlNetwork/` |
| counterexample-n15 | 15/23 | `corpus/named-networks/counterexample-n15/` |
| metro_directed_dag | 306/350 | `corpus/named-networks/metro_directed_dag_for_ipm/` |
| PSPLIB j301_1 | 32/48 | `case-studies/psplib-j301_1/` (durations table: `validation/critical-path/thesis_writing_pack/appendix_a_durations_successors.csv`; source `.sm`: cite Kolisch & Sprecher 1997, converter `converters/psplib_to_ipf.py`) |
| IEEE RTS-24 | 24/34 | `case-studies/rts24/` (orientation log + `orient_rts24.py`) |
| drone designs | 217/263, 242/1753, 230/1648 | `case-studies/drone-networks/` (generators: `converters/drone_network_to_dag*.jl`) |
| munin, water, 17 bnlearn | — | `corpus/bnlearn/` (structure only; cite bnlearn repository) |
| Net3 | 97/119 | `case-studies/net3/` (`Net3.inp` + sha in `RESULTS.md`; `converters/net3_to_ipf.py`; orientation log; node mapping) |
| 129-graph + adversarial | summary stats | `corpus/random-and-mutated/` (`graph_gen.jl` + `rerun_129_corpus.jl`), `corpus/adversarial/` |

### Chapter 5 — Probability Propagation

| Figure / table | Data | Script |
|---|---|---|
| Fig 5.4 width vs diagram size | `figures/ch05_probability/complexity_validation.csv`, `paper_data.csv` | `validation/probability/_scripts/complexity_validate.jl`; `corpus/random-and-mutated/rerun_129_corpus.jl` |
| Fig 5.5 p-box tightness envelope | `figures/ch05_probability/grid_envelope{,_frechet}.csv` | `validation/probability/_scripts/grid_envelope{,_frechet}.jl` |
| Fig 5.7 fan-in / mesh crossover | `figures/ch05_probability/adversarial_factored.csv` | `validation/probability/_scripts/adversarial_scaling.jl` |
| Fig 5.8 hero CDF | `figures/ch05_probability/hero_figure.csv` | `validation/probability/_scripts/hero_figure.jl` |
| Fig 5.6 drone reliability map | belief bounds (see Tab pp-drone) | `validation/probability/_scripts/drone_beliefs_check.jl` |
| Tab pp-trace (worked network) | — | `validation/probability/_scripts/prob_chapter_example_trace.jl` |
| Tab pp-structured (4 nets vs BDD) | `validation/probability/` structured run | `validation/probability/_scripts/bdd_oracle.jl` + `oracles.jl` |
| Tab pp-power-repro (Tong & Tien) | — | `validation/probability/asce_power_reproduction.jl` |
| Tab pp-adversarial | `validation/probability/data/adversarial*.csv` | `validation/probability/_scripts/adversarial_scaling.jl`, `graph_families.jl` |
| Tab pp-certified (bound vs MC) | `validation/probability/data/certified_bound_vignette.csv` | `validation/probability/_scripts/certified_bound_vignette.jl` |
| Tab pp-pbox-cost (time vs discretisation) | `validation/probability/data/timing_imprecise.csv` | `validation/probability/` p-box timing scripts |
| Tab pp-drone (3 designs) | `validation/probability/drone_ksweep_remeasure_results.csv` | `validation/probability/drone_ksweep_remeasure.jl` |

Provenance for every corpus network: `validation/probability/CORPUS_PROVENANCE.md`.
Campaign findings: `validation/probability/MASTER_FINDINGS.md`, `INDEX.md`.

### Chapter 6 — Capacity Flow

| Figure / table | Data | Script |
|---|---|---|
| Tab config-comparison, node-upgrade-sweep, critical-edges A/B, parametric, mincut-A | `case-studies/flow-configs-ab/` server responses | `case-studies/flow-configs-ab/check_flagship_benchmark.jl` |
| Figs critical-overlay-A, critical-bars-AB, sensitivity-ranking-AB, degradation-trajectory, sink-flow-heatmap | same | `case-studies/flow-configs-ab/generate_case_study_artifacts.py` (renders; data as above) |
| IEEE RTS-24 net-injection table | `case-studies/rts24/rts24_netinjection_server_response.json` | `case-studies/rts24/run_rts24_netinjection_analysis.jl` |
| Appendix B — 12-network flow validation | `validation/flow/flow_validation_summary.csv` | `validation/flow/run_flow_validation.jl` |
| Appendix B — DIMACS-scale timing | `validation/flow/dimacs/timings.csv` | `validation/flow/dimacs/run_dimacs_validation.jl` (+ `generate_genrmf_dag.py`) |

### Chapter 7 — Critical Path

| Figure / table | Data | Script |
|---|---|---|
| Fig 7.4 exact float bounds | `validation/critical-path/thesis_writing_pack/psplib_j301_1_float_bounds.csv` | `figures/ch07_cpm/make_fig04_floats.py` (reads `case-studies/psplib-j301_1/_analysis-results/time-longest-path-interval-result.json`) |
| Tab cpm-psplib-longest, cpm-psplib-allowance | `case-studies/psplib-j301_1/_analysis-results/*.json` | server runs per `case-studies/psplib-j301_1/RESULTS.md` |
| Appendix B — 10-network CPM validation | `validation/critical-path/float_validation_summary.csv` | `validation/critical-path/run_float_validation.jl` + `oracle.jl` |
| Appendix B — j301_1 per-node float bounds | `validation/critical-path/thesis_writing_pack/psplib_j301_1_float_bounds.csv` | `validation/critical-path/run_mc_check_psplib_j301_1.jl` |

Full CPM pack index: `validation/critical-path/thesis_writing_pack/INDEX.md`.

### Chapter 9 — interface

All figures are screenshots of the deployed application; not reproducible artefacts.

### Chapter 10 — integrated case study (Net3)

Figures fig01–fig14 are application screenshots. Underlying data and every request/response:

| Item | Location |
|---|---|
| Inputs, all scenarios | `case-studies/net3/net3-scenarios/{Baseline,Degraded,Interval,MaxScaling}/` |
| Every request + response JSON | `case-studies/net3/net3-scenarios/responses/` (reliability responses gzipped) |
| Run summary | `case-studies/net3/net3-scenarios/net3_scenarios_summary.csv` |
| Headline numbers, provenance, orientation, corrections | `case-studies/net3/RESULTS.md` |
| Reliability edge classification | `case-studies/net3/net3-scenarios/reliability_input_classification.csv` |
| Driver | `case-studies/net3/net3-scenarios/run_net3_scenarios.py` |
| Superseded BFS-oriented conversion | `case-studies/net3/superseded-bfs-conversion/` (see `RESULTS.md` §1) |

The interval-schedule result is the **conservative enclosure**, not a domination split
(`RESULTS.md` §4 — the split is screened out at Net3's input count).

Net3 pack index: `case-studies/net3/thesis_writing_pack/INDEX.md`.

---

## Provenance and licence

Every case-study network here is public or synthetic; none contains proprietary system
data (`validation/probability/CORPUS_PROVENANCE.md`). Third-party network *structures*
(bnlearn, EPANET Net3, PSPLIB, IEEE RTS-24, MATPOWER) are cited in the thesis and remain
under their original terms; the derived `.EDGES`/JSON, the converters, and the validation
scripts in this repository are released under the MIT licence (`LICENSE`).
