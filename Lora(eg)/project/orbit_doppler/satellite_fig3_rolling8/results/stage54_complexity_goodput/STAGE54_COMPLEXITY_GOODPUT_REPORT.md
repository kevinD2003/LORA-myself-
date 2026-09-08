# Stage 54：复杂度与有效通信速率审计

本报告只读取 Stage 53 冻结的 5 次完整过境结果；没有重新运行接收机，没有改变算法、阈值、随机种子或曲线数据。

## Huang-PREC 来源锚点

- `D:\codex\师兄代码\matlab\CFO相关\频移算法\PREC.m`
  - SHA-256: `3AB8FBC23C595485E0CC9E478223C1A4048BD034A666EE97D7499AF55DF77E98`
- `D:\codex\师兄代码\matlab\CFO相关\频移算法\卫星信道\卫星信道\MonteCarlo_BER_RMSE_PRC_EC_TQ28.m`
  - SHA-256: `85E657783A2A791DE2843526334DE6BBAD816CF2050E8D5A164A5D19A1C1CFD1`

当前 Huang 基线保留其 `eta=0:0.1:0.9`、8 个零上啁啾、去啁啾 FFT、全局峰值和 `epsilonHat=integerBin-eta`。唯一物理适配是将跨符号复数平均改成逐上啁啾 FFT 功率累加，以避免连续相位造成相消；载荷期 CFO 固定。

## 口径

- 每帧信息位：`704 bit`；帧长：`0.98304 s`；名义信息速率：`716.145833 bit/s`。
- active-link packet goodput = `(1-PER)*信息位/帧长`。
- pass-average delivery 将成功帧信息位除以完整 508 帧过境墙钟时间，包含盲区。
- correct-bit rate = `(1-BER)*名义信息速率`，只作为不丢弃坏帧时的辅助上界。
- runtime 是本机 MATLAB 实测，不等价于硬件无关运算量；理论计数另列。

## 正式运行时间与有效速率

| SNR | 方法 | 平均/中位/P95耗时(s/帧) | 相对Huang | 实时裕量 | deadline miss | active goodput | pass-average | correct-bit rate |
|---:|---|---:|---:|---:|---:|---:|---:|---:|
| -21 | Huang-PREC-static-CP | 0.03193 / 0.03088 / 0.03463 | 1.00x | 30.78x | 0 | 161.13 | 136.99 | 686.87 |
| -21 | SenLoRa-VP | 0.21586 / 0.19815 / 0.30091 | 6.76x | 4.55x | 0 | 132.62 | 112.75 | 685.15 |
| -20 | Huang-PREC-static-CP | 0.03137 / 0.03022 / 0.03406 | 1.00x | 31.34x | 0 | 399.85 | 339.95 | 703.39 |
| -20 | SenLoRa-VP | 0.23017 / 0.19908 / 0.30652 | 7.34x | 4.27x | 0 | 363.71 | 309.22 | 705.12 |

## 代码级复杂度计数

`M=2048`。Huang 每帧精确执行 200 个 M 点 FFT。SenLoRa 因提前收敛在 2--5 次之间，执行 552--1248 个 M 点 FFT，另含 Gray LLR、软 Hamming、11 点局部残差投影和 rolling-8 稳健拟合。

| 方法 | M点FFT下/上界 | 迭代下/上界 | LLR log-sum-exp输入下/上界 | 软Hamming评分项下/上界 | 残差投影bank上界 |
|---|---:|---:|---:|---:|---:|
| Huang-PREC-static-CP | 200 / 200 | 1 / 1 | 0 / 0 | 0 / 0 | 0 |
| SenLoRa-VP | 552 / 1248 | 2 / 5 | 5.04627e+06 / 1.26157e+07 | 39424 / 98560 | 315 |

## 动态区有效速率

| SNR | 区域 | 方法 | BER | PER | active packet goodput (bit/s) |
|---:|---|---|---:|---:|---:|
| -21 | low dynamic lt 0p5 bin per frame | Huang-PREC-static-CP | 0.0138084 | 0.669388 | 236.767 |
| -21 | low dynamic lt 0p5 bin per frame | SenLoRa-VP | 0.0431876 | 0.810204 | 135.922 |
| -21 | high dynamic ge 0p5 bin per frame | Huang-PREC-static-CP | 0.0985672 | 1 | 0.000 |
| -21 | high dynamic ge 0p5 bin per frame | SenLoRa-VP | 0.0434741 | 0.824638 | 125.585 |
| -20 | low dynamic lt 0p5 bin per frame | Huang-PREC-static-CP | 0.0024341 | 0.182993 | 585.096 |
| -20 | low dynamic lt 0p5 bin per frame | SenLoRa-VP | 0.0155129 | 0.485714 | 368.304 |
| -20 | high dynamic ge 0p5 bin per frame | Huang-PREC-static-CP | 0.0505579 | 0.992754 | 5.189 |
| -20 | high dynamic ge 0p5 bin per frame | SenLoRa-VP | 0.0151412 | 0.505797 | 353.921 |

## 可用于论文的结论边界

- SenLoRa 的平均接收机耗时约为 Huang 的 `6.76x`（-21 dB）和 `7.34x`（-20 dB），但两者所有正式帧均在 0.98304 s 帧周期内完成，deadline miss rate 为 0。
- 全过境 packet delivery 在 -21 dB 为 Huang/Sen `136.99/112.75 bit/s`，在 -20 dB 为 `339.95/309.22 bit/s`。SenLoRa 的 BER 改善不必然转化为 PER/goodput 改善，因为少量误码可能分散到更多帧。
- 物理高动态区两种 SNR 下 SenLoRa 的 BER 和 packet goodput 均优于静态 Huang；低动态区 Huang 更好。这是主时间图中曲线可区分的原因，也必须作为算法适用边界同时报告。
- 本报告没有测量功耗、芯片面积或嵌入式能耗；不能用 MATLAB 墙钟时间替代这些指标。硬件无关比较应引用 FFT/LLR/Hamming/残差投影计数。
