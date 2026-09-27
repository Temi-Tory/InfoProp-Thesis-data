# Additions of 2026-09-21 (parity pass)

- `structured_fresh.csv` — raw output of make_structured.jl (2026-08-16), the source of the power-network and KarlNetwork rows of tab:structured. Its counterexample row still shows the older 340-node diagram; the canonical figure is 323 (see `counterexample_n15_canonical_timing.csv`).
- `paper_data.csv` — counterexample-n15 `sift_nodes` corrected 340 -> 323 to match the manuscript.
- `robdd_named_networks_20260921.csv` — sifted CUDD diagram sizes and IPA-vs-ROBDD agreement for the gas, transit and Net3 networks (uniform 0.9 inputs).
- `grid_ipa_vs_cudd_cost_20260921.csv` — IPA vs CUDD cost on the benchmark grid (min time, Julia-side memory and allocations).
- Scripts (`scripts_20260921/` or `probability_20260921/`): `grid_bench3.jl`, `net_bdd.jl`, `worked16.jl` (section 4 worked example), `drone_C.jl` (drone conditioning sizes: centralised 8, dense 16, minimal 16). Path constants point at the authors' local scratch layout and need adjusting to rerun.
- `bnlearn_vs_sifted_bdd_20260921.csv` — IPA (Float64 and interval) against sifted CUDD on 18 bnlearn-family networks incl. munin-dag/munin-sub1/water; script `bnl_oracle.jl`.
