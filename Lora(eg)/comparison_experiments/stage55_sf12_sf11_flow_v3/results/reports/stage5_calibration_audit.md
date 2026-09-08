# 阶段 5 SF12 机制标定审计

时间：2026-09-04（Asia/Shanghai）

结论：参数版本 4 通过并冻结。参数版本 1 的失败、参数版本 2 的作废和参数版本 3 的烟雾失败均单独保留。

- 参数来源仅为独立 mechanism-calibration 的 CFO 误差、置信覆盖、误接纳和速率可观测性。
- 未读取 V1/V2 正式 SER、论文图像 marker 或任何 V3 正式性能曲线。
- 参数版本 4 使用新的 mechanism/validation pass-index 种子子域，包含跨帧前导 CFO 速率注入、短历史 VP 保护及 SF12 局部 CFO 鲁棒 bootstrap。
- calibration 每个 SNR 12 帧，按误接纳率 95% Wilson 上界不高于 2% 选择置信门。
- 孤立置信 validation：误接纳率 0.009217，覆盖率 0.121094，通过 0.02/0.01 门。
- 动态跨帧 VP validation：误接纳率 0，覆盖率 0.068080，通过 0.02/0.01 门。
- Rician K=10 dB 与复 AWGN 的实测平均功率分别为 1.0019 和 1.0024。
- `receiverParameterManifest.json` 状态为 `frozen`，记录完整参数、选择证据和算法签名。
- 冻结算法签名：`b3134fb32179f9025e2b9682c87e6471d0b25c31c156807537aff7f7af4510ee`。
- 参数重新加载、身份匹配和签名验证均通过；接收机核心变化将拒绝加载。

全量回归：21 passed、0 failed、0 incomplete；Code Analyzer：0 问题。
