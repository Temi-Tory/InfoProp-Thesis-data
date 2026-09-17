# Reproducing the results

## Status at v1.0

The **data, numbers, and recorded server responses in this repository are final** — they
are what the thesis and the RESS paper report. What is deferred to a post-viva **`v1.1`**
tag is a clean-room re-run of every script below against the pinned package, with each
script's include path updated to the `_compat` shim and any calls to retired internal
functions fixed.

This is the sequencing the thesis data-repository plan anticipated: tag `v1.0` for the
version cited at submission, tag `v1.1` for post-viva corrections. Zenodo mints a distinct
DOI for each while keeping both resolvable.

## Environment

| Component | Version | Notes |
|---|---|---|
| Julia | 1.12 | |
| `InformationPropagationAnalysis` | 0.2.1 | registered; `julia --project=_compat -e 'using Pkg; Pkg.instantiate()'` |
| `ProbabilityBoundsAnalysis` | 0.2.11 | does not precompile on 1.12 (upstream); loads interpreted (~40 s), runs normally |
| BDD oracle | `validation/_bddenv/` | `BinaryDecisionDiagrams.jl`, **not** CUDD — for the exactness cross-checks only |
| Python | 3.10+ | `matplotlib`, `numpy` for the plot/convert scripts; `wntr` 1.5.0 for `net3_to_ipf.py` |

Timing convention (thesis-wide): wall-clock, single core, **second call in a warm
process** (a discarded warm-up run precedes every reported time).

## Per-script repointing (for v1.1)

Each `.jl` script under `validation/` and `converters/` currently begins with

```julia
const REPO = raw"C:\...\Info_Prop_Framework_Project"
include(joinpath(REPO, "InfoPropFrmwrk", "src", "Algorithms", "InfoPropFramework.jl"))
using .InfoPropFramework
```

For v1.1 this becomes

```julia
include(joinpath(@__DIR__, <relative path to>, "_compat", "InfoPropFramework.jl"))
using .InfoPropFramework
```

and repo-local helpers (`graph_gen.jl`, `oracles.jl`, `oracle.jl`) are included by their
new in-repo paths.

### Known fixes needed

- `validation/probability/_scripts/oracles.jl` — `ipa_structure` calls the retired
  `identify_and_group_diamonds`; the exactness scripts should use `new_identify` directly
  (as `corpus/random-and-mutated/rerun_129_corpus.jl` already does).
- CUDD-based comparison paths are replaced by the `_bddenv` pure-Julia oracle throughout.
- `net3_to_ipf.py` needs `Net3.inp` from WNTR 1.5.0's bundled library
  (`case-studies/net3/Net3.inp`, sha256 in `RESULTS.md`).

## What each toolkit's pack already contains

- `validation/probability/INDEX.md` — the 7 campaign runs, all complete, with script and
  results-CSV paths.
- `validation/critical-path/thesis_writing_pack/INDEX.md` — the CPM validation pack.
- `case-studies/net3/thesis_writing_pack/INDEX.md` — the Net3 case-study pack.
