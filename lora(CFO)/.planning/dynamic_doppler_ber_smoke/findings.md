# 发现记录：动态 Doppler BER Smoke

- 远端 `main` 只有原 AWGN 基准，前四轮 Doppler 文件尚未进入 Git。
- 原 AWGN 本地快照与远端 main 在统一换行后内容完全一致。
- 前四轮源码位于 `D:\codex\lora(CFO)`。
- 前四轮完整回归为 33/33 通过。
- `paper_piecewise_linear` 由 `lora_doppler_piecewise_linear` 提供。
- `exact_orbit_sampled` 对应同一函数的 `exactDopplerHz` 和
  `exactPhaseRad`，也与 `apply_lora_dynamic_doppler` 的 `full_rf`
  路径一致。
- Figure 17 shared-window 第一段为
  `[-253.364624963310, -2.344896842552] s`，由几何公式自动推导。
- 生产场景构造未硬编码 `18.6 kHz`、`571 Hz` 或对应时刻。
- 原 AWGN order-statistic 函数只适用于无 Doppler，不可在新引擎调用。
- 已迁入的 13 个前四轮 MATLAB 文件与源目录 SHA-256 逐文件一致。
- 动态 BER 主链路只调用原 `lora_css_modulate`、现有
  `lora_doppler_piecewise_linear` 和原 `lora_css_demodulate`。
- fixed 模式在 `M^2 <= maxComplexSamplesPerBatch` 时缓存相位模板；
  SF12 不会创建超出复采样上限的全符号模板。
- 正式 smoke 共 24 点；最慢点为 high-rate、SF5、0 dB，
  `13.481 s`。
- 正式 smoke 最大复采样峰值为 `1,998,848`，低于 `2e6`。
- 最大 MATLAB 增量峰值约 `178.348 MiB`；最大保守估算为
  `244 MiB`。
- high-rate 的 SF5/SF7 在 0 dB 或 10 dB 出现零或极少错误并运行到
  bit 上限；BER=0 时另存 `ber_upper_bound`，未写 NaN。
- high-shift 和 high-rate 的 SF8/SF12 在无补偿接收机中出现明显
  FFT 峰偏移/谱泄漏，通常首批即达到目标错误数。
- 未发现接口或单位不一致；`exact_orbit_sampled` 已明确映射到现有
  exact 字段。
- 未出现 NaN、Inf、空批次或越界 FFT bin。
- 生产代码未调用 AWGN order-statistic、人工 bin shift 或 Doppler
  补偿，也未硬编码论文近似场景值。
- 原 AWGN 文件相对 `main` 没有改变。
- 最终完整回归为 51/51 通过，MATLAB Code Analyzer 问题数为 0。
- 本轮没有生成最终 Figure 17。
