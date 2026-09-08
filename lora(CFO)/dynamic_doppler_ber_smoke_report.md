# 动态 Doppler BER Smoke 报告

## 仿真范围

- 配置：`figure17_smoke`
- Doppler 模型：`paper_piecewise_linear`
- 时间模式：`fixed_orbit_start_independent_symbols`
- 接收机：uncompensated noncoherent dechirp FFT argmax
- 信道：unit-power complex baseband AWGN
- bit 映射：natural binary
- 目标 bit 错误数：200
- 每点最大 bit 数：2000000
- 复采样批上限：2000000
- 最终 Figure 17：未生成

论文没有完整公开 Figure 17 的接收机和 SNR 细节。本报告采用本项目已验证的单位平均采样功率、复基带 AWGN、理想符号边界、无 Doppler 补偿以及非相干 dechirp-FFT-argmax 判决。

## 公式推导场景

- shared visibility window 第一段：`[-253.364624963310, -2.344896842552] s`
- high Doppler shift 起始时刻：`-253.364624963310 s`
- high Doppler rate 起始时刻：`-2.344896842552 s`

## 每点结果

| 场景 | SF | SNR(dB) | BER | SER | bit数 | 批数 | 秒 | MATLAB峰值(MiB) | MATLAB增量(MiB) | 保守估算(MiB) | 停止原因 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| high_doppler_rate | 5 | -10.0 | 0.275342 | 0.544189 | 20480 | 1 | 0.240 | 3747.38 | 11.24 | 16.01 | target_bit_errors |
| high_doppler_rate | 5 | 0.0 | 2e-06 | 2.5e-06 | 2000000 | 98 | 21.435 | 3747.38 | 11.02 | 16.01 | maximum_bits |
| high_doppler_rate | 5 | 10.0 | 0 | 0 | 2000000 | 98 | 21.474 | 3742.37 | 11.02 | 16.01 | maximum_bits |
| high_doppler_rate | 7 | -10.0 | 0.0681152 | 0.150635 | 28672 | 1 | 0.237 | 3775.37 | 44.02 | 64.12 | target_bit_errors |
| high_doppler_rate | 7 | 0.0 | 0 | 0 | 1999998 | 70 | 16.880 | 3775.37 | 44.02 | 64.12 | maximum_bits |
| high_doppler_rate | 7 | 10.0 | 0 | 0 | 1999998 | 70 | 16.714 | 3772.31 | 44.09 | 64.12 | maximum_bits |
| high_doppler_rate | 8 | -10.0 | 0.22171 | 0.860352 | 32768 | 1 | 0.269 | 3808.35 | 88.02 | 128.50 | target_bit_errors |
| high_doppler_rate | 8 | 0.0 | 0.250519 | 0.999756 | 32768 | 1 | 0.269 | 3810.96 | 88.02 | 128.50 | target_bit_errors |
| high_doppler_rate | 8 | 10.0 | 0.250702 | 1 | 32768 | 1 | 0.265 | 3810.96 | 88.02 | 128.50 | target_bit_errors |
| high_doppler_rate | 12 | -10.0 | 0.315574 | 1 | 5856 | 1 | 0.499 | 3890.84 | 167.90 | 244.00 | target_bit_errors |
| high_doppler_rate | 12 | 0.0 | 0.309768 | 1 | 5856 | 1 | 0.514 | 3891.09 | 168.02 | 244.00 | target_bit_errors |
| high_doppler_rate | 12 | 10.0 | 0.320867 | 1 | 5856 | 1 | 0.485 | 3891.21 | 167.90 | 244.00 | target_bit_errors |
| high_doppler_shift | 5 | -10.0 | 0.467627 | 0.974365 | 20480 | 1 | 0.216 | 3734.46 | 11.02 | 16.01 | target_bit_errors |
| high_doppler_shift | 5 | 0.0 | 0.386279 | 1 | 20480 | 1 | 0.225 | 3734.46 | 11.02 | 16.01 | target_bit_errors |
| high_doppler_shift | 5 | 10.0 | 0.375732 | 1 | 20480 | 1 | 0.219 | 3734.46 | 11.02 | 16.01 | target_bit_errors |
| high_doppler_shift | 7 | -10.0 | 0.494838 | 0.998047 | 28672 | 1 | 0.239 | 3767.46 | 44.02 | 64.12 | target_bit_errors |
| high_doppler_shift | 7 | 0.0 | 0.488316 | 1 | 28672 | 1 | 0.239 | 3767.46 | 44.02 | 64.12 | target_bit_errors |
| high_doppler_shift | 7 | 10.0 | 0.47719 | 1 | 28672 | 1 | 0.238 | 3767.46 | 44.02 | 64.12 | target_bit_errors |
| high_doppler_shift | 8 | -10.0 | 0.561188 | 1 | 32768 | 1 | 0.265 | 3811.59 | 88.15 | 128.50 | target_bit_errors |
| high_doppler_shift | 8 | 0.0 | 0.56134 | 1 | 32768 | 1 | 0.265 | 3811.72 | 88.15 | 128.50 | target_bit_errors |
| high_doppler_shift | 8 | 10.0 | 0.559052 | 1 | 32768 | 1 | 0.266 | 3811.72 | 88.02 | 128.50 | target_bit_errors |
| high_doppler_shift | 12 | -10.0 | 0.51571 | 1 | 5856 | 1 | 0.475 | 3891.58 | 167.89 | 244.00 | target_bit_errors |
| high_doppler_shift | 12 | 0.0 | 0.526469 | 1 | 5856 | 1 | 0.477 | 3891.58 | 167.77 | 244.00 | target_bit_errors |
| high_doppler_shift | 12 | 10.0 | 0.517589 | 1 | 5856 | 1 | 0.485 | 3891.71 | 167.90 | 244.00 | target_bit_errors |

## 完整性审查

- BER/SER 出现 NaN 或 Inf：否
- 出现空批次：否
- FFT bin 映射全部有效：是
- 使用 AWGN order-statistic 主算法：否
- 使用 Doppler 补偿或人工 FFT-bin 平移：否
- continuous-sequence diagnostic：本次未运行
- 最终 Figure 17 已生成：否
