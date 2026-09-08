# Stage 3R Experiment A redesign audit

Overall: `FAIL`. Admission: `DO_NOT_ADMIT_STAGE_4`.

## Evidence

- R4 freeze: PASS.
- New/inherited mechanism and causality tests: 16/16 PASS.
- Calibration v1: FAIL; 32 candidates, 500 packets per Case, artifact `f66c19a0d591b6b2f60af03666b71cc15b34011e530ff34dd4e9bfbc051b6f88`.
- Calibration v2: FAIL; 32 candidates, 500 packets per Case, artifact `646ad1001c8378c07aa841bd7cb829f0515da679430815ef47488e7084b87ae2`.
- Source/read-only boundary: PASS. R3 failure evidence: PASS.

Across the two rounds, 2000 physical packets and 64000 candidate-packet receiver evaluations were completed. No candidate passed both Cases. Case 0 false-acceptance ranged from 92.56% to 96.17% in v1 and 93.07% to 98.96% in v2.

## Gate decision

Validation: `BLOCKED`; low-SNR safety: `NOT_APPLICABLE`; smoke: `BLOCKED`; formal: `NOT_APPLICABLE`; Experiment B: `BLOCKED_REQUIRE_A_PASS`.

The adverse result is retained. No threshold, denominator, candidate table, sample count, or round budget was relaxed.

