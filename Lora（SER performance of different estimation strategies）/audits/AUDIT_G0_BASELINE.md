# AUDIT_G0_BASELINE

Status: **PASS_WITH_NOTES**  
Date: 2026-09-21  
Scope: read-only inspection before creating EXP1 code or results.

## Frozen parent

- Git root: `D:\codex`
- Parent directory: `D:\codex\Lora(eg)\comparison_experiments\stage55_sf12_sf11_flow_v4_noldro`
- Base HEAD: `4d509fd5c2c6e0656916c4a8dd82a7ff56686f39`
- Executed source identity: base HEAD plus the complete local dependency closure locked by `configs/parent_source_manifest.json`.
- Parent report: `results/method_aligned/unified_v23_report/report.json`
- Parent status: `PASS / ADMIT_V23_FREEZE`

Frozen receiver entries:

- Huang/PREC: `v4HuangPrecUnifiedDecodeV9`
- Stage55: `v4Stage55UnifiedDecodeV16`
- Paper Midamble-Point: `v4PaperMidamblePointUnifiedV6`
- Frame/orbit anchor: `v4GenerateBCaseAnchorFrame` + `v4TrackAOrbit`

The exact inspected file hashes are recorded in `configs/parent_source_manifest.json` and checked before every run. The validator also recomputes the `exp1RunCell` parent dependency closure and rejects any runtime parent `.m` file missing from the manifest. This explicitly includes the locally patched `v4RollingTrackerPass.m`; the project does not claim a clean-HEAD source tree.

## Evidence and decisions

1. **PHY and frame layout — PASS.** Parent config resolves to SF12, BW/Fs 125 kHz, no-LDRO, CR3, 768 information bits, 112 data symbols, 8 bootstrap symbols and 37 Paper midambles. `v4BuildFrameLayout` produces 157 physical symbol intervals.
2. **Orbit time and phase — PASS.** `v4GenerateBCaseAnchorFrame` defines its input as the first-sample orbit time and integrates samplewise Doppler by a trapezoidal phase recursion across the complete 157T frame. No symbol boundary phase reset occurs.
3. **Noise — PASS.** Unit-magnitude transmitted samples use fixed complex AWGN I/Q total variance `10^(-SNR/10)`, independent of orbit, method and received realization.
4. **Pairing and reset — PASS.** Parent results use keyed payload/noise/channel seeds per packet. A new frame and new receiver result are created per packet; no receiver history is carried between packets.
5. **Truth isolation — PASS.** The three ordinary entries declare and implement no payload/orbit-truth use. Truth is consumed only by offline scoring. Ideal is kept as a separate reference path.
6. **Paper configuration — PASS_WITH_NOTE.** V6 is one fixed entry for all positions. Its static/trend branch is selected from the received preamble by `v4Stage55ObservableModeSelectorV10`; it does not inspect Case identity, SNR or truth. This satisfies the prohibition on selecting a Paper endpoint configuration from official results. The implementation remains an adapted no-LDRO Paper receiver and is not a literal native-paper frame.
7. **Historical endpoint source — PASS.** Unified V23 merges Huang V9 packet results with Stage55 V16/Paper V6 results generated from the same deterministic parent frames. At -21 dB its archived endpoint SER values are: Case1 Huang/Stage55/Paper = `7.1429e-5 / 7.1429e-5 / 1.9554e-3`; Case2 = `0.9945 / 0.0163125 / 0.0434911`.
8. **VP-off feasibility — PASS.** The Stage55 dynamic path exposes a clean boundary: mode selection and joint-preamble initialization precede `v4Stage55Decode`; VP observations enter through `v4RollingTrackerPass`'s candidate mask. Supplying an all-false mask preserves initialization/prediction while eliminating payload updates.

## Notes that are not blockers

- The repository already contains a large unrelated dirty state, and `v4RollingTrackerPass.m` has a local patch relative to the base commit. EXP1 therefore identifies the parent as base commit plus a full locked dependency closure, lives in a new sibling directory, and never edits the parent.
- The parent endpoint report uses integer `-21 dB`. Smoke must reproduce that point. `-21.12 dB` is a new selected anchor and must not be described as an exact Fig.12 reproduction without a separate SNR-definition audit.
- The parent Track-A orbit uses the precise constant `c = 299792458 m/s` and a zenith circular-orbit geometry. EXP1 preserves this parent model rather than silently switching to the other `v4Trajectory` implementation.
- The parent initializes channel phase to zero per packet. EXP1 preserves this choice and records it; random phase is not introduced during the orbit-only comparison.

## Go/no-go

**GO.** No confirmed issue invalidates a five-position, common-waveform AWGN scan or the specified VP-off ablation, provided the frozen source hashes pass and `-21.12 dB` is described conservatively.
