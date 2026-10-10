# V4 expedited AWGN scope amendment v1

> 目录整理（2026-10-08）：[所属项目入口](../../README.md)。本文的 MATLAB 命令和反引号内的代码、数据及文档路径以该项目根目录为基准；历史数值和验收结论保留其原记录时间。

Effective date: 2026-09-13.

Parent plan: `V4-noLDRO-plan-R3-project-aligned`.

Revised execution identity: `V4-noLDRO-plan-R3-project-aligned-expedited-AWGN-v1`.

The user explicitly requested a reduced sample count and AWGN-only completion so results can be available the next morning. This amendment changes only the remaining Experiment B reporting budget and channel scope:

- AWGN controlled-time: 5 complete passes per SNR at -30:-21 dB.
- AWGN native-overhead: 5 complete passes per SNR at -30:-21 dB.
- Rician controlled-time and native-overhead: `NOT_APPLICABLE` under the revised user scope.
- Paired complete-pass bootstrap: 10000 draws per SNR, with only five clusters; wide or degenerate intervals must be reported as `precision-inconclusive`.

All PHY, orbit, SNR values, coding, timing, receivers, Stage55 v30 implementation, Paper/Huang implementations, random generators, pass identifiers, metric denominators and controlled/native definitions remain unchanged.

The first five registered formal pass identifiers at each retained group/SNR are the complete revised sample. Existing pass identifiers above five are retained as superseded parent-budget evidence and excluded deterministically, without inspecting performance. They must not be mixed into the expedited report.

This amendment cannot be presented as completion of the parent 50-pass-per-SNR/Rician-inclusive R3 budget. Final reports must state actual versus parent sample counts and the reduced precision explicitly.
