# Grid benchmark (16-node directed grid, Tong & Tien 2019) — verification note

Setup (from the paper): sources {1,3,13}; **all node priors = 1.0 (perfect nodes), link reliability
R_l = 0.9**. (NB: this is nodes=1.0 / links=0.9, NOT all-0.9.)

## Result: the paper's grid table is CORRECT
Corrected IPA (framework `new_identify` + propagation) reproduces the paper's Table
[tab:resultcomparison_grid] and the exact CUDD ROBDD to machine precision (worst |diff| = 1.1e-16). The
published "IPA = Exact" column stands; **no correction to the paper's grid numbers is needed.**

## Two distinct bugs found & fixed during hardening (neither affects the published table)
1. **Context/hkey collision** (old Pipeline identification): produced wrong reliabilities on reconvergent
   grids at NON-1.0 probability assignments (measured Δ≈3.3e-3 at nodes 7,8,11,15 under random priors).
   Fixed by context-aware conditioning.
2. **`is_det` over-exclusion** (introduced by the rewrite, now fixed): the identifier skipped any node with
   prior 0 or 1 from conditioning. At the grid benchmark EVERY node prior is 1.0, so it produced ZERO
   diamonds → naive inclusion-exclusion → wrong (Δ≈1.6e-3 at nodes 6,7,8,11,12,15,16). Root cause: a
   prior-1 NON-source fork still has UNCERTAIN reachability (via its 0.9 edges) and must be conditionable;
   only prior-0 (dead) and prior-1 SOURCES have deterministic reachability. Fixed: exclude only those.

After both fixes: grid at (1.0/0.9) → 5 diamonds, exact (1.1e-16, matches paper); grid at all-0.9 →
8 diamonds, exact; random corpus unchanged (0 wrong).

## For the response
"We independently re-verified the grid benchmark against a canonical ROBDD (CUDD): IPA reproduces the exact
node reliabilities (max error 1.1e-16), confirming the published results. During hardening we also
identified and fixed two edge-case identification errors (a context-collision on reconvergent grids under
non-unit node priors, and an over-aggressive determinism check that suppressed conditioning when all node
priors equal 1) — both are corrected and covered by the expanded validation corpus."
