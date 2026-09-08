# V4 轨道、轨道参数与信道差异记录

修订日期：2026-09-07

## 1. Track A 与 Track B

| 项目 | Track A：Paper-condition anchor | Track B：完整项目移植 |
|---|---|---|
| 研究问题 | 论文机制趋势是否合理 | 完整 Stage55 与两种参考方法谁更有效 |
| Payload | 23 个 symbol-level labels | 16 个 CR3 块、112 数据符号 |
| 信息位声明 | 120 bit 仅为场景元数据 | 768 个经过编码往返验证的信息 bit |
| 编码指标 | 不报告伪 CR1 BER/PER | SER、硬 BER、ML BER、PER |
| Paper 身份 | Paper-native | Paper-adapted |
| 初始化 | 最后完整 downchirp Point | 共同 8-upchirp bootstrap |
| residual CFO | 整数 FFT-bin peak | 允许经标定的 sub-bin estimator |
| 调度 | Case1/Case2 paired packet | continuous satellite pass |
| 统计单位 | paired packet | complete pass cluster |

两轨共同使用 SF12、125 kHz、no-LDRO、4096 直接标签，但数值曲线不能混称或直接合并。

## 2. Track B 与原始 SF11：轨道参数

| 参数 | 原始 SF11 | Track B | 是否相同 |
|---|---:|---:|---|
| 地球半径 | 6371 km | 6371 km | 是 |
| 卫星高度 | 550 km | 550 km | 是 |
| 轨道倾角 | 15° | 15° | 是 |
| 地球自转角速度 | 7.292e-5 rad/s | 相同 | 是 |
| 载波频率 | 868 MHz | 868 MHz | 是 |
| 理论最大仰角 | 56° | 56° | 是 |
| 最低通信仰角 | 10° | 10° | 是 |
| 中央盲区边界 | 50° | 50° | 是 |
| 中央过境时间 | 0 s | 0 s | 是 |
| 轨道模型 | 单星圆轨道 | 相同 | 是 |
| Doppler | 逐采样径向速度 | 相同公式 | 是 |
| Doppler phase | 连续积分 | 连续积分 | 是 |

同一轨道不等于同一离散动态难度。SF12 的符号时间为 32.768 ms，是 SF11 8.192 ms 的 4 倍；FFT bin 从 122.0703 Hz 变为 30.5176 Hz。因此相同 Hz/s Doppler rate 在 bin/s 和单符号漂移上的表现不同，所有门限必须重新标定。

## 3. Track B 与原始 SF11：PHY 和编码

| 参数 | 原始 SF11 | Track B |
|---|---:|---:|
| SF | 11 | 12 |
| BW/Fs | 250 kHz | 125 kHz |
| FFT | 2048 | 4096 |
| LDRO | 不适用本 V4 身份 | false |
| 有效数据位 | 11 | 12 |
| 标签数 | 2048 | 4096 |
| bin 映射 | 直接 | 直接 |
| Hamming 块 | 16 | 16 |
| Payload symbols | 112 | 112 |
| 信息位 | 704 | 768 |

Track B 是“流程移植”，不是“只改变 SF 的单变量实验”。

## 4. Track B 与原始 SF11：信道

| 项目 | 原始 SF11 主口径 | V4 Track B 主口径 |
|---|---|---|
| Doppler | 有 | 有，轨道公式一致 |
| AWGN | 主结果口径 | 机制基线保留 |
| Rician | 不是主要正式口径 | packet-flat K=10 dB 独立补充 |
| 包间复信道相位 | 无独立 Rician 跳变 | `angle(h_k)` 可逐包跳变 |
| 平均功率 | 单位平均发射功率 | 相同定义 |

Track B 的 AWGN＋连续 Doppler 是主结果，Rician 是独立补充；两者均不能解释为纯 SF11→SF12 单变量差异。

## 5. Doppler 相位与 Rician 相位

物理模型：

```text
r(t) = h_k * x(t) * exp(j*phi_Doppler(t)) + n(t)
```

连续的是 `phi_Doppler(t)`，不是逐包 Rician 系数 `h_k` 的复相位。跨帧可以保留 Doppler oscillator/CFO/rate 历史，但每帧接收机绝对相位必须由本帧前导重新估计。禁止把上一包的接收复相位直接传给下一包。

## 6. Track B 两种公平口径

| 项目 | Controlled-time | Native-overhead |
|---|---|---|
| 目的 | 比较算法跟踪能力 | 比较系统效率 |
| Paper | 112 D + 37 M | 112 D + 37 M |
| Stage55/Huang | 不读 M，但时钟推进 M 时隙 | 不发送 M |
| Payload 绝对时刻 | 三方法相同 | 各自自然时间轴，不相同 |
| 整帧 raw samples | 不要求完全相同 | 不可能完全相同 |
| 配对基础 | 公共 D 时刻、Payload、随机账本 | 轨道/种子生成规则和完整 pass |
| 主要输出 | SER/BER/PER/CFO | 另加 ToA/goodput/energy proxy |

两种结果必须分开保存、绘图和解释。
