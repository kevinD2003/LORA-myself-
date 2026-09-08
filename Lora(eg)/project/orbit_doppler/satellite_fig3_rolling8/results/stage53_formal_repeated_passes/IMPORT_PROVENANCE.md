# Stage53 正式产物合并来源

本目录的 13 个冻结正式产物于 2026-08-23 从以下只读旧副本合并：

`D:\codex\lora（prec）\satellite_fig3_rolling8(ber1)\results\stage53_formal_repeated_passes`

合并前已检查 `stage52_formal_time_latest.mat`：

- 方法为 `Huang-PREC-static-CP` 与 `SenLoRa-VP`；
- SNR 为 `-21/-20 dB`；
- 每个 SNR 有 5 个完整轨次；
- 每轨 508 帧，总记录数 5080；
- 正式状态均为完成。

合并后由 `test_stage53_formal_result_acceptance` 和
`test_stage54_complexity_goodput_report` 重新验收。性能方向只作为结果观察，
不作为代码正确性或“必须优于”门禁。
