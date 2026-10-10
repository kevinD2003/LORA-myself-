# Pure-paper direct-IQ reproduction

This directory implements the paper's fixed and causal rolling ordinary
least-squares LR, equations (18)-(22), at SF12, 62.6 kHz, 2.1 GHz and a
400 km circular orbit. Table IV uses M=51 and eight known preambles.
Both receivers consume the same observation. Hann windowing, 4x FFT
padding and a ten-sample magnitude centroid with offsets -4:5 are used.

The full PHY generates independent sample-level AWGN for each transmitted
packet in every overpass. Whitening, CR1/CR4 Hamming coding, interleaving,
Gray mapping and CRC are executed. CRC-success coded BER is the primary
metric required by the paper's text. All-packet coded BER and PLR are
reported alongside it. No accepted packets means BER is undefined (NaN).
Payload bits are independently drawn for each packet/overpass; both
receivers use the same generated packet and sample-level noise observation.

No project receiver, Stage55 branch, midamble, robust regression,
code-aided replay or truth-assisted decision is used here.

## Isolated reference-PHY correction

The calculation sources and completed 3000-pass results described below are
the preserved v5 baseline. The separately implemented
[reference_phy_v6](reference_phy_v6/README.md) corrects packet transforms and
sync/SFD timing against a pinned gr-lora_sdr reference without augmenting LR.
Its ten-test, eight-pass validations include the latest 11,600-packet full
SNR grid, not a formal 3000-pass experiment. Numerical agreement with the
publication remains unestablished.
See its README and CHANGELOG for current source-bound results and audit status.

The user-defined numerical acceptance criterion is now an absolute difference
of at most 5 percentage points for each published SER, coded BER and PLR
entry, including zero targets. This is not 5% relative error. See
[ACCEPTANCE_5PP.md](ACCEPTANCE_5PP.md) for the precise denominator, current
pass/fail counts and separation of validation from formal reproduction.

The user-authorized [standard soft PHY branch](reference_soft_phy/README.md)
keeps LR, hard feedback, primary LR-hard coded bits and CRC rules unchanged.
After repairing an independently confirmed FFT-energy normalization omission,
14 tests and the focused read-only re-audit pass. Both fresh full paired runs
match all frozen hard counters. Corrected Hann meets 27/40 entries (Adaptive
19/20, Fixed 8/20); CR1/-20 dB PLR is 11.5327%, while CR4/-15 dB still fails
with a 5.3328-point gap. This separate author-unconfirmed eight-pass profile
is not a new formal run or complete tolerance success. See
[corrected paired results](reference_soft_phy/SOFT_PHY_RESULTS.md).

## Commands

```matlab
addpath('D:/codex/Doppler_Resistant_Enhancement_for_Energy_Efficient_Device-to-Satellite_LoRa_Communications/paper_conditions_strict')
strictPaperSetup
% Run once after editing the native source; requires an MSVC C++ compiler.
compile_strict_native
tests = run(testsuite('testStrictPaperReproduction.m'));
assert(all([tests.Passed]))
run_strict_table_iv
run_strict_table_iv(Overpasses=32, MaximumPacketsPerCall=100)
% Repeat a CHECKPOINTED call with identical statistical options.
run_strict_full_phy(Overpasses=8, MaximumPackets=12)
run_strict_full_phy(Overpasses=8, SnrDb=-10)
audit_strict_phase_sensitivity
audit_strict_numerical_gaps
run_strict_full_phy % 3000 passes, both CRs, all five SNRs and all positions
audit_strict_paper_reproduction % requires the complete formal ensemble
```

`MaximumBatchesPerCall` bounds a MATLAB process; statistical options and
source hashes must remain identical when resuming. Disjoint
`ConditionIndices` schedule independent cells in the full grid. A
worker returning WORKER_COMPLETE does not mean the full ensemble is
complete: the default runner must aggregate all ten cells.

`invoke_strict_batches.ps1` runs bounded processes and resumes saved
checkpoints. Each cell saves every ten batches, independently of other
cells. A batch contains at most 32 overpasses. The active results use
`table_iv_v5_...` and `full_phy_v5_...`. Earlier v2-v4 directories are
historical validation/engineering iterations and are not formal results.

## Numerical audit

The original single overpass is reproduced exactly in decision/error counts
after acceleration. Its Adaptive SER at 0, -5, -10, -15 and -20 dB is
0, 0, 1.2778, 4.8812 and 8.5995 percent. The published values are
0, 0, 1.11, 4.82 and 13.44 percent.

Thirty-two independent overpasses give Adaptive SER means of 0, 0.021962,
0.79742, 3.98791 and 9.74000 percent. At -20 dB the empirical individual-pass
95% range is 7.8968 to 11.8624 percent: this diagnostic does not support
attributing the entire discrepancy to the original random seed. Fixed LR also has persistent
high-SNR differences. Full comparisons and uncertainty intervals are in
`results/numerical_gap_audit/table_iv_uncertainty.csv`.

At -10 dB, eight complete validation overpasses give Fixed CR4 all-packet
coded BER of 3.4632 percent, close to the paper's 3.47 percent, but
CRC-success BER is 0.0963 percent and PLR is 34.8926 percent, versus the
paper's 0 percent PLR. The two BER denominators cannot be silently exchanged.
Phase/sign sensitivities do not simultaneously recover all paper values.
These differences are reported; no model, parameter or metric is fitted to
force numerical agreement. The formal 3000-pass ensemble completed on
2026-10-09 at 10:10 Asia/Shanghai: all ten conditions and 6,030,000 received
packets. The required audit passed all nine tests, source/signature checks,
per-position/per-overpass reconciliation and MAT/CSV comparisons. Its status
is FORMAL_COMPLETE_WITH_NUMERICAL_GAPS, not numerical reproduction success.

At -10 dB, formal Fixed CR4 CRC-success coded BER is 0.092520% and PLR is
34.346421%; all-packet coded BER is 3.477140%. The paper reports 3.47% BER
and 0% PLR. Adaptive CR4 CRC-success BER is 0.003100% and PLR is 1.752352%,
versus published 0.31% and 0.12%. The independent code audit remains
INCONCLUSIVE (no actionable code findings); it must not be relabeled PASS.
See FINAL_RESULTS.md and results/full_phy_v5_O3000_Pall_S0_-5_-10_-15_-20/
formal_comparison.csv for the completed comparison and uncertainty intervals.

## Acceleration and provenance

The compiled kernel generates each IQ sample from the transmitted waveform
and the sample-level MT19937 noise supplied by MATLAB, then runs Hann,
dechirping, a double-precision FFT and the ten-point centroid. The payload
labels are used to generate the transmitter waveform, not to supply decoded
symbols. Nine tests include sample/centroid/decision equivalence with the
reference MATLAB path and PHY/CRC equivalence. The standalone FFTW library
is pinned by SHA-256 together with its C++ source, MEX binary and build record.
The FFT plans are kept alive for the process lifetime to avoid R2022a
foreign-library shutdown races; the operating system releases them.

Source and configuration hashes must match exactly. Cache signatures are
never migrated. Per-position and per-overpass raw counts are both retained
and must reconcile in the audit. Formal completion requires 3000 passes at
239 CR1 and 163 CR4 positions for each of five SNRs: 6,030,000 received
packets, each scored by both receivers.

## Explicit limits

The author source, N, Hann convention, even centroid placement, payload
size, whitening state, and packet header/padding details are unpublished.
The frozen choices are N=8, periodic Hann, offsets -4:5, a 32-byte payload,
six coding blocks, 16 padding bits and one trailing padding symbol.
The full PHY therefore has 39/57 symbols for CR1/CR4; M=51 refers to Table IV.
In the frozen packed bitstream, CRC is appended to the payload, followed by
the zero data-padding bits; whitening and Hamming coding cover that entire
bitstream. The separate trailing padding symbol is zero. This describes
the actual simulation convention, not a verified author on-air frame layout.

The main simulation reproduces the product phase in Eq. (15) literally.
Physically integrating instantaneous Doppler and reversing the sign are
separate diagnostic calculations. The small baseband-frequency term of
Eq. (14) is omitted. FFT-bin unwrapping and quantization are cyclic.
These assumptions must accompany any interpretation of numerical gaps.

The product phase uses the orbit time axis, with t=0 at closest approach.
Its instantaneous frequency is f_D(t)+t*f_D'(t), not f_D(t). The paper's
printed Eq. (15) and an integrated instantaneous-Doppler channel therefore
are not interchangeable. The existing phase sensitivity results do not
recover all Table IV targets under either interpretation; no phase model
was chosen by target closeness. The manuscript alone does not establish
the author's implementation/time-origin convention.

`results/audit.json` distinguishes implementation integrity, formal
experiment completion and numerical agreement. Completing 3000 overpasses
does not establish author-source identity or agreement with every target.
