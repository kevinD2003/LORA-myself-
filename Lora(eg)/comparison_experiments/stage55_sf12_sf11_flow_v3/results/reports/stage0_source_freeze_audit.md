# 阶段 0 来源冻结审计

时间：2026-09-04（Asia/Shanghai）

结论：通过。

- 新建目录严格位于 `D:\codex\Lora(eg)\comparison_experiments\stage55_sf12_sf11_flow_v3`。
- 目标在创建前不存在，未执行覆盖。
- 从唯一规范 SF11 目录原样复制 34 个与方案第 10 节对应的核心文件。
- `config/source_manifest.json` 为每个文件记录来源绝对路径、来源 SHA-256 和副本 SHA-256；冻结时两者全部相同。
- 冻结副本只放在 `src/upstream_sf11`；后续 SF12 适配不得修改这些副本。
- 未复制 SF11/V1/V2 结果、随机账本或检查点，V3 `results` 为空目录骨架。
- 未修改规范 SF11、V1 或 V2。

阶段 0 只冻结来源和边界，没有声称任何 SF12 算法、性能或统计结果已通过。

