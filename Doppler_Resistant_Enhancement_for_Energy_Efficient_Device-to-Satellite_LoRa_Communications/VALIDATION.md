# Validation record

This file is updated only from executed evidence.

## Required gates

- [x] MATLAB regression suite passes: 17 passed, 0 failed (2026-09-28).
- [x] Paper Table-IV anchor completed at all five SNRs, 182 packets/SNR.
- [x] Full PHY completed for CR1 and CR4 at all five SNRs with 3000
  overpasses per condition.
- [x] Figures 3 and 4 and Tables V and VI were generated and compared with
  the published values.
- [x] Project comparison started only after the complete paper anchor.
- [x] All five project receivers processed identical paired received IQ frames.
- [x] Fixed LR and Adaptive LR declare no payload-truth or orbit-truth input.
- [x] Result CSV/MAT/PNG files were generated and visually checked.
- [x] Automated reproduction audit passes all signatures, MAT/CSV equality,
  truth-leakage declarations, sample counts, and required artifacts.
- [x] Formal V23 comparison completed all 20 case/SNR cells with 1000 paired
  packets per cell; the three project baselines match the original V23 report
  exactly in symbol and bit error counts.
- [x] Complete-symbol paper-flow adaptation completed the same 20 cells and
  20,000 IQ frames; all frame fingerprints match the verified V23 result.
- [x] Tests show the new flow is identical to the Eq. (18)-(22) decoder when
  no midambles exist, and consumes all 37 known V4 midambles causally.
- [x] The literal ten-point Table-IV rerun completed five SNRs with 182
  packets per SNR, and the -21 dB four-way project check completed 1000
  paired packets in each of the two cases.
- [x] Receiver-only refined fits were tested with 150 development and 850
  validation packets per case, then on fresh packet IDs 1001:2000.
- [x] Paired BER-gain intervals were recomputed from frozen per-packet errors
  with 2000 shared packet-bootstrap resamples and checked against CSV/MAT.
- [x] No-midamble robust replay V3 completed 20 case/SNR cells with 1000
  packets per cell; every full cell and every packet-101:1000 holdout cell has
  no more symbol errors than Midamble V6.

## Executed sample counts

- Paper anchor: 182 packets and 7,826 payload symbols at each of five SNRs.
- Full PHY: CR1 uses 238 packets/pass and CR4 uses 163 packets/pass; every
  CR/SNR condition contains 3000 overpasses.
- Project comparison: 30 paired packets per case/SNR cell, 3,360 payload
  symbols and 23,040 information bits per method/cell.
- Project cells: start times -366 s and 0 s; SNR -27, -24, and -21 dB.
- Formal V23 project comparison: 2 cases x 10 SNRs (-30 through -21 dB) x
  1000 paired packets = 20,000 received frames; 100 method/condition rows.
- Per formal cell/method: 112,000 data symbols and 768,000 information bits.
- Formal 95% intervals use 2000 resamples of the 1000 paired packets per cell.
- Known-midamble adaptation: 7 methods x 20 cells = 140 summary rows; each
  of the 20,000 frames was checked against its frozen V23 IQ fingerprint.
- Ten-point project correction: 8 rows from 2 cases x 4 processing branches;
  all 2000 regenerated IQ fingerprints match the frozen V23 frame records.
- Refined LR: 18 development/validation/full rows plus 6 independent-holdout
  rows; the three receivers process the same IQ in each case and use no
  payload truth, orbit truth, or extra midamble updates.
- Paired BER report: 18 augmented screening rows and 6 augmented fresh-
  holdout rows; the original receiver outcomes are unchanged.
- Robust replay V3: 60 summary rows from 20 cells and three methods. Case 2
  uses 45, 431, and 913 replay packets at -23, -22, and -21 dB; all remaining
  packets use the preamble-observable no-midamble safety branch.

## Automated audit artifacts

- `results/audit/reproduction_audit.json`: PASS, 17 tests, 5 old and 5
  ten-point Table-IV rows, 10 full-PHY rows, 100 V23 project rows, 140
  known-midamble adaptation rows, 8 ten-point project rows, 18 refined
  screen rows, 6 fresh-holdout rows, and 6 paired-BER holdout rows.
  It also verifies 60 robust-replay rows, 20 complete cells, and the
  900-packet-per-cell holdout performance gate against Midamble V6.
- `results/audit/source_manifest.csv`: SHA-256 manifest for the MATLAB files.
- The audit deliberately records `standardCrcPlrMatchesPaper=false`; scope and
  integrity pass, but published PLR is not numerically reproduced by standard
  CRC semantics.

## Interpretation boundary

The full-PHY path implements whitening, Hamming coding, zero padding,
interleaving, Gray coding, and CRC. Payload size, exact whitening state,
padding, and the paper's coded-BER/CRC denominator are not completely stated
in the six-page paper, so those choices are frozen assumptions rather than
claimed author-source values. Standard CRC PLR is reported even where it
disagrees strongly with the published PLR.

The formal project comparison uses the current V4 SF12, 125 kHz, no-LDRO,
CR3, 112-payload-symbol, 768-information-bit AWGN frame and the existing
paired case-anchor generator. Midamble rows remain in the shared physical
timeline; the Dietl receivers ignore their values but use the true elapsed
row positions when fitting the linear model. The plot uses a 0.5/count
display floor for zero observed errors on its logarithmic axes; the CSV and
MAT retain the exact zero counts and rates.

The known-midamble adaptation uses existing common-frame overhead. Its
improvement must not be presented as the original paper's no-extra-overhead
receiver performance. The paper's exact even-window placement is unpublished;
the corrected project port uses ten total FFT samples with offsets -4:5.
The earlier 3000-overpass full-PHY artifact still uses the historical
21-point interpretation and must be identified as such.
