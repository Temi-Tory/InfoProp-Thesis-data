# The 129-graph exactness corpus

Not stored as files: the 120 `random_nX_pY_sZ` graphs are reconstructed byte-for-byte
from their names via `graph_gen.jl`'s seeded `MersenneTwister`, and the 8
`mutant_rand28_sN` graphs from the parameters recorded in `rerun_129_corpus.jl`'s header
(`MersenneTwister(7)`, `n=28, p=0.12` base, `scaling_mutants(...; seeds=1:8, adds=5, dels=2)`).
`counterexample-n15` is the one real persisted file, in `../named-networks/`.

- `graph_gen.jl` — the generator (`scaling_random`, `scaling_mutants`, `verify_graph`)
- `graph_families.jl` — the fan-in-k and mesh-w adversarial families
- `oracles.jl` — tiered oracle helpers (note: `ipa_structure` uses a retired function; see REPRODUCE.md)
- `rerun_129_corpus.jl` — the post-fix confirmation run: 129/129 exact, script + method documented in its header
- `rerun_129_corpus_results.csv` — per-graph results of that run
- `paper_data.csv` — the original 129-graph results (timings, structure, oracle agreement)

Priors/link probabilities for this corpus: uniform 0.9 everywhere (never exactly 0 or 1
on any node), per `graph_gen.jl`'s `verify_graph` convention.
