# User-authorized standard soft PHY branch

Ordinary fixed/causal rolling LS and its Hann/4x/ten-point centroid and hard
feedback remain frozen v6. No soft/CRC result, replay, robust fit, midamble,
Gold payload or orbit truth updates the receiver.

After its causal prediction, the standard soft option applies constant-per-
symbol frequency correction, an N-point FFT, reference signal/noise estimation,
FFT-energy-by-N normalization, max-log log-I0 bit likelihoods, Gray /4 mapping,
diagonal deinterleaving and the 16-codeword ML Hamming decoder. Header,
dewhitening and CRC rules match v6. Reference commit:
`31243b0ac9cc8255f860dc85fc9594734856e03e`, GPL-3.0; URLs in
`reference_manifest.json`. The reference defaults to hard decoding; the user
authorized soft testing. Author settings and source identity remain unconfirmed.

Two fixed front ends are separate: `reference-rectangular` control and
`paper-hann` (runner default, identical frozen periodic Hann). Its N FFT at
integer candidates equals the fourfold-padded FFT subset, verified by test.
Neither changes likelihood/ML rules or selects a window/codec per packet.

## Metrics, pairing and provenance

Primary BER retains the identical LR-hard pre-Hamming coded bits, with each
codec's independently decided CRC-success mask. LLR-sign BER is separate.
Zero accepted bits means NaN. Counter denominators exclude padded codewords.
Gold enters scoring only after both receive paths finish, never LR or CRC.

Full-position hard counters must reproduce the parent per position and per
pass. Finite position samples do not claim full-grid/formal acceptance. Four
exclusive paired acceptance cases reconcile PLR differences. Results bind
parent/target MAT bytes, frozen dependencies, all new sources and oracle data.
Old v5/v6/forensics sources and all old cache signatures are unchanged.

## Commands

```matlab
addpath('D:/codex/Doppler_Resistant_Enhancement_for_Energy_Efficient_Device-to-Satellite_LoRa_Communications/paper_conditions_strict/reference_soft_phy')
setupReferenceSoftPhy
tests=run(testsuite('testReferenceSoftPhy.m')); assert(all([tests.Passed]))
input='D:/codex/Doppler_Resistant_Enhancement_for_Energy_Efficient_Device-to-Satellite_LoRa_Communications/paper_conditions_strict/reference_phy_v6/results/reference_phy_v6_O8_Pall_S0_-5_-10_-15_-20_product_0204768bc498/reference_phy.mat';
full=run_reference_soft_phy(input);
control=run_reference_soft_phy(input,SoftWindow='reference-rectangular');
audit_reference_soft_phy(string({full.outputDirectory;control.outputDirectory}))
```

## Current validated results

14 new tests pass: 418 literal ML vectors, 12 independently computed spectra,
causality, Gold isolation, parser equivalence, zero-signal/invalid input guards,
both windows, N/4N integer-grid equivalence and closed-form normalization tests.
Ten frozen-v6 tests also passed. Full eight-pass paired runs each use the same
11,600 physical packets. Every hard counter and paired reconciliation passes.
The combined audit's 23,200 run-count packets are two same-corpus executions,
not twice the independent sample size.

Corrected Hann meets 27/40 entries (Adaptive 19/20, Fixed 8/20); rectangular
control meets 23/40. CR1/-20 dB Adaptive PLR is 11.5327%, a 3.5727-point gap;
CR4/-15 dB PLR is 5.5328%, a 5.3328-point gap and still failing.
Acceptance remains per-entry absolute difference <=5 percentage points.
No new 3000-pass formal result or complete numerical success is claimed.

Current directories: `results/paired_soft_825c3db77dfc` (rectangular) and
`results/paired_soft_9e64048d168e` (Hann). See [SOFT_PHY_RESULTS.md](SOFT_PHY_RESULTS.md)
and `results/soft_phy_comparison.png` for the corrected comparison.

## Independent audit gate

Initial audit FAIL identified missing FFT energy multiplication by N, also
missing in the old oracle. Fixed exactly at the pinned reference stage: raw
Ps/Pn first, then N scaling for Bessel/clipping/fallback. Fixtures were regenerated
and an independent sqrt(35)/sqrt(7), 128*999 regression added. Fresh runs use
new signatures, without relabeling any cache. Earlier soft results are invalid
and retained only as history. Focused re-audit PASS, no actionable findings;
tests were not independently rerun. Corrected full-run integrity was subsequently
verified by the primary process. See [AUDIT_LOG.md](AUDIT_LOG.md).
