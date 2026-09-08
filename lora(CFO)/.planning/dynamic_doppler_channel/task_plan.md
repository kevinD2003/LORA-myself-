# Task Plan: Single-Symbol Dynamic Doppler Channel

## Goal

Implement and verify the approved single-symbol dynamic Doppler channel
without modifying the original LoRa modulator or demodulator.

## Phases

| Phase | Status |
|---|---|
| Approved design and implementation plan | complete |
| TDD RED: create tests and observe expected failures | complete |
| GREEN: implement instantaneous frequency | complete |
| GREEN: implement channel and AWGN | complete |
| GREEN: implement no-compensation detector wrapper | complete |
| Full MATLAB regression, analyzer, and hash verification | complete |

## Constraints

- Target directory: `D:\codex\lora(CFO)`
- Baseline directory: `D:\codex\Lora(theory)` (read-only)
- MATLAB R2022a
- Full-RF mode is default
- Trapezoidal phase integration
- No Doppler compensation or FFT-bin shifting

## Errors Encountered

| Error | Attempt | Resolution |
|---|---:|---|
| Design document parent directory did not exist | 1 | Verified missing path, created exact directory, reapplied patch |
