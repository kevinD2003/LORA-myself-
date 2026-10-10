# EXP1-SF12-ORBIT-POSITION-V2 冻结规格

规范来源：`C:\Users\chene\Desktop\实验一_SF12轨道位置扫描_修订方案_v2.md`，SHA-256 `870a3adba9498935a2cbc7de8d9d18b0763a7ddee9ef07b5dcb03b8a955155a1`。本文件提取实际执行所需的冻结项；原文中的说明性内容不替代用户请求或运行时审计。

## 研究问题

1. 在固定 PHY、共同波形和冻结接收机规则下，Stage55 相对 Huang/PREC 与 Paper Midamble-Point 的性能差异如何随轨道位置变化？
2. 性能差异是否与同一数据时刻的残余 CFO、帧内错误位置和 VP 行为一致？
3. 关闭 payload VP 更新后，Stage55 在低、中、高动态位置如何变化？

轨道扫描提供相关性证据；只有 VP 开/关配对消融支持的部分才允许作机制性表述。

## 冻结矩阵

| 项目 | 值 |
|---|---|
| SF / BW / Fs | 12 / 125 kHz / 125 kHz |
| LDRO / CR | off / 工程 CR3（4/7 Hamming） |
| 信息位 / 数据符号 | 768 / 112 |
| 共同时间轴 | 8 bootstrap + 112 data + 37 midamble = 157T |
| `Ts` / 物理 bin | 32.768 ms / 30.517578125 Hz |
| 信道 | 固定单位信号功率参考的复 AWGN + 连续轨道 Doppler |
| 轨道起点 | `[-366, -274.5, -183, -91.5, 0] s` |
| 主扫描 SNR | `[-24, -21.12] dB` |
| 方法 | Huang/PREC、Paper、Stage55、Ideal |
| VP 消融位置 | `[-366, -91.5, 0] s` |

父端点逐包复现使用父结果实际的 `-21 dB`，不要求它与 `-21.12 dB` 数值相同。

## 阶段和预算

| 阶段 | 预算 | seed 集合 |
|---|---:|---|
| smoke | 两端点 × -21 dB × 10 包 | 父 Unified V23 的原始包身份 |
| pilot | 五点 × -24 dB × 200 包 | `pilot` 独立集合 |
| formal | 五点 × 两 SNR × 1000 包 | `formal` 独立集合 |
| ablation | 三点 × 两 SNR × 1000 包 | 与对应 `formal` 相同包身份 |

Formal 后仅按预登记的精度或定位规则 refinement，最大 5000 包/单元；不因结果不符合预期选择性补跑。

## VP-off

`Stage55-VP-off` 保留：

- 同一接收机可观测模式选择；
- 共同前导与联合前导 CFO/rate 初始化；
- 原有数据检测、逐符号状态预测和初始 rate 外推；
- 同一 payload、噪声、轨道和时间轴。

唯一变化是 payload 中不把数据判决提升为 VP，也不执行由 VP 观测触发的历史更新。该版本不自动等同于 Huang。

## 保存量与统计

- 每包保存符号/Hard-BER/ML-BER 错误计数、包级事件、失败标志、共享输入指纹。
- 保存 `fD_start_Hz`、最后样本/右边界 Doppler、起始/最大绝对 rate、signed/absolute frame drift、frame range 和数据中心时刻。
- 保存各方法数据符号位置的错误指示与残余 CFO；内部无逐符号 rate 输出时标为缺失，不填零。
- Stage55 保存候选、接纳、错误接纳计数；接纳数为零时错误率为缺失。
- `DeltaSER = SER_baseline - SER_Stage55`，正值表示 Stage55 更好。
- CI 使用 packet-level paired bootstrap，默认 10000 draws。同一 draw 对全部方法使用同一 packet 索引。
- 全零错误时不报告真实 SER=0；附带 `1 - 0.05^(1/N)` 的包级事件单侧 95% 保守上界。

## 完成门

- G0：父版本、端点、Paper 分支、时间/相位、噪声、随机性和结果来源闭环。
- G1：实现、父端点逐包 smoke、VP-off 路径和 R2022a 测试通过后，才进入 Formal。
- G2：从逐包数据重算汇总、CI 和图表，确认单元完整、包身份唯一且无静默失败后发布结论。

