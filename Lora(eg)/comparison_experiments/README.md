# Comparison experiments

本目录只保留两类内容：

1. 当前实现及其可复现实验入口；
2. 已经实际生成过 SER 与 BER 成对图的历史版本。

## 保留项目

| 目录 | 用途 | 保留原因 |
|---|---|---|
| `stage55_sf12_sf11_flow_v4_noldro/` | SF12、125 kHz、no-LDRO 的当前主实现 | 当前 Unified V23，以及已有 SER/BER 图的 V4 历史版本 |
| `stage55_sf12_sf11_flow_v3/` | SF12 条件下的 V3 三方法流程 | 已生成 `ser_snr` 与 `soft_ber_snr` |
| `stage55_three_method/` | SF11 三方法对比 | 已生成 SER/BER trajectory 图 |

早期 `stage55_sf12_paper_conditions/` 和
`stage55_sf12_paper_conditions_v2/` 只生成过 SER，没有 BER，且实现已被后续版本取代，
因此不再保留。

## 使用约定

- 新工作默认从 `stage55_sf12_sf11_flow_v4_noldro/` 开始。
- 历史结果仅用于复现和对照，不应覆盖当前版本。
- 每个保留项目的 `results/` 只留正式出图所需的原始结果、报告和图文件。

## 内容导航

- [全项目文件导航](../文件导航.md)
- [V4/SF11 对齐记录](docs/alignment/V4_SF11_PROJECT_ALIGNMENT.md)
- 各实验 `docs/code_index.md` 按功能列出源码与入口，`docs/README.md` 分类列出说明文件。
