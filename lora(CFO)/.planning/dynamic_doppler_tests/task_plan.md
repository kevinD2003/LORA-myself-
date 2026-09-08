# Task Plan: Dynamic Doppler Channel Acceptance Tests

## Goal

Add the approved non-BER dynamic Doppler tests, implement the minimal
`no_doppler` mode, run MATLAB, and save the fresh transcript.

## Phases

| Phase | Status |
|---|---|
| Approved design and implementation plan | complete |
| TDD RED for `no_doppler` | complete |
| Minimal `no_doppler` implementation | complete |
| Remaining deterministic acceptance tests | complete |
| Full MATLAB regression and analyzer | complete |
| Results transcript and hash verification | complete |

## Constraints

- Target: `D:\codex\lora(CFO)`
- No BER sweep
- Do not modify original AWGN functions
- Full-RF remains the default
- Explicit numeric tolerances for all comparisons

## Errors Encountered

| Error | Attempt | Resolution |
|---|---:|---|
| `rg.exe` access denied while listing the target | 1 | Used literal-path PowerShell reads |
| `pdftotext` unavailable | 1 | Used bundled Python `pdfplumber` |
| Initial PDF extraction hit GBK encoding error | 1 | Reconfigured Python stdout to UTF-8 |
| MATLAB `runtests` shadowed by BELLHOP script | 1 | Confirmed with `which -all`; used `matlab.unittest.TestSuite.fromFile` |
| Invalid-mode message became a 1-by-2 string array | 1 | Concatenated it into one string scalar for MATLAB R2022a |
| Helper ending in `_for_test` was collected as a test | 1 | Renamed helper to avoid `functiontests` discovery convention |
| MCP command capture left MATLAB diary empty | 1 | Wrote results directly with MATLAB `fopen`/`fprintf` |
| Result writer closed the same file twice | 1 | Removed duplicate `onCleanup` close and reran cleanly |
