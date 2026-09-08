# SF=12 Midamble-Point reproduction report

## Outcome

The MATLAB R2022a implementation completed the requested experimental
reproduction for the SF=12 right panels of paper Figures 10 and 11. The
delivered primary figure contains three curves:

1. AWGN and Rician fading without Doppler.
2. Point estimation.
3. Midamble-Point estimation.

All curves come from raw Monte Carlo error counts. No paper marker value,
curve fit, horizontal shift, scale factor, or post-hoc optimization enters the
simulation.

## Full-run evidence

- SNR grid: -30 through -21 dB in 1 dB increments.
- Strategies per case: 3.
- Points per case: 30.
- Packets per point: 5056 (batch-granularity realization of the 5000 minimum).
- Data symbols per point: 116288.
- Minimum accumulated symbol errors per point: greater than 1500.
- Every fittedOrTuned flag: false.
- MATLAB release: R2022a.
- Communications Toolbox: 7.7.

At -21 dB:

| Case | Strategy | SER | 95% CI |
|---|---|---:|---:|
| 1 | No Doppler | 0.028773 | [0.027828, 0.029750] |
| 1 | Point | 0.072811 | [0.071331, 0.074318] |
| 1 | Midamble-Point | 0.075253 | [0.073751, 0.076783] |
| 2 | No Doppler | 0.028696 | [0.027752, 0.029671] |
| 2 | Point | 0.806979 | [0.804701, 0.809237] |
| 2 | Midamble-Point | 0.109143 | [0.107364, 0.110948] |

Case 1 reproduces the paper's key relationship Point approximately equals
Midamble-Point. Case 2 reproduces the high-rate failure of Point and the strong
benefit of Midamble-Point; at -21 dB the experimental relative SER reduction
is approximately 86.5 percent.

## Mandatory validation gates

- 10000 random LoRa symbols, no noise and no Doppler: zero errors.
- Positive 10 kHz Point CFO: estimate 10009.765625 Hz; error 9.765625 Hz,
  below one 30.517578125 Hz FFT bin.
- Reference [50] and [51] orbital landmarks:
  visibility half-time 366.028752 s, fD(-366 s) 20226.569967 Hz,
  fD(0) 0 Hz, center rate -279.089833 Hz/s.
- Frame: 23 data chirps and 8 pure-upchirp midambles using the Eq. (20)
  ceiling count; the eighth is a terminal pilot.
- Midamble update: residual estimate is accumulated according to paper
  Eq. (17); Case 2 tracking is piecewise constant.
- LDRO: enabled for SF=12 at 125 kHz; the valid data-bin spacing is four.
- Unit tests and statement/function coverage: see the freshly generated
  `results/project_audit.json` and `results/coverage_summary.json`.
- Static analysis is rerun by `auditProject`; the audit requires zero active
  Code Analyzer findings.

## Quantitative difference from the published plot

The experimental curves reproduce the qualitative Case 1 overlap and Case 2
benefit, but they do not pass the frozen quantitative endpoint ranges. At
-21 dB the final figure visually places Case 2 Point around 0.55-0.75 and
Midamble-Point around 0.035-0.080, whereas the locked experiment gives
0.806979 and 0.109143. Case 1 and the no-Doppler baseline are also above their
acceptance intervals. These differences are not hidden or corrected.

The following paper details are insufficient or internally inconsistent:

1. Table 3 reports 1.341 s Midamble-Point ToA. It is reproduced to the stated
   millisecond precision only by the non-integer approximation
   `1.089536 + (23/3)*0.032768 = 1.340757... s`. Eq. (20) requires the ceiling,
   eight midambles, and a realizable 1.351680 s frame. This identifies the
   source of the 10.680 ms table/implementation difference.
   Point ToA is reproduced: 1.089536 s versus the table's rounded 1.090 s.
2. The [50]/[51] orbit gives -279.09 Hz/s at Case 2. With the implemented
   frame, the first-to-last data-symbol Doppler change is 265.16 Hz, while the
   paper text states approximately 510 Hz.
3. The paper does not publish the extended physical-layer simulator or its
   temporal Rician fading, receiver-filter and synchronization settings.
4. The public arXiv source is an earlier, incompatible experiment: AWGN-only
   with SF=12 midamble spacing one. That source configuration is reproduced
   separately and never used to overwrite the final-text configuration.

The eighth pilot is after the final payload symbol. A regression test confirms
that adding this terminal pilot changes ToA and Eq. (20) compliance but does
not change payload SER for an identical random seed.

An explicit Rician-coherence diagnostic at -21 dB found SER 0.028111 for one
coefficient per packet and 0.029324 for one coefficient per symbol, with
overlapping confidence intervals. Coherence therefore does not explain the
gap. The primary result retains packet-coherent Rician fading and explicit
unit-power AWGN. The prohibited measured-power AWGN option was not used.

During the final audit, a real/complex storage defect was found only in the
AWGN-only path: a real all-ones no-Doppler template caused `awgn` to generate
real rather than circular complex noise. `applyUnitPowerAwgn` now forces every
input to complex storage and a regression test enforces this. The final-text
Rician result tables above were already complex because their channel
coefficient is complex, so this correction does not alter those counts. The
separate AWGN-only author-source baselines were recomputed after the fix.

## Reproduction commands

From the project folder:

    run(fullfile("scripts", "runStage1Validation.m"));
    run(fullfile("scripts", "runSmokeReproduction.m"));
    run(fullfile("scripts", "runAllReproduction.m"));
    run(fullfile("scripts", "auditFullResults.m"));

The CSV files are the authoritative results. PNG files are rendered from those
CSV values, and FIG files remain editable in MATLAB.

The machine audit reports `independent_reproduction_passed` while separately
reporting
`paperMatchState=not_reproducible_from_available_publication_materials` and
`completePaperReproductionClaimed=false`. This prevents a validated,
independent experiment from being mislabeled as a complete point-for-point
paper reproduction.
