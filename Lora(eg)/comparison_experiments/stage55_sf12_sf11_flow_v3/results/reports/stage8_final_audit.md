# 阶段 8 报告与最终审计

结论：通过。

- 正式汇总 60 行：10 SNR × 2 区域 × 3 方法。
- 逐符号 CFO RMSE 6,720 行：10 × 2 × 3 × 112。
- 配对区间 160 行，全部以完整过境为重采样单位，每项 2,000 次 bootstrap。
- 输出 SER、硬 BER、ML 软 BER、PER、CFO、common/native goodput、运行时间、FFT 与 deadline 支撑量。
- Paper Midamble 明确报告 38 个符号开销；分支名称固定为 `Paper-Midamble-Point-SF12-CR3-adapted`，不是论文原图复现。
- `V3_SF11_DIFFERENCES.md` 保留所有长期差异。
- 最终 `auditV3`：24 passed、0 failed；Code Analyzer 0；冻结源哈希差异 0；范围违规 0；正式点 10；每点完整过境数均为 5；`usesOrbitPrior=false`。

性能排序只作为冻结参数后的盲测观察，未用于参数反向选择或测试断言。

