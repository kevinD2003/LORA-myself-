# Reproduction and project-comparison results

Date: 2026-09-25

## 1. Paper Table-IV anchor

Each SNR used one complete horizon-to-horizon pass containing 182 consecutive
51-symbol packets. The score contains 7,826 payload symbols per SNR. Both
receivers used the same IQ samples; payload truth was used only for scoring.

| SNR dB | Adaptive reproduced % | Adaptive paper % | Fixed reproduced % | Fixed paper % |
|---:|---:|---:|---:|---:|
| 0 | 0.000 | 0.00 | 18.860 | 22.75 |
| -5 | 0.000 | 0.00 | 19.052 | 23.06 |
| -10 | 0.026 | 1.11 | 22.374 | 24.30 |
| -15 | 3.233 | 4.82 | 30.961 | 28.66 |
| -20 | 27.869 | 13.44 | 49.246 | 36.57 |

The fixed-LR error floor and the advantage of symbol-by-symbol adaptive
updating are reproduced. Fixed-LR differs from the paper by -4.01 to +12.68
percentage points; the largest discrepancy is at -20 dB. Adaptive LR agrees
in trend down to -15 dB but enters decision-feedback failure earlier at
-20 dB. Consequently this is a mechanism-and-trend reproduction, not a claim
of exact numerical identity.

The second Table-IV metric is the mean magnitude of the symbol error among
erroneous symbols:

| SNR dB | Adaptive reproduced | Adaptive paper | Adaptive delta | Fixed reproduced | Fixed paper | Fixed delta |
|---:|---:|---:|---:|---:|---:|---:|
| 0 | 0.000 | 0.00 | 0.000 | 3.770 | 1.56 | 2.210 |
| -5 | 0.000 | 0.00 | 0.000 | 3.758 | 1.58 | 2.178 |
| -10 | 1.000 | 2.16 | -1.160 | 3.363 | 1.57 | 1.793 |
| -15 | 4.269 | 2.58 | 1.689 | 2.792 | 1.59 | 1.202 |
| -20 | 107.818 | 491.17 | -383.352 | 68.357 | 126.32 | -57.963 |

The low-SNR magnitude discrepancy reinforces the interpretation that omitted
receiver details materially affect decision-feedback failures.

The largest uncertainty is the paper's omitted receiver detail at low SNR:
the exact preamble count, FFT centroid convention, circular unwrapping, noise
normalization, and packet placement are not fully specified. Equation (15) is
implemented literally for the anchor because the physically integrated phase
model removes most of the published fixed-LR error floor.

## 2. Full-PHY Figs. 3-4 and Tables V-VI

The complete PHY includes whitening, Hamming coding, padding, diagonal
interleaving, Gray mapping, and CRC. Each CR/SNR cell uses 3000 overpasses.
CR1 contains 238 packets per pass and CR4 contains 163, matching the packet
index ranges of the published figures.

| CR | SNR | Adaptive BER reproduced/paper % | Fixed BER reproduced/paper % | Adaptive PLR reproduced/paper % | Fixed PLR reproduced/paper % |
|---:|---:|---:|---:|---:|---:|
| 1 | 0 | 0.000 / 0.44 | 2.163 / 2.22 | 0.000 / 0.88 | 24.790 / 0.88 |
| 1 | -5 | 0.000 / 0.45 | 2.180 / 2.28 | 0.000 / 0.88 | 25.674 / 0.88 |
| 1 | -10 | 0.000 / 0.58 | 2.344 / 2.48 | 0.011 / 0.95 | 34.353 / 0.88 |
| 1 | -15 | 0.100 / 1.28 | 3.136 / 2.80 | 7.739 / 1.18 | 60.932 / 1.03 |
| 1 | -20 | 5.453 / 4.74 | 7.385 / 6.88 | 66.946 / 7.96 | 89.697 / 7.52 |
| 4 | 0 | 0.000 / 0.00 | 3.272 / 3.19 | 0.000 / 0.00 | 28.227 / 0.00 |
| 4 | -5 | 0.000 / 0.02 | 3.347 / 3.28 | 0.000 / 0.00 | 30.481 / 0.00 |
| 4 | -10 | 0.000 / 0.31 | 3.812 / 3.47 | 0.004 / 0.12 | 42.177 / 0.00 |
| 4 | -15 | 0.145 / 0.96 | 5.000 / 4.06 | 1.772 / 0.20 | 60.521 / 0.20 |
| 4 | -20 | 6.772 / 4.81 | 9.459 / 8.02 | 50.789 / 7.89 | 78.455 / 7.89 |

Fixed-LR coded BER is reproduced closely: the difference is below 0.14
percentage point for CR1 from 0 to -10 dB and below 0.35 point for CR4 over
the same range. The packet-index curves reproduce the central high-Doppler-
rate degradation and the sign-change notch. Adaptive LR is better than Fixed
LR throughout but is too optimistic above -20 dB under the frozen empirical
centroid-noise model.

PLR does not numerically reproduce the paper when evaluated with a standard
post-Hamming CRC. In particular, the paper combines nonzero coded BER with
near-zero CRC loss, while the implemented CRC rejects many Fixed-LR packets.
The discrepancy is retained as an audit result instead of introducing an
unpublished erasure rule or scaling the output.

## 3. Current-project comparison

The definitive comparison is now the 1000-packet-per-cell V4 Unified V23
experiment across both cases and every SNR from -30 to -21 dB. It aligns with
Huang V9, Stage55 V16, and Midamble V6. The 100-row CSV, four-panel plot,
per-packet MAT records, and Chinese report are under `results/project_formal_v23_verified/`
and `PROJECT_FORMAL_V23_REPORT.md`.

At high-rate -21 dB, Stage55 SER is 0.016313, Midamble SER is 0.043491,
Dietl Adaptive SER is 0.584080, and Dietl Fixed SER is 0.748071. The paired
Adaptive-minus-Stage55 SER difference is 0.567768 with packet-bootstrap 95%
interval [0.546737, 0.589152]. All three V23 baseline error totals match the
original project report exactly.

The older 30-packet smoke comparison under `results/project_comparison/`
used Huang V2 and a different seed domain. It is retained as a diagnostic
artifact; all current-project conclusions use the formal V23 results above.

The subsequent paper-flow correction processes all physical V4 symbols,
including already-known midambles. Its separate seven-method results are in
`results/project_paper_flow_v2/` and `PAPER_FLOW_V2_REPORT.md`. At -21 dB,
Adaptive LR SER falls from 0.5783 to 0.3009 in the high-shift case and from
0.5841 to 0.3033 in the high-rate case; it remains above Stage55. At -24 dB
the SER slightly worsens. This is a V4 known-midamble adaptation and retains
the common frame's existing pilot overhead.

A later code check found the centroid's "size 10" had been interpreted as
ten neighbors on each side (21 total). The literal ten-point, no-midamble
paper port is the appropriate result for the user's -21 dB question. Across
1000 paired frames per case, its SER is 0.1770 (high shift) and 0.1563
(high rate), versus 0.5783 and 0.5841 for the previous 21-point port.
Known-midamble assistance with the ten-point estimator performs worse than
the ten-point no-midamble method. See `PAPER_10POINT_ALIGNMENT_REPORT.md`
and `results/project_centroid10_alignment_v4/`. The Table-IV anchor rerun
with ten points is in `results/paper_centroid10_verified/`; the earlier 3000-overpass
full-PHY artifact remains a documented 21-point result.

Two minimal receiver-only LR refinements were evaluated separately from the
faithful paper baseline: ordinary LS over 16 recent symbols and Theil-Sen
robust fitting over eight. On fresh V4 -21 dB packet IDs 1001:2000, both
lowered SER in the high-shift and high-rate cases without extra pilots or
truth input. See `REFINED_LR_REPORT.md` and the independent-holdout CSV.
Paired SER and BER gain intervals are both reported in
`results/refined_lr_paired_ber/`.

## 4. Reproducibility and fairness

- Fixed LR and Adaptive LR receive no payload truth or orbit truth.
- Adaptive LR updates only after the current hard decision and affects later
  symbols, preserving causality.
- V4 payload, noise, channel, and case seeds are paired across all receivers.
- The project MAT signature binds the complete V4 configuration, the Table-IV
  anchor signature, and the full-PHY signature.
- Midamble rows remain in the shared frame; the Dietl receivers ignore their
  values and use only their elapsed physical-row positions.
- The complete assumptions and interpretation boundary are in `README.md`
  and `VALIDATION.md`.
- `run_reproduction_audit` passes 14 regression tests and verifies all current
  MAT/CSV tables, signatures, anchor linkage, sample counts, and required PNGs.
