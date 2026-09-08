# Stage 03 - Experiment A implementation, calibration, validation and smoke audit

Overall: `FAIL`. Admission: `DO_NOT_ADMIT_STAGE_4`.

## Identity and executed evidence

- Plan: `V4-noLDRO-plan-R3-project-aligned`.
- MATLAB: R2022a.
- Source manifest SHA-256: `86b725a1922c2976cc8ac7dc4b9ee5ed8e76677d7121319135f0e0d15af1a032`.
- Active code/config/scripts/tests aggregate SHA-256: `27893d220419f269dec980a0c76ef4e1249d9284a6844e5105930547c67bcb4c`.
- Executed: `runV4TrackAMechanismTests`, three bounded calibration rounds, and independent validation v1/v3.
- Mechanism tests passed for 41.25T/23D/8M timing, integer signed-bin Point, no sub-bin call, no Hamming call, terminal-M causality, no-Doppler zero-error, later-only VP application and deterministic packet pairing.

## Calibration and validation ledger

| Version | Calibration | Independent validation | Result |
|---|---|---|---|
| A-param-v01 | PASS; 32 candidates, mechanism-only selection | `a_validation_v1`, 2000 packets per Case | FAIL |
| A-param-v02 | FAIL; no candidate met both quality gates | Not run | NOT_APPLICABLE |
| A-param-v03 | PASS; candidate 26, 32 candidates | `a_validation_v3`, 2000 packets per Case | FAIL |

V1 raw validation recount:

- Case -366 s: 43375 accepted, 2610 false, false-acceptance 0.060173, coverage 0.942935.
- Case 0 s: 42159 accepted, 6213 false, false-acceptance 0.147371, coverage 0.916500.

V3 raw validation recount:

- Case -366 s: 3820 accepted, 175 false, false-acceptance 0.045812, coverage 0.083043.
- Case 0 s: 2098 accepted, 1965 false, false-acceptance 0.936606, coverage 0.045609.

All counts reproduce the JSON ratios by `falseAccepted/accepted` and `accepted/(2000*23)`. Both versions exceed the fixed 2% false-acceptance limit. V3 low-SNR safety remained finite, but that cannot override the -21 dB quality failure.

The first round-2 run raised the correct failure before persisting its failure artifact. The writer was fixed and the identical deterministic round-2 domain was rerun solely to capture the missing evidence; it failed identically. No candidate, seed, result scope, tolerance or gate changed.

## Status and decision

- Source/read-only boundary: `PASS`.
- Track A deterministic mechanisms: `PASS`.
- Calibration/validation quality gate: `FAIL` after the maximum three rounds.
- Track A smoke: `BLOCKED` by validation.
- Track A formal: `NOT_APPLICABLE`; not started.
- Experiment B: `BLOCKED` by the required Experiment A closeout sequence.

The failure is preserved as an adverse mechanism result. No tolerance was relaxed, no failed test was removed, and no SER/BER or method ordering was used for candidate selection. Per the registered rule, implementation stops here rather than tuning a fourth version or fabricating a PASS.
