# V4 no-LDRO comparison experiment

[按功能查找源码](docs/code_index.md) · [文档索引](docs/README.md)

## 当前实现

当前正式入口是 **Unified V23**，报告状态为 `PASS / ADMIT_V23_FREEZE`。

- Stage55 数据入口：`scripts/runV4UnifiedV16TestGrid.m`
- Huang/PREC 数据入口：`scripts/runV4HuangV9TestGrid.m`
- 汇总与出图：`scripts/buildV4UnifiedV23TestReport.m`
- 当前报告：`results/method_aligned/unified_v23_report/`

Unified V23 的三接收机实现分别是：

- Huang/PREC：`src/stage55/v4HuangPrecUnifiedDecodeV9.m`
- Stage55：`src/stage55/v4Stage55UnifiedDecodeV16.m`
- Midamble-Point：`src/paper/v4PaperMidamblePointUnifiedV6.m`

## 保留的出图版本

| 系列 | 保留版本 | 结果位置 |
|---|---|---|
| Unified | V17、V19、V21、V22、V23 | `results/method_aligned/unified_v*_report/` |
| B Case Anchor | V1–V6 | `results/case_anchor_b/` 与 `results/reports/B_CASE_ANCHOR_*` |
| Paper Figure 11 aligned | V7 | `results/paper_curve_v7/` 与 `results/reports/B_CASE2_PAPER_*` |
| 完整 Experiment B | V30 AWGN P10、Native P10 | `results/formal/track_b/` 与 `results/reports/V30_*` |

V19、V21、V22 的报告状态为历史 `FAIL`，它们仅因已经生成 SER/BER 成对图而保留；
不得把它们当作当前实现。V17 为历史 `PASS`，V23 为当前 `PASS`。

## 目录约定

- `config/`：当前和保留出图版本所需的冻结配置与清单。
- `src/`：当前实现及保留版本的依赖闭包。
- `scripts/`：重跑、聚合、审计和出图入口。
- `tests/`：当前实现及保留版本的回归测试。
- `results/`：正式出图所需的原始结果、报告、PNG 和 FIG。

运行 MATLAB 回归测试：

```matlab
cd('D:\codex\Lora(eg)\comparison_experiments\stage55_sf12_sf11_flow_v4_noldro')
addpath('scripts')
runV4Tests
```
