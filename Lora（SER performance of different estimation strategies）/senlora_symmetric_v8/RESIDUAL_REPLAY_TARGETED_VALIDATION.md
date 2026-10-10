# V8 blockwise residual replay targeted validation

Status: **REJECTED AS A COMPLETE FIX**

This validation reused mechanism seeds only. It selected the seven frames
with the largest original V8 error counts and the physical-mirror frame with
the same payload/noise seed for each selected frame. No Review or Formal seed
was used.

The candidate keeps the existing first pass. Its second pass freezes the
first-pass Hamming-reencoded labels, admits complete blocks only when soft and
hard decoding agree and the existing margin, peak-ratio and innovation gates
pass, fits a rolling-eight first-order residual CFO/rate model at Hamming-block
boundaries, and preserves correction phase continuously. A virtual pilot
affects later blocks only.

## Selected high-error frames

| orbit start (s) | packet | original V8 errors | first-pass errors | residual-replay errors | accepted VP |
|---:|---:|---:|---:|---:|---:|
| 41.81784 | 19 | 56 | 55 | 14 | 42 |
| -183 | 14 | 49 | 49 | 24 | 7 |
| 224.81784 | 6 | 47 | 47 | 0 | 14 |
| -45.75 | 8 | 41 | 43 | 4 | 21 |
| -45.75 | 17 | 41 | 49 | 11 | 35 |
| 133.31784 | 1 | 39 | 39 | 0 | 28 |
| 41.81784 | 7 | 38 | 53 | 46 | 28 |
| **Total** | | **311** | **335** | **99** | |

## Same-seed physical mirrors

| orbit start (s) | packet | original V8 errors | first-pass errors | residual-replay errors | accepted VP |
|---:|---:|---:|---:|---:|---:|
| -45.75 | 19 | 0 | 0 | 1 | 77 |
| 179.06784 | 14 | 0 | 0 | 0 | 91 |
| -228.75 | 6 | 4 | 34 | 27 | 35 |
| 41.81784 | 8 | 0 | 11 | 0 | 70 |
| 41.81784 | 17 | 0 | 1 | 0 | 84 |
| -137.25 | 1 | 0 | 44 | 0 | 28 |
| -45.75 | 7 | 0 | 0 | 0 | 91 |
| **Total** | | **4** | **90** | **28** | |

## Finding

The proposed residual replay is directionally useful when early reliable
virtual pilots exist. Across the seven selected high-error frames it reduced
errors from 311 to 99. On the worst 41.81784 s packet it reduced errors from
56 to 14 and reduced CFO-residual RMSE from about 0.638 to 0.275 bins.

It is not stable enough to promote. Another 41.81784 s packet increased from
38 to 46 errors after its reliable block evidence ended, and the -228.75 s
mirror frame increased from 4 to 27 errors. The seven mirror frames increased
from 4 total errors to 28. Alternative experiments that stopped residual-rate
extrapolation or used a trusted candidate chain traded one failure for another
and did not remove the spikes.

The large spikes therefore begin mainly in the first-pass trajectory, and a
residual-only second pass is not a complete solution. Once qualified payload
evidence disappears, a first-order trajectory has no receiver-visible
information about the later rate change. Under the current prohibition on a
higher-order model, rate hypotheses and current-block joint decoding, that
loss of observability cannot be repaired by tuning d0/d1 or VP gains. The
candidate must not replace the current V8 or advance to the full mechanism
grid, Review, or Formal in its present form.
