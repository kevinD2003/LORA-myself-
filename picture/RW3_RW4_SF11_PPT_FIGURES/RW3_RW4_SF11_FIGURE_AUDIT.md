# RW3/RW4 SF11 Figure Audit

- Generated: `2026-09-09 16:18:45`
- Project root: `D:\codex\Lora(eg)\project\orbit_doppler\satellite_fig3_rolling8`
- Git commit SHA: `UNAVAILABLE (project is not a Git worktree)`
- MATLAB: `9.12.0.1884302 (R2022a)`
- Selected real run: schedule frame `341`, SNR `-20 dB`, payload seed `2026271141`, noise seed `2026271241`.
- Run command: `"E:\Matlab2022\MATLAB2022\bin\matlab.exe" -batch "addpath(''D:\codex\picture\RW3_RW4_SF11_PPT_FIGURES''); generate_rw3_rw4_sf11_figures"`
- Main receiver: `satelliteFig3SenLoRaVirtualPilotDecode` (isolated-frame mode).
- Rate source: `isolated-frame known-preamble phase fit`.
- Receiver reads orbit truth / payload truth: **NO**. `truth` and transmitted labels are passed only to offline selection metrics and plot overlays after receiver execution.

## Verified canonical configuration

| Parameter | Runtime value | Code source |
|---|---:|---|
| `SF` | `11` | `satelliteFig3Config.m` |
| `BW` | `250000` | `satelliteFig3Config.m` |
| `Fs` | `250000` | `satelliteFig3Config.m` |
| `fc` | `868000000` | `satelliteFig3Config.m` |
| `CR` | `3` | `satelliteFig3Config.m` |
| `bootstrapPilotCount` | `8` | `satelliteFig3Config.m` |
| `payloadSymbolCount` | `112` | `satelliteFig3Config.m` |
| `virtualPilotHistoryLength` | `8` | `satelliteFig3Config.m` |
| `maxSenLoRaIterations` | `5` | `satelliteFig3Config.m` |
| `confidenceAlpha` | `0.8` | `satelliteFig3Config.m` |
| `confidenceThresholdScale` | `1` | `satelliteFig3Config.m` |
| `amendLlrMix` | `0.5` | `satelliteFig3Config.m` |
| `senloraMinimumMarginRatio` | `0.15` | `satelliteFig3Config.m` |
| `senloraRequireSoftHardAgreement` | `true` | `satelliteFig3Config.m` |
| `senloraUseSoftDecodedPilotLabels` | `false` | `satelliteFig3Config.m` |
| `senloraUseCausalConfidenceTiming` | `true` | `satelliteFig3Config.m` |
| `confidenceInnovationLimitBins` | `0.22` | `satelliteFig3Config.m` |
| `residualPeakRatioThreshold` | `1.05` | `satelliteFig3Config.m` |
| `decisionPeakRatioThreshold` | `1.05` | `satelliteFig3Config.m` |
| `historyDecay` | `0.85` | `satelliteFig3Config.m` |
| `huberThresholdBins` | `0.15` | `satelliteFig3Config.m` |
| `residualSearchBins` | `-0.5 -0.4 -0.3 -0.2 -0.1 0 0.1 0.2 0.3 0.4 0.5` | `satelliteFig3Config.m` |
| `maxRateBinsPerSec` | `2` | `satelliteFig3Config.m` |
| `senloraRateReleasePilotCount` | `2` | `satelliteFig3Config.m` |
| `senloraRateTrackingDeviationLimitBinsPerSec` | `0.1` | `satelliteFig3Config.m` |
| `senloraVirtualPilotInnovationGain` | `0.35` | `satelliteFig3Config.m` |
| `senloraPhasePairInnovationGain` | `0.6` | `satelliteFig3Config.m` |
| `senloraVirtualPilotCfoStdBins` | `0.075` | `satelliteFig3Config.m` |
| `senloraPhasePairInnovationLimitBins` | `0.1` | `satelliteFig3Config.m` |
| `senloraPhasePairAgreementLimitBins` | `0.15` | `satelliteFig3Config.m` |
| `senloraVirtualPilotRateStdLimitBinsPerSec` | `0.1` | `satelliteFig3Config.m` |

## RW3 implementation chain

1. `satelliteFig3SenLoRaConfidence.m`: compensated symbol -> hard-dechirped FFT spectrum -> FFT-energy log probabilities -> Gray-bit LLRs.
2. The same function deinterleaves those LLRs, performs soft Hamming(7,4), computes best-vs-second-best codeword margin, amends the LLRs, and forms symbol confidence as the sum of squared amended-LLR magnitudes.
3. `tauBlock = mean(C)+std(C)` and `tauGlobal = alpha*tauGlobal+(1-alpha)*tauBlock`; `confidentMask` compares confidence to `confidenceThresholdScale*tauGlobal`.
4. `satelliteFig3SenLoRaIterativeDecode.m` adds minimum margin ratio, soft-hard agreement, and two-pass stability. A proposed symbol is not a final VP.
5. `senloraUseSoftDecodedPilotLabels=false`: soft Hamming determines trust only. The tracker label is the compensated hard LoRa decision.
6. The tracker separately enforces residual peak ratio, non-boundary peak, 0.22-bin innovation, and decision peak ratio before insertion.

## RW4 implementation chain

- `satelliteFig3RollingPilotTracker.m` fills eight slots with known preambles. `localInsert` writes `idx(nextSlot)` and advances `nextSlot=mod(nextSlot,8)+1`, so every accepted VP replaces exactly one oldest slot.
- Residual CFO candidates are exactly `-0.5:0.1:0.5 bin`; actual innovation limit is `0.22 bin`; both peak-ratio thresholds are `1.05`; history decay is `0.85`; Huber threshold is `0.15 bin`.
- This delivered run is isolated: initial rate comes from the known-preamble phase fit. `satelliteFig3CrossFrameRateUpdate.m` is the separate continuous-pass path, with at most eight causal preceding-frame preamble CFO observations.
- Truth is evaluation-only and never appears in the receiver function interface.

## Figure-variable mapping

### 1. `fig_rw3_sf11_confidence_timeline`

- Input: `selected_run_workspace.mat` -> `decoded.iterationHistory(2).soft` and final `decoded.tracker`.
- Curves: `confidence`, `tauBlock`, `tauGlobal`; markers: `proposedMask`, `stableMask`, `requestedMask`, `acceptedMask`.
- Gate variables: `marginRatio`, `softHardAgreement`; label audit: `decodedWaveformBins`, `hardWaveformBins`.
- Outputs: PNG / FIG / MAT in `D:\codex\picture\RW3_RW4_SF11_PPT_FIGURES`.

### 2. `fig_rw3_sf11_vp_admission_waterfall`

- Runtime stages and counts:
  - `Total payload`: `112`
  - `Confidence pass`: `21`
  - `+ Margin-ratio pass`: `10`
  - `+ Soft-hard agreement`: `10`
  - `+ Two-pass stable/requested`: `10`
  - `+ Tracker accepted`: `10`
- Output MAT contains `stageNames`, `stageCounts`, and exact logical `stageMasks`.

### 3. `fig_rw4_sf11_causal_tracking`

- Truth overlays: `truth.trueDopplerHz/config.fftBinSpacingHz`, `truth.trueDopplerRateHzPerSec/config.fftBinSpacingHz`.
- Receiver curves: `decoded.tracker.predictedCfoBins`, `predictedRateBinsPerSec`, `activeHistoryCount`.
- Markers: first 8 preambles, `pilotAccepted`, and `requestedMask & ~pilotAccepted`.

### 4. `fig_rw4_sf11_residual_rolling8`

- Error: `trueCfoBins-predictedCfoBins` in FFT bins; reference lines are exactly +/-0.5 bin.
- Ring-buffer trace: reconstructed exactly from `pilotAppliedAtRows` and the source `localInsert` cyclic-slot rule; saved as `historySlotSymbolIndex`.

## Source locations and thresholds

- `satelliteFig3Config.m`: canonical physical/link constants and Stage55 gate/tracker constants.
- `satelliteFig3SenLoRaConfidence.m`: FFT/log-probability/LLR/soft-Hamming/confidence/threshold implementation.
- `satelliteFig3SenLoRaIterativeDecode.m`: proposal, margin ratio, agreement, stability, requested mask, and hard-label policy.
- `satelliteFig3SenLoRaVirtualPilotDecode.m`: Stage55 isolated/continuous rate provenance and quality-aware option wiring.
- `satelliteFig3RollingPilotTracker.m`: residual/peak gates, causal availability, CFO/rate outputs, pilot acceptance, active history, and cyclic replacement.
- `satelliteFig3PhaseRotationEstimate.m`: residual CFO/phase observation.
- `satelliteFig3CrossFrameRateUpdate.m`: causal cross-frame Rolling-8 rate state.

All four requested figures were directly supported by runtime variables; no synthetic, smoothed, interpolated, or manually redrawn experimental curve was used.
