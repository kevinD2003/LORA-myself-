# 阶段 3 三接收机分支审计

时间：2026-09-04（Asia/Shanghai）

结论：通过。

全量回归：12 passed、0 failed、0 incomplete；Code Analyzer：0 问题。

- 方法名严格为方案指定的三个名称。
- 公共物理时间轴含 8 bootstrap、112 数据和 38 Midamble；三方法数据符号物理时刻一致。
- 三方法复用同一个 bootstrap 对象，CFO/相位逐元素一致。
- Huang 与 Stage55 的显式 Midamble 接纳为 0；Paper 的虚拟导频接纳为 0。
- Paper 使用 `n_int=3` 的已知纯 upchirp Midamble 和累加残余 CFO。
- Stage55 最多 5 次迭代；软信息只决定接纳，VP 标签固定来自补偿后的硬 LoRa 判决。
- Hamming 置信仅在完整 7 符号块之后生效；接纳生效物理行不早于可用行。
- rolling history 的活动项始终不超过 8；拟合含历史衰减、peak 权重和 Huber 权重。
- 单符号 CFO 融合、受双门保护的相位对 CFO、VP 速率可观测性门均已接线。
- 三分支最终统一输出 SER、硬 BER、ML 软 BER、PER、CFO 与 FFT 计数所需原始量。
- 无噪声常 CFO 配对帧中，三方法 SER/硬 BER/软 BER/PER 均为 0。

边界审计：接收机输出声明不使用 Payload/轨道真值；真值只由 `v3EvaluateFrame` 外层评估器接收。本阶段使用的 wiring 参数不是冻结标定参数，未运行或读取正式曲线。

