# Progress: Single-Symbol Dynamic Doppler Channel

## 2026-07-29

- Figure 3 orbit model previously passed 9/9 MATLAB tests.
- User approved the dependency strategy and full channel design.
- Design specification saved under `docs/superpowers/specs`.
- Implementation plan saved under `docs/superpowers/plans`.
- No production channel code or channel tests have been written yet.
- Captured SHA-256 hashes for both original CSS functions before edits.
- TDD RED observed: 0/7 tests passed; failures were undefined-function
  errors for the three planned production functions.
- Added `lora_symbol_instantaneous_frequency.m`.
- Frequency checkpoint: 1/7 tests passed; remaining failures were caused
  by the still-missing channel and detector wrapper.
- Added `apply_lora_dynamic_doppler.m`.
- Channel checkpoint: 6/7 tests passed; the only remaining failure was
  the missing detector wrapper.
- Added `lora_css_demodulate_dynamic_channel.m`.
- New channel suite GREEN: 7/7 tests passed in MATLAB R2022a.
- Full regression GREEN: 16/16 tests passed (9 orbit/Figure 3 and
  7 single-symbol dynamic-channel tests).
- MATLAB Code Analyzer reported 0 messages across the four new channel
  implementation/test files.
- Recomputed both original CSS file hashes; they exactly match the
  pre-implementation baselines.
- Requirement scan confirmed that Doppler compensation and artificial
  FFT-bin shifting are absent; matched terms occur only in comments and
  the explicit no-compensation test name.
