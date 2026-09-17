# Diamond-identification rewrite — status

## Goal
Replace the buggy diamond IDENTIFICATION (hybrid reuse = Bug #1, completeness loop = Bug #2) with a
correct-by-construction producer that plugs into the EXISTING, unchanged propagation
(`update_beliefs_iterative` / `updateDiamondJoin`). Propagation is correct GIVEN correct diamonds and is
T-generic; only identification is rebuilt.

## Current artifact: `validation/new_identify.jl`
`new_identify(edgelist, node_priors, link_probs, source_nodes, fork_nodes, join_nodes, ancestors,
descendants, iteration_sets) -> (root_diamonds::Dict{Int,DiamondsAtNode},
unique_diamonds::Dict{UInt64,DiamondComputationData{T}})` — exactly the two objects the propagation
consumes. Drop-in for `identify_and_group_diamonds` + `build_unique_diamond_storage...`.

### Algorithm (recursive conditioning, single-fork-per-level)
For a join `v`: pick the topologically-highest fork `f` that is a shared ancestor of ≥2 of `v`'s parents
and is not already conditioned (boundary `E`); emit a diamond with `conditioning_nodes = {f}` (SINGLE
fork so `updateDiamondJoin`'s product weighting stays valid); cut incoming edges to `E∪{f}`; recurse on
inner joins in context `E∪{f}` until parents share no un-conditioned fork → plain inclusion-exclusion.
This mirrors `validation/rc_core.jl` (the proven-correct reference).

## Validation status (after the grid fix — Option A)
- **Broad sweep (`validation/new_validate.jl`)**: 114 random+mutant DAGs vs exact CUDD → **0 wrong**.
- **Structured (`validation/new_power.jl`)**: power-network OK (8e-17), grid-graph **now OK** (1.1e-16),
  KarlNetwork OK (5.5e-17, prop 0.4s). All shallow, fast, no blow-up.

## THE FIX (Option A) — context-aware conditioning + zero-weight skip
Two matched pieces:
1. **Producer** (`validation/new_identify.jl`): `conditioning_nodes = {f} ∪ (E ∩ relevant(edges))` — the
   one new fork PLUS the already-conditioned upstream forks that actually appear in this diamond's edges.
   This makes the diamond identity `create_diamond_hash_key = (edgelist, conditioning)` encode the outer
   context, so root-diamond@7 (`{3}`) and the same diamond nested under a diamond that already conditioned
   node 1 (`{1,3}`) are DISTINCT hkeys → no collision → correct. Restricting to `relevant(edges)` keeps
   every conditioning node in the enclosing `belief_dict` (isolated E nodes would KeyError). Structure is
   SHALLOW (each fork conditioned once) → no recursion-depth blow-up.
2. **Propagation** (`InfoPropFrmwrk/.../DiamondPropagation.jl`, `updateDiamondJoin`): zero-weight
   conditioning skip — a conditioning node whose contextual belief is exactly 0/1 (pinned by an outer
   conditioning) is treated as a fixed source, not enumerated. So the extra context nodes cost nothing and
   only the one genuinely-free fork per level contributes a factor of 2. Float64-only (exact 0/1);
   pbox/Interval keep full enumeration (correct, unoptimized). Pure optimization — results identical.

These two are a PAIR: the producer emits the context-distinct diamonds; the skip makes the extra
conditioning nodes free, so there is no 2^depth state blow-up and no deep-nesting recursion.

## OLD KNOWN BUG — grid-graph (NOW FIXED by Option A above; kept for the record)
Δ ≈ 3.3e-3 (nodes 7,8,11,15). rc_core was EXACT on the same graph, so the defect was in the
producer→propagation mapping, not the theory.

## grid-graph root cause (fully characterized)
A diamond's identity is `create_diamond_hash_key(diamond) = hash(sorted edgelist, sorted conditioning)`.
When an upstream fork is a graph **SOURCE**, cutting its incoming edges is a **no-op**, so two genuinely
different contexts produce the *same* `(edgelist, conditioning)` diamond:
- **root** diamond@7 (cond {3}): node 1 is a FREE source → its inner join 6 must be conditioned on {1,5}.
- diamond@7 nested inside an outer diamond that already conditioned node 1: node 1 is FIXED → inner join
  6 only needs {5}.
Same hkey → the framework stores ONE `DiamondComputationData` → whichever context is built first wins →
the other silently reuses the wrong nesting. When the `{5}`-only version is reused in the root context
(node 1 free), node 6's conditional belief is wrong → node 7 wrong. Verified by CUDD conditionals
(`w[var3]=0/1`): inside the subgraph, framework `belief(6|3=1)=0.3586` vs exact `0.3512`.

## Fix attempts and why they failed (do not repeat)
1. **Cross-join reset of the conditioned set (context-free build)** → correct nesting, but violates the
   framework invariant that a nested diamond's edgelist ⊆ enclosing edgelist → `KeyError` in
   `updateDiamondJoin` (link_probability restricted to enclosing edges).
2. **Split roles: `B_cut` accumulates for edges, `cond_local` resets for pick_fork** → still `KeyError`,
   because `pick_fork` used GLOBAL ancestors and chose a fork not present in the restricted subgraph
   (e.g. KarlNetwork: join 17 in diamond@5 conditioned on node 11, absent from diamond@5's subgraph).
3. **Fully subgraph-local recursion (pick_fork over the subgraph)** → fixed the missing-node issue, but
   without a self-chain the join re-picks the SAME fork (still a branching source after its incoming is
   cut) → self-referential `sub_structs[v]` → **infinite recursion in propagation → OOM (crashed the
   machine twice)**.
4. **Subgraph-local + self_chain + cross-join reset (re-condition free source forks)** → correct, but a
   source fork that is a shared fork at many nesting levels gets re-enumerated at each level → **2^depth**
   state blow-up during propagation → OOM again on dense graphs (KarlNetwork).

## The real constraint
The framework's diamond identity `(edgelist, conditioning)` cannot encode the outer conditioning CONTEXT,
but the correct single-fork nesting DEPENDS on it (which upstream forks are already fixed). rc_core avoids
this by memoizing on `(v, cond ∩ anc(v))` — the actual conditioned set. The framework needs the analogous
thing: a **context-aware computation key**. Two viable directions (NEXT STEP, needs care + small changes
confined to identification + the lookup key, NOT the propagation math):
- **(A)** Key `unique_diamonds` / `create_diamond_hash_key` on `(edgelist, conditioning, fixed-source-set
  ∩ relevant)` so root vs nested diamond@7 are distinct entries, each with its correct, non-redundant,
  efficient nesting. `updateDiamondJoin` must compute the same key (it already calls
  `create_diamond_hash_key(diamond)`), so the fixed-source context must travel on the `Diamond`/lookup.
- **(B)** Encode "fixed upstream source" structurally so the edgelist differs by context (e.g. drop a
  fixed source's outgoing edges INTO the diamond and fold its contribution into a boundary constant),
  making hkeys naturally distinct — larger change to the subgraph builder.

## INTEGRATED into the framework (Stream 3 done)
`new_identify` now lives at `DiamondDecomposition/Internal/NewIdentify.jl`, exported by
`InfoPropFramework`. The three case-study callers use it; `Pipeline_Rewrite.jl` is no longer included and
`identify_and_group_diamonds` / `build_unique_diamond_storage*` exports are removed. Propagation runs the
per-state enumeration SERIALLY (the `@spawn` path had a data race + small-stack overflow); factorization
keeps state counts small so serial is fast. `validation/new_identify.jl` is a no-op stub. See ROADMAP.md.

## Current state of the file
`validation/new_identify.jl` implements **Option A** (context-aware conditioning). `DiamondPropagation.jl`
carries the zero-weight skip. grid-graph, power-network, KarlNetwork all exact; broad-sweep regression
gate re-run in progress (`validation/new_broad.log`). Run propagation single-threaded (`julia -t 1`): the
per-state `Threads.@spawn` path uses a small task stack that can overflow on deep nesting even when the
main-stack recursion is fine.

## Attempt that failed and why (kept so it isn't retried)
"Maximal nesting" — always re-condition free source forks, context-free build. Correct on grid, but
re-conditioning a source fork at many nesting levels creates DEEP structural nesting; the zero-weight
skip bounds the STATE count but NOT the recursion DEPTH → StackOverflow on KarlNetwork (both threaded and
`-t 1`). Option A avoids it by conditioning each fork ONCE (shallow) and distinguishing contexts via the
conditioning set instead of via extra nesting.

## Test files
- `validation/new_identify.jl` — the producer (current).
- `validation/new_validate.jl` — broad sweep vs CUDD (0 wrong gate).
- `validation/new_power.jl` — structured-network regression vs CUDD.
- `validation/new_smoke.jl` — quick 3-graph smoke.
- `validation/grid_probe*.jl` — grid failure localization (CUDD conditionals).
- `validation/rc_core.jl` — proven-correct reference (recursive conditioning).
