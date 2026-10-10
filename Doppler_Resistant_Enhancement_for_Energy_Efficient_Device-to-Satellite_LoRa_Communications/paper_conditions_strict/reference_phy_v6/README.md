# Reference PHY v6 correction

This version corrects verifiable differences between the v5 packed PHY and
the paper's cited gr-lora_sdr implementation, pinned at commit
`31243b0ac9cc8255f860dc85fc9594734856e03e`. It is not the paper author's
simulation source and does not claim complete numerical agreement.

## What changed

- Byte whitening uses the reference 255-period, eight-bit sequence, on
  payload bytes only. CRC/header/codeword padding are not whitened.
- CRC uses the reference CRC-16/0x1021 over the first N-2 payload bytes,
  XOR the final two bytes, then appends four unwhitened low-first nibbles.
- Payload nibbles are low-first within a byte. Hamming bit ordering,
  interleaving permutation and hard CR1/CR4 correction follow the reference.
- The first block uses CR4 and SF-2; LDRO auto is active when Ts > 16 ms.
  Reduced-rate interleaver parity/zero bits and the physical Gray +1 shift
  are implemented, with the inverse -1/divide-by-four operation on receive.
- Padding is applied to encoded codewords after Hamming, not inserted into
  the whitened data stream. Only actual Hamming-encoded words enter BER.
- The explicit five-nibble header/checksum is processed independently on
  receive. There is no transmitted-data argument in the decoder.
- Physical time includes eight pilots, two sync upchirps and 2.25 SFD
  downchirp symbols. Perfect synchronization is assumed; downchirp samples
  are not fed into the upchirp LR observations. Sync upchirps are hard-decided,
  not supplied as extra known pilots. Full-frame sample AWGN is generated.
- LR remains fixed/causal rolling ordinary least squares. Its time indices
  include the actual SFD gap. No robust fit, replay, midamble or payload truth.

## Frozen choices and limits

SF12, B=62600 Hz, fc=2.1 GHz, 400 km orbit, N=8, periodic Hann, 4x FFT,
ten magnitude-centroid samples (-4:5), 32-byte independently random payload,
explicit header, CRC present, automatic LDRO, sync word 0x12.
The radio driver's 40-symbol idle guard is hardware-specific and is omitted
from the back-to-back on-air cadence. No extra zero-valued LoRa symbol is added.
Resulting on-air lengths are 55.25/76.25 symbols for CR1/CR4, with 168/122
complete packets per pass. These differ from the v5 packet durations.

The main phase remains literal Eq. (15). An analytic instantaneous-Doppler
integral is a separately labeled diagnostic. Neither phase is selected by
closeness to published target values. Eq. (14)'s small baseband-frequency
term is still omitted. The author N/frame/decoder configuration is unconfirmed.

The complete v5 sources, 3000-pass data and signatures remain unchanged.
Every v6 result binds its own source/configuration plus the pinned shared
native IQ/FFT kernel. Source changes reject caches; signatures are not migrated.

## Validation

An independent Python fixture generator uses literal reference whitening and
Hamming tables, Python's standard CRC implementation, header parity masks,
and the inverse interleaver permutation. Its 64 frame combinations and
288 hard-decoder entries agree with MATLAB. Ten tests also cover noiseless
round trips, codeword correction, full-frame AWGN, seed independence,
causal time-aware OLS, Gold-data isolation, corrupt-header loss, v5 integrity
and rejection of an audit call without result directories.

```matlab
addpath('D:/codex/Doppler_Resistant_Enhancement_for_Energy_Efficient_Device-to-Satellite_LoRa_Communications/paper_conditions_strict/reference_phy_v6')
setupReferencePhyV6
tests=run(testsuite('testReferencePhyV6.m')); assert(all([tests.Passed]))
run_reference_phy_v6(Overpasses=8)
run_reference_phy_v6(Overpasses=8,PhaseModel='integrated-instantaneous-doppler')
```

The two complete -10 dB validation ensembles contain 4,640 received packets.
Method 1 is Adaptive LR; method 2 is Fixed LR. Primary BER is pre-Hamming
coded BER on CRC-success packets; all-packet BER and header/packet loss
are reported separately. No accepted packets means NaN.

| Phase / CR | Adaptive BER % | Adaptive PLR % | Fixed BER % | Fixed PLR % |
| --- | ---: | ---: | ---: | ---: |
| Product / CR1 | 0.000765 | 1.4881 | 0.001867 | 29.3899 |
| Product / CR4 | 0.002140 | 1.6393 | 0.027330 | 37.0902 |
| Integrated / CR1 | 0 | 0 | 0.002755 | 31.6220 |
| Integrated / CR4 | 0 | 0 | 0.036205 | 40.8811 |

These are eight-pass validation results, not 3000-pass formal results.
Reference-PHY corrections do not yet recover Tables V/VI. Do not equate
lower conditional BER, altered packet duration or a separately interpreted
phase model with numerical reproduction success. Full comparisons retain
`numericalAgreementClaimed=false`.

## User acceptance: 5 percentage points

The user specified absolute differences of at most 5 percentage points for
each published SER, coded BER and PLR entry, not 5% relative error.
The frozen product-phase eight-pass validation now covers all five SNRs,
both CRs and 11,600 physical packets. Ten tests and result/source/counter
checks pass. Of 40 BER/PLR comparisons, 26 meet the threshold and 14 do not;
Adaptive LR meets 18/20, with remaining PLR gaps of 6.6233 points at
CR1/-20 dB and 6.0500 points at CR4/-15 dB. Fixed LR meets 8/20.
This is not a new formal 3000-pass experiment. No calculation source changed.
Full details and scope are in [../ACCEPTANCE_5PP.md](../ACCEPTANCE_5PP.md).

Latest all-SNR validation directory:

`results/reference_phy_v6_O8_Pall_S0_-5_-10_-15_-20_product_0204768bc498`

The SNR task list contributes to RNG cell indices; its -10 dB results are
not paired reruns of the earlier single-SNR ensembles. Do not select the
closer sample or the alternate phase as a replacement for the main result.

## Reference provenance

`reference_manifest.json` pins reference source URLs and commit. Algorithms
and fixtures are derived from gr-lora_sdr, GPL-3.0 (repository LICENSE).
No GNU Radio scheduler is implemented; this is a MATLAB model of the
reference packet transforms with an ideal frame synchronizer.

## Independent audit gate repair

The first independent code audit found one confirmed defect: a no-argument
audit call could report an implementation validation status while checking
no results. The function now requires at least one completed result directory;
a tenth regression test checks rejection of the empty invocation. Rerunning
the two complete eight-pass ensembles uses new source-signature-suffixed
directories; older v6 caches are historical and were not relabeled or migrated.
Their scalar metrics remain identical. Independent audit status and any
confirmed repairs are recorded in CHANGELOG.md.

Earlier independently checked -10 dB result directories:

- `results/reference_phy_v6_O8_Pall_S-10_product_1d5b97d81423`
- `results/reference_phy_v6_O8_Pall_S-10_integrated_b11f25ab4ed4`

Pass these directories explicitly to `audit_reference_phy_v6`. A bare audit
call is intentionally rejected rather than implying result validation.
