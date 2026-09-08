# Locked paper protocol

## Primary target

- Figure 10, right panel: Case 1, SF=12, SER versus SNR.
- Figure 11, right panel: Case 2, SF=12, SER versus SNR.
- Required curves for the Midamble-Point reproduction stage:
  1. AWGN + Rician fading, no Doppler.
  2. Point estimation.
  3. Midamble-Point estimation.

The metric is SER (chirp error rate), not BER. Simulated curves are generated
from Monte Carlo trials. Paper-marker readings are never used as inputs to the
simulation and no curve fitting or post-hoc parameter optimization is allowed.

## Values stated by the paper

| Quantity | Value | Source |
|---|---:|---|
| Carrier frequency | 868 MHz | Table 2 |
| Bandwidth | 125 kHz | Table 2 |
| Spreading factor | 12 | Table 2 / Figure 10-11 right panels |
| Orbital height | 550 km | Table 2 |
| Satellite positions | Case 1, Case 2 | Table 2 |
| Case 1 orbit time | approximately -366 s | Section V / Figure 4 |
| Case 2 orbit time | 0 s | Section V / Figure 4 |
| Rician K factor | 10 dB | Section VII |
| Preamble upchirps | 8 | Table 2 |
| Complete downchirps for Point methods | 2 | Table 2 |
| Payload | 120 bits | Table 2 |
| Coding parameter CR | 1 | Table 2 |
| Midamble-Point spacing at SF=12 | 3 data chirps | Table 2 |
| SNR | average received signal power / noise power in B | Section VII-A |
| Point ToA at SF=12 | 1.090 s | Table 3 |
| Midamble-Point ToA at SF=12 | 1.341 s | Table 3 |

The paper defines each midamble as a pure upchirp (LoRa symbol 0). The initial
Point estimate comes from the last synchronization downchirp. At each midamble,
the receiver estimates the residual frequency offset after applying the current
estimate, then iteratively updates the accumulated estimate (Eq. 17). The model
is piecewise constant (Remark 3).

## MATLAB implementation fixed by the referenced ChatGPT reproduction plan

These values make the experiment executable but are not represented as values
reported verbatim by the paper:

- MATLAB R2022a implementation.
- Sample rate = bandwidth (one complex sample per chip).
- FFT length = 2^SF = 4096; no zero padding or sub-bin interpolation.
- 23 payload chirps, inferred from Point ToA:
  `(8 + 2.25 + 23) * 4096 / 125000 = 1.089536 s`.
- Eq. (20) ceiling count is retained: midambles follow chirps 3, 6, ..., 21,
  plus one terminal pilot after chirp 23 (8 midambles total). Table 3's
  1.341 s is explained by the non-realizable fractional approximation
  `23/3=7.666...` pilots; see `PUBLICATION_CONSISTENCY.md`.
- LDRO enabled for the final Figure 10/11 SF=12 reproduction. The paper states
  that LDRO is mandatory for SF=11/12 at 125 kHz, and defines the alphabet as
  M=2^(SF-2), increasing adjacent valid-bin separation by four. LDRO OFF is
  only a diagnostic corresponding to the paper's Figure 14 comparison.
  The production detector finds the fine-grid FFT peak and maps it to the
  nearest spacing-four symbol, matching the paper's 0.5B/M tolerance model.
  A valid-bins-only alternative is retained solely as a diagnostic and is not
  used for primary results.
- SNR sweep -30:-21 dB, plotted with x-limits [-31, -21].
- Fixed MATLAB `twister` random seed 2025 (derived deterministically per case,
  strategy and SNR point).
- Flat block Rician fading: one coefficient per packet, E[|h|^2] = 1.
- AWGN is added with `awgn(signal, snrDb, 0)`: explicit 0 dBW unit transmit
  power. All inputs are forced to complex storage so MATLAB adds circular
  complex baseband noise on every strategy, including a zero-symbol
  no-Doppler tone. The prohibited `'measured'` option is never used.

The 23-chirp inference is checked independently against Table 3. Reference
[12] validates an I/Q receiver with ADC rate 2B, ideal-like low-pass filters,
downsampling to B, dechirping and a 2^SF FFT. Its reported ideal-filter AWGN
operating points are consistent with this project's corrected complex-AWGN
baseline. The paper does not publish the extended simulator or all
packet-format and time-selective Rician details; ambiguity is reported rather
than tuned against Figure 10/11.

## Conflicting public source revision

The public arXiv source snapshot predates the supplied final IEEE PDF. Its
`main.tex` states AWGN plus Doppler and sets SF=12 `n_int=1`; the final paper
states Rician plus AWGN and sets SF=12 `n_int=3`. The historical source profile
is implemented by `authorFigureSf7Config` and `authorFigureSf12Config` and
writes files with the `_author_source` suffix. It is never substituted for the
locked final-text profile.

## Doppler model

The implementation re-derives the circular-orbit zenith-pass model from paper
reference [50], cross-checked against the public MATLAB code accompanying [51]:

`nu(t) = -(a Re omega / c) sin(omega t) /
          sqrt(a^2 + Re^2 - 2 a Re cos(omega t))`

with `a = Re + h`, `omega = sqrt(mu/a^3)`, and `fD(t) = fc nu(t)`.
Time-varying Doppler is applied through integrated phase, never as `fD(t)*t`.

## Mandatory gates

1. No-noise, no-Doppler LoRa: 10,000 random symbols, SER = 0.
2. Constant +10 kHz CFO: Point estimate error no greater than one FFT bin
   (30.517578125 Hz).
3. Doppler landmarks: visibility half-time approximately 366 s,
   fD(-366 s) approximately +20.2 kHz, fD(0) = 0, and center Doppler rate
   approximately -279 Hz/s for the locked [50] model.
4. Tracking diagnostic: Point is constant; Midamble-Point is staircase-shaped
   and updates only at the configured midambles.
5. No-Doppler SER baseline before Case 1/2.
6. Class-based `matlab.unittest` regression tests must pass under MATLAB R2022a.
7. Case 1 and Case 2 Monte Carlo outputs, with counts and 95% binomial
   confidence intervals saved alongside SER.
8. Frozen paper endpoint bounds are used only for acceptance; they never enter
   simulation or parameter selection.

No later stage may be used to silently alter a parameter that failed an earlier
gate. Corrections must be justified by the paper, a cited reference, or a code
defect demonstrated by a focused test.
