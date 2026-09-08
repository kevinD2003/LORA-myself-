# SenLoRa MATLAB Confidence-Symbol Reproduction

This folder implements a MATLAB minimum reproduction of the SenLoRa paper's
confidence-symbol detection path:

```text
continuous LoRa IQ -> dechirp -> FFT spectrum -> bin probability -> LoRa Gray-bit LLR
-> soft Hamming decode -> symbol confidence -> adaptive threshold
```

For a Chinese review and learning walkthrough from experiment conditions to
principles and result interpretation, see
`PROJECT_REVIEW_AND_LEARNING_CN.md`.

## Run

Open MATLAB in this folder and run:

```matlab
run_senlora_confidence_demo
run_senlora_continuous_demo
run_predictive_doppler_ber_demo
run_sf11_variable_doppler_ber
```

Run the complete automated test suite with:

```matlab
runSenLoRaProjectTests
```

The canonical Stage55 implementation is
`../orbit_doppler/satellite_fig3_rolling8`.  It contains the Huang-PREC
continuous-phase fair replay, the SenLoRa VP-quality receiver, and the
two-method SER/BER trajectory figures.  Run only that stage suite with:

```matlab
runStage55ProjectTests
```

The former external Stage55 working copy is frozen; see
`../orbit_doppler/satellite_fig3_rolling8/CANONICAL_PROJECT.md`.

The project test runner discovers the root unit tests and all satellite-stage
regressions, and restores the MATLAB search path after execution.

The demo synthesizes one interleaving block, detects confidence symbols, and
plots `sum |LLR|^2` with the block/global thresholds.

`run_senlora_continuous_demo` processes a continuous 84-symbol sequence and
exports arrival-aligned correct/error/confident flags under `results/`.
It produces both an end-to-end IQ sequence plot and a four-panel paper
correspondence plot.

`run_predictive_doppler_ber_demo` adapts the supplied `PREC.m` phase-rotation
method to time-varying Doppler. A configurable number of bootstrap correct
symbols starts the tracker. Each later correct symbol measures its residual
on a 0.1-bin rotation grid and updates the next-symbol prediction and the
cumulative phase state. BER is compared with no compensation, static PREC,
ideal compensation, and the exact noncoherent AWGN theory.
`predictiveDopplerCompensate` also accepts an external correct-symbol mask,
so the previous confidence detector's `ConfidentFlag` can directly control
which decoded symbols are allowed to update the Doppler predictor.

`run_sf11_variable_doppler_ber` is the physical-parameter reproduction for
SF=11 and BW=250 kHz. Its BER-SNR experiment uses a rate profile that varies
from 250 to 750 Hz/s, while a separate 500 Hz/s reference verifies the
half-bin raw-decision transition at symbol 16 from the supplied figure. It
exports BER/SER curves, per-symbol CSV data, and confidence/correct/error
flags under `results/sf11_variable_doppler/`.

The channel in this experiment is explicitly
`r[n] = s[n] exp(j phi_D[n]) + w[n]`: a unit-gain flat channel with
continuous accumulated Doppler phase and complex sample-domain AWGN. It does
not include Rayleigh/Rician amplitude fading, multipath delay spread, or path
loss, because those effects would require a different theoretical BER line.

The main BER graph separates two pilot-update cases. The oracle curve is an
upper bound gated by known simulation truth. The receiver curve uses coded
payload blocks, the paper's local confidence threshold, and up to five
Algorithm-2-style compensation/confidence iterations. The separate flag plot
keeps the paper's global EMA threshold with alpha=0.8. At -15 dB the receiver
curve simulates 145,200 payload bits to resolve the 1e-4 target; other SNR
points use 29,040 bits.

## Key Files

- `run_senlora_confidence_demo.m`: runnable demo.
- `run_senlora_continuous_demo.m`: continuous sequence demo and CSV/MAT/PNG export.
- `synthesizeLoRaSignalSequence.m`: LoRa preamble/payload waveform generator.
- `dechirpLoRaSignalSequence.m`: synchronized dechirp and unitary FFT front end.
- `detectLoRaSignalSequence.m`: end-to-end IQ waveform detector.
- `plotSenLoRaPaperCorrespondence.m`: Sec. 5/Fig. 6/Algorithm 2 result mapping.
- `stepSenLoRaSymbolDetector.m`: one-symbol streaming interface.
- `detectContinuousSymbolSequence.m`: sequence wrapper and aligned flag arrays.
- `iterativeSoftDemodBlockFromFft.m`: Algorithm-2 style iteration wrapper.
- `detectConfidentSymbolsFromFft.m`: main detection chain for one block.
- `fftToBinLogProb.m`: paper probability mapping and noise-scaled ablation.
- `loraGrayBits.m`: LoRa Gray mapping from Fig. 6.
- `softHammingDecodeOne.m`: Algorithm 1 implementation.
- `updateConfidenceThreshold.m`: `tau_b = mean + std`, `tau_g` EMA.
- `testSenLoRaConfidence.m`: MATLAB unit tests.

## Continuous Flag Semantics

- `CorrectFlag=1`: hard FFT-bin decision equals the known simulation truth.
- `ErrorFlag=1`: hard FFT-bin decision differs from simulation truth.
- `ConfidentFlag=1`: the SenLoRa confidence score exceeds the adaptive threshold.
- `ReceiverDecisionFlag=+1/-1`: receiver considers the symbol likely correct/unsafe.
- `ReceiverDecisionFlag=0`: the last partial interleaving block is still pending.

Only a simulation or labeled capture can produce `CorrectFlag` and `ErrorFlag`.
An online receiver uses `ConfidentFlag`; a low-confidence symbol is not proof of
an error, so both truth flags and receiver flags are exported for evaluation.

## Paper Figure Correspondence

`results/paper_correspondence_confidence_detection.png` contains:

- panel (a): Fig. 6 and Eq. (12), FFT-bin probability `P(Z[f])`;
- panel (b): Eq. (13), Gray-mapped bit LLRs;
- panel (c): Sec. 5.2 block/global thresholds and selected confidence symbols;
- panel (d): Algorithm 2 `ConfdSym` beside truth-based correct/error flags.

The paper's Fig. 10 reports PRR/BER versus channel-estimation iterations. Its
exact `amendLLR` and `channelSense` formulas are not published, so this code
does not claim a numerical reproduction of Fig. 10.

## Important Reproduction Notes

- `detectLoRaSignalSequence` accepts raw complex IQ and performs dechirp/FFT.
  It assumes the LoRa frame start is known, matching the paper section's
  post-synchronization scope. An SDR capture still needs packet detection and
  frame alignment before this function.
- `deinterleaveBlock.m` is a minimal block transpose consistent with the
  synthetic demo. Replace it with exact LoRa diagonal deinterleaving for raw
  LoRa PHY packets.
- The paper names `amendLLR` and `channelSense` but does not fully define
  their formulas. This implementation keeps `amendMode="identity"` by default
  and leaves the channel update point explicit in the iterative wrapper.
- `fftToBinLogProb(..., "paper")` follows the paper equation. A practical
  ablation mode, `"noise-scaled"`, is included because subtracting the same
  `N0` from every softmax logit cancels during normalization.
