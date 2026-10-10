# Frozen-v6 packet-loss forensics

This independent diagnostic does not modify v5/v6 calculation sources or
receiver decisions. It regenerates the exact payload and sample AWGN for
selected saved v6 conditions, runs the unchanged LR and hard PHY, then uses
Gold data only to classify already completed receive outcomes.

Default conditions are source indices 5, 8 and 9 of the five-SNR v6 grid:
CR1/-20 dB, CR4/-10 dB and CR4/-15 dB. This covers both remaining Adaptive
PLR misses and the large Fixed CR4 loss at -10 dB. It is not a new PHY,
a 3000-pass experiment, or numerical reproduction success.

The runner requires exact current parent source/configuration signatures.
Every selected condition must reproduce all six scoring counter matrices,
both per position and per overpass, before any report is saved. Result
identity also binds the input MAT bytes, selected indices and diagnostic
sources. Hamming word histograms exclude padding; header rejection and
valid-header CRC rejection partition packet loss. Other error categories
can overlap and must not be summed as exclusive causes.

```matlab
addpath('D:/codex/Doppler_Resistant_Enhancement_for_Energy_Efficient_Device-to-Satellite_LoRa_Communications/paper_conditions_strict/loss_forensics')
tests=run(testsuite('testLossForensicsV6.m')); assert(all([tests.Passed]))
run_loss_forensics_v6('D:/codex/Doppler_Resistant_Enhancement_for_Energy_Efficient_Device-to-Satellite_LoRa_Communications/paper_conditions_strict/reference_phy_v6/results/reference_phy_v6_O8_Pall_S0_-5_-10_-15_-20_product_0204768bc498/reference_phy.mat')
```

No CRC feedback, replay, payload/orbit truth, robust fit or midamble enters
the receiver. Word multiplicity explains hard-code correction limits but
does not itself prove the author's decoder configuration or a code defect.
The pinned reference uses integer truncation for LDRO /4 and defaults to
hard decoding. Neither is replaced simply to make PLR approach a target.

## Verified diagnostic run

Five new tests and the ten unchanged v6 tests passed. A 3,296-packet run
matched every selected per-position and per-overpass scoring counter exactly.
Results: `results/loss_forensics_cd2d111f8129/loss_forensics.mat` and `.json`.
Method 1 is Adaptive LR; method 2 is Fixed LR.

| CR / SNR | Method | Packets | Header rejected | Valid-header CRC rejected | Rejected with a >=2-bit-error word |
| --- | --- | ---: | ---: | ---: | ---: |
| CR1 / -20 dB | Adaptive | 1344 | 82 | 114 | 152 |
| CR1 / -20 dB | Fixed | 1344 | 93 | 561 | 563 |
| CR4 / -10 dB | Adaptive | 976 | 2 | 17 | 19 |
| CR4 / -10 dB | Fixed | 976 | 9 | 329 | 338 |
| CR4 / -15 dB | Adaptive | 976 | 2 | 59 | 61 |
| CR4 / -15 dB | Fixed | 976 | 2 | 402 | 404 |

Header and valid-header CRC losses are disjoint. The word-error column
overlaps them; it is not a third additive loss category. CR4 losses all
include a multi-bit-error word, but not every multi-bit-error word causes
a packet loss. CR1 has no hard systematic-bit correction, so 44 Adaptive
losses occur with no more than one error per word. No rejected packet had
all decoded nibbles equal to the transmitted header/payload/CRC nibbles.

One CRC-accepted Fixed CR4/-10 dB packet nevertheless had a wrong payload.
It remains accepted by the unchanged receiver and is only flagged post hoc;
there is no Gold-based override. This is an undetected error, not proof of
an invalid CRC implementation. The diagnostics do not establish why the
author's PLR differs or confirm a different hard/soft setting.

Reference source checks (same pinned commit as v6):

- [Hard demodulation /4 and soft option](https://github.com/tapparelj/gr-lora_sdr/blob/31243b0ac9cc8255f860dc85fc9594734856e03e/lib/fft_demod_impl.cc).
- [Hard/soft Hamming decoder](https://github.com/tapparelj/gr-lora_sdr/blob/31243b0ac9cc8255f860dc85fc9594734856e03e/lib/hamming_dec_impl.cc).
- [Receiver default soft_decoding=False](https://github.com/tapparelj/gr-lora_sdr/blob/31243b0ac9cc8255f860dc85fc9594734856e03e/python/lora_sdr/lora_sdr_lora_rx.py).

Independent read-only code audit: PASS; no actionable findings. The reviewer
checked counter reconciliation, post-receiver Gold isolation, padding,
loss partitions, invalid selection rejection and saved source/input hashes.
The five new and ten v6 tests were run by the primary process, not rerun by
the read-only reviewer. Numerical gaps remain subject to the per-entry
five-percentage-point acceptance rule; this run does not improve or replace
any v6 BER/PLR result.

Next configuration choice: whether to test the cited implementation's
standard soft Hamming option in a separate branch. The paper does not
confirm that setting. Any such test must retain ordinary LR, the hard
baseline, independent CRC decisions and an explicitly unconfirmed-profile
label; it must not be presented as an established author-source correction.
