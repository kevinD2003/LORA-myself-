# SF12 V3 正式报告

算法签名：`b3134fb32179f9025e2b9682c87e6471d0b25c31c156807537aff7f7af4510ee`。

本报告使用 -30:-21 dB、每点 5 个完整过境的 Formal V2。三方法同帧配对；置信区间以完整过境为重采样单位。

Paper 分支固定标记为 `Paper-Midamble-Point-SF12-CR3-adapted`，不是论文 Figure 10/11 原条件复现。

## 产物

- `v3_formal_summary.csv`：SER、硬 BER、ML 软 BER、PER、CFO、goodput 和运行时间。
- `v3_symbol_cfo_rmse.csv`：112 个载荷位置的逐符号 CFO RMSE。
- `v3_paired_complete_pass_ci.csv`：完整过境配对 bootstrap 95% 区间。
- `ser_snr.png`、`soft_ber_snr.png`、`per_snr.png`、`cfo_rmse_snr.png`、`goodput_snr.png`。

## Paper Midamble 开销

38 个 Midamble 相对 120 符号无 Midamble 帧增加 31.67% airtime；占 158 符号共同时间轴 24.05%。

## 固定边界

物理 SF=12，有效数据 SF=10，spacing=4，CR3，112 载荷符号，640 信息位；接收机 `usesOrbitPrior=false`。SF11 与 V3 的全部固定差异见项目根目录 `V3_SF11_DIFFERENCES.md`，不得从最终报告删除。

性能排序是冻结参数后的盲测观察，不是单元测试或调参目标。所有未满足预期的点应原样保留。
