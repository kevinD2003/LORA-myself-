# Progress: Dynamic Doppler Channel Acceptance Tests

## 2026-07-30

- Reviewed the existing orbit and dynamic-channel implementation.
- Read the paper sections defining single/shared visibility and Doppler.
- Confirmed the approved distinction between device-A and shared-window
  Figure 17 endpoints.
- Wrote and self-reviewed the design specification.
- User approved the written specification and requested implementation.
- Created the detailed implementation plan; no production or test code
  has been changed in this phase yet.
- Added the explicit `no_doppler` contract test before production code.
- The generic test runner was shadowed by a BELLHOP `runtests.m`; path
  resolution confirmed the environmental cause.
- TDD RED was observed through `TestSuite.fromFile`: 7 passed, 1 failed
  and incomplete. The new test failed with the expected
  `lora:InvalidDopplerMode`.
- Added the minimal `no_doppler` implementation. The first GREEN run
  passed the new contract but exposed a 1-by-2 error-message string in
  the pre-existing invalid-mode test; corrected the message to one
  scalar without changing behavior.
- Focused GREEN then passed 8/8.
- Added the remaining deterministic acceptance cases. Initial discovery
  treated a helper ending in `_for_test` as a test function; renamed the
  helper without changing its calculation.
- The expanded focused suite passed 15/15.
- The full orbit and dynamic-channel regression passed 24/24.
- Code Analyzer reported zero messages for all eight relevant MATLAB
  files.
- MATLAB diary was empty under the connector's captured-output
  execution. Replaced it with direct MATLAB text output; removed a
  duplicate file-close warning and reran cleanly.
- Generated the 4232-byte results transcript with explicit
  `BER_SWEEP_RUN=false`.
- Recomputed both original AWGN file hashes; both are unchanged.
