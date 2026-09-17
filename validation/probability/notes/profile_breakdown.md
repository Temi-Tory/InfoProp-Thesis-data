# Grid cost profiling — IPA vs PBA (empirical complexity confirmation)

Grid (paper config A, nodes 1.0 / links 0.9). Structural: n_diamonds=12, maxcond=4, measured_ops=57.
Attribution = per-sample leaf-first source-file bucketing.


## pbox@200
- TIME  (22192 samples): PBA 97.9% | IPA 0.0% | other(Base/GC) 2.1%
- ALLOC (sampled)   : PBA 100.0% | IPA 0.0% | other 0.0%  (88.5 MiB sampled)

## Interval
- TIME  (1201 samples): PBA 0.0% | IPA 99.8% | other(Base/GC) 0.2%
- ALLOC (sampled)   : PBA 0.0% | IPA 100.0% | other 0.0%  (0.3 MiB sampled)

_For p-box, %%-time in PBA quantifies the 2^|C_d| conditioning-state convolution cost; IPA%% is
the diamond identification + belief bookkeeping. 'other' = Base array/GC not inside a PBA/IPA frame._
