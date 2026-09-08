# 发现记录：Figure 17 动态 Doppler BER 粗网格预检

- 当前分支：`codex/dynamic-doppler-ber-smoke`。
- 当前提交：`4a79703 test: verify dynamic Doppler BER smoke sweep`。
- 工作树干净。
- 第 5 轮完整回归：51/51 通过，Code Analyzer 问题数为 0。
- `lora_dynamic_doppler_ber_config` 已通过
  `lora_figure17_geometry` 自动取得 high-rate/high-shift 起始时刻。
- shared visibility window 第一段为
  `[-253.364624963310, -2.344896842552] s`。
- `simulate_lora_dynamic_doppler_ber_point` 已实现完整时域动态相位、复 AWGN、
  原 dechirp–FFT 判决与自然二进制 bit 统计。
- `paper_piecewise_linear` 读取现有 `linearPhaseRad`；
  `exact_orbit_sampled` 读取现有 `exactPhaseRad`。
- 既有引擎按 `maxComplexSamplesPerBatch` 自动批处理，并保存原始错误计数、
  时延、内存、FFT 映射有效性和场景指标。
- smoke 已呈现预期初步趋势：high-rate 的 SF5/SF7 随 SNR 明显改善；
  high-rate 的 SF8/SF12 及 high-shift 多数点较差。
- 336 点中，低错误率的 SF5/SF6/SF7 高 SNR 点可能运行到 1e7 bit；
  必须 checkpoint 并支持续跑。
- 粗网格必须额外保存逐点结果 CSV，否则 16 行场景/SF 诊断表无法完整保存
  336 点的原始 bit_errors 与 total_bits。

