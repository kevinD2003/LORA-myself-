# V4 expedited AWGN scope amendment v2 — P10

> 目录整理（2026-10-08）：[所属项目入口](../../README.md)。本文的 MATLAB 命令和反引号内的代码、数据及文档路径以该项目根目录为基准；历史数值和验收结论保留其原记录时间。

Effective date: 2026-09-13.

Plan identity: `V4-noLDRO-plan-R3-project-aligned-expedited-AWGN-v2-P10`.

This supersedes the v1 five-pass expedited reporting budget before v1 completion. To avoid excessively low complete-pass cluster precision while retaining a next-morning target, the fixed revised budget is ten complete passes per AWGN mode/SNR.

- AWGN controlled-time: 10 complete passes per SNR at -30:-21 dB.
- AWGN native-overhead: 10 complete passes per SNR at -30:-21 dB.
- Included identifiers are deterministically pass 1 through pass 10.
- Rician groups remain `NOT_APPLICABLE` by explicit user scope amendment.
- Bootstrap remains 10000 paired complete-pass resamples per mode/SNR.

All PHY, orbit, channel definition, SNR values, timing, coding, receiver implementations, seeds, pass identifiers and metric denominators remain unchanged. Existing completed passes are reused by exact signature; no pass is regenerated or selected by performance.

Ten clusters remain below the parent 50-pass budget. Precision limitations and CI crossings must be reported. This amendment is not completion of the parent R3 formal budget.
