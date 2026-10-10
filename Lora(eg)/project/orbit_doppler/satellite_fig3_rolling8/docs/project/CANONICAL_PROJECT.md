# Stage55 规范项目位置

> 目录整理（2026-10-08）：[所属项目入口](../../README.md)。本文的 MATLAB 命令和反引号内的代码、数据及文档路径以该项目根目录为基准；历史数值和验收结论保留其原记录时间。

自 2026-08-23 起，本目录是 SenLoRa/PREC Stage55 的唯一规范工作版本：

`D:\codex\Lora(eg)\project\orbit_doppler\satellite_fig3_rolling8`

本目录已经合并原工作副本
`D:\codex\lora（prec）\new（kua zhen chuan shu）` 中的 Stage46--55
源码、测试、文档和结果，同时保留当前工作区原有历史结果。

同步前的完整版本保存在：

`D:\codex\Lora(eg)\tmp\satellite_fig3_rolling8_pre_stage55_sync_20260823`

缺失的 Stage53 冻结正式产物从旧 `satellite_fig3_rolling8(ber1)` 副本验证后合并；
来源和验收信息见
`results/stage53_formal_repeated_passes/IMPORT_PROVENANCE.md`。

开发规则：

1. 后续只修改本目录；原工作副本仅作为冻结来源快照。
2. 不得把旧结果目录覆盖成新算法结果；算法变化必须使用新结果目录。
3. Stage55 回归统一运行 `runStage55ProjectTests`。
4. 整个项目回归统一运行根目录的 `runSenLoRaProjectTests`。
5. 性能方向属于实验观察，不得用“SenLoRa 必须优于参考方法”的断言替代公平性检查。

当前源码哈希见 `docs/provenance/CANONICAL_SOURCE_SHA256_20260823.csv`，本轮测试与静态检查记录见
`docs/audit/2026-08-23/VALIDATION_20260823.md`。

旧副本与历史结果的精简记录见 `docs/audit/2026-08-23/CLEANUP_20260823.md`。
