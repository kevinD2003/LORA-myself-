# 动态 Doppler BER Smoke 设计规范

## 1. 目标与范围

本轮在 `kevinD2003/LORA-theory` 的独立开发分支
`codex/dynamic-doppler-ber-smoke` 上建立动态 Doppler BER 引擎，并实际运行
24 个 smoke 点：

- SF：`[5, 7, 8, 12]`；
- SNR：`[-10, 0, 10] dB`；
- 场景：`high_doppler_rate`、`high_doppler_shift`；
- Doppler 模型：`paper_piecewise_linear`；
- 时间模式：`fixed_orbit_start_independent_symbols`；
- 每点停止条件：`targetBitErrors=200`、`maxBitsPerPoint=2e6`。

本轮不运行完整 Figure 17 扫描，不绘制最终 Figure 17，不使用干扰、FEC、
交织、白化、CRC、帧头、LoRaWAN、衰落、多径、CFO 或 STO。

## 2. 现状与唯一实现来源

远端 `main` 只有原 AWGN 基准。前四轮已经验证的动态 Doppler MATLAB
源码位于 `D:\codex\lora(CFO)`。实现阶段将这些源码和测试按原内容迁入当前
Git 分支，成为仓库内唯一的轨道与 Doppler 实现；不会重写、改名或创建第二套
同职责函数。

迁入并复用的 MATLAB 文件为：

- `lora_orbit_doppler_config.m`
- `lora_orbit_doppler_trajectory.m`
- `lora_visibility_window.m`
- `lora_figure17_geometry.m`
- `lora_symbol_instantaneous_frequency.m`
- `apply_lora_dynamic_doppler.m`
- `lora_doppler_piecewise_linear.m`
- `lora_css_demodulate_dynamic_channel.m`
- `run_lora_doppler_figure3.m`
- `run_lora_doppler_approx_validation.m`
- `test_lora_dynamic_doppler.m`
- `test_lora_dynamic_channel.m`
- `test_lora_doppler_approximation.m`

历史 PNG、PDF、CSV 和 JSON 只作为审查证据读取，不在迁入阶段复制。对应
运行器仍可从仓库源码重新生成这些产物。

## 3. 现有接口映射

### 3.1 轨道场景

`geometry = lora_figure17_geometry()` 自动推导：

- `geometry.sharedFirstSec`
- `geometry.highShiftTimeSec = geometry.sharedFirstSec(1)`
- `geometry.highRateTimeSec = geometry.sharedFirstSec(2)`
- `geometry.configA`

BER 配置和仿真只能从该接口取得场景起始时刻。论文近似值
`18.6 kHz`、`571 Hz`、`-254.9 s`、`-2.345 s` 只能作为 metadata 或测试
容差参考，不能参与场景构造。

### 3.2 Doppler 模型

`paper_piecewise_linear` 映射到：

```matlab
result = lora_doppler_piecewise_linear( ...
    symbol, sf, startTimeSec, orbitConfig, ...
    BandwidthHz=bandwidthHz);
frequencyHz = result.linearDopplerHz;
phaseRad = result.linearPhaseRad;
```

`exact_orbit_sampled` 映射到同一已验证调用的精确字段：

```matlab
frequencyHz = result.exactDopplerHz;
phaseRad = result.exactPhaseRad;
```

它与 `apply_lora_dynamic_doppler(..., Mode="full_rf")` 使用同一完整 RF
逐采样定义：

```text
f_D[n] = -(f_c + f_bb,s[n]) v(t[n]) / c
```

因此 BER 引擎不新增第三个 Doppler 计算函数。正式 smoke 默认使用
`paper_piecewise_linear`，测试保留 `exact_orbit_sampled` 交叉验证。

## 4. 新增组件

### 4.1 `lora_dynamic_doppler_ber_config.m`

返回单一配置结构，包含：

- `profile = "figure17_smoke"`
- `bandwidthHz = 250e3`
- `spreadingFactors = [5, 7, 8, 12]`
- `snrDb = [-10, 0, 10]`
- 两个轨道场景
- `dopplerModel = "paper_piecewise_linear"`
- `timeMode = "fixed_orbit_start_independent_symbols"`
- `targetBitErrors = 200`
- `maxBitsPerPoint = 2e6`
- `maxComplexSamplesPerBatch = 2e6`
- `maxSymbolsPerBatch = 4096`
- 独立的符号与噪声基础随机种子
- `geometry = lora_figure17_geometry()`

配置必须保存公式推导的 shared-window 起始时刻，不保存用于构造场景的论文
近似频偏。

### 4.2 `simulate_lora_dynamic_doppler_ber_point.m`

接口：

```matlab
result = simulate_lora_dynamic_doppler_ber_point( ...
    profile, orbitScenario, timeMode, dopplerModel, ...
    sf, snrDb, config)
```

该函数执行一个 BER 点的完整时域 Monte Carlo，不调用
`simulate_lora_css_awgn_point`，也不使用 order-statistic 最大错误 bin。

### 4.3 `run_lora_dynamic_doppler_ber_smoke.m`

接口：

```matlab
outputs = run_lora_dynamic_doppler_ber_smoke( ...
    OutputDirectory=string(pwd))
```

运行 24 个 smoke 点，写出 CSV 和中文 Markdown 报告，不生成 Figure 17
图像。

### 4.4 `test_lora_dynamic_doppler_ber.m`

验证配置、场景来源、完整时域判决、批处理、两种模型、两种时间模式、
随机种子、字段完整性以及 runner 产物。

## 5. 完整时域 BER 数据流

每批处理按以下顺序执行：

1. 使用独立符号随机流生成自然二进制索引的随机 LoRa CSS 符号；
2. 调用原 `lora_css_modulate` 生成单位平均采样功率的 `M-by-N` 波形；
3. 对批内每个符号调用现有 `lora_doppler_piecewise_linear`，选择
   `linearPhaseRad` 或 `exactPhaseRad`；
4. 计算 `x .* exp(1j*phase)`；
5. 使用独立噪声随机流加入方差 `10^(-SNRdB/10)` 的复基带 AWGN；
6. 调用原 `lora_css_demodulate` 完成 dechirp、M 点 FFT 和
   `argmax |Y[k]|^2`；
7. 立即累计符号错误与自然二进制 bit 错误；
8. 清除本批波形，进入下一批。

不对 Doppler 做补偿，不平移 FFT bin，不长期保留 Monte Carlo 波形。

## 6. Monte Carlo 时间模式

### 6.1 `fixed_orbit_start_independent_symbols`

这是 Figure 17 主模式：

- 每个 Monte Carlo 符号使用同一场景 `t0`；
- 每个符号的 Doppler 初相位重置为 0；
- 符号内采样时间为 `t0 + n/B`；
- 不随 Monte Carlo 符号编号推进轨道时间。

对于同一批中重复出现的符号索引，可以缓存该批所需的相位向量，但缓存只在
当前 BER 点内使用，不改变模型。

### 6.2 `continuous_symbol_sequence`

这是单独标记的诊断模式：

- 第 `m` 个符号从 `t0 + m*Ts` 开始；
- 随机符号序列连续生成；
- Doppler 相位跨符号连续；
- 接收机仍按理想符号边界逐符号检测。

由于现有单符号相位字段以 0 开始，跨符号相位偏置按梯形积分补齐：

```text
phi_first(m) =
phi_last(m-1) + pi/Fs * (fd_last(m-1) + fd_first(m))
```

随后给当前符号的单符号相位向量整体加上 `phi_first(m)`。测试必须直接验证
边界相位和频率积分的一致性。

## 7. 批处理与内存

```matlab
M = 2^sf;
batchSymbols = min( ...
    config.maxSymbolsPerBatch, ...
    max(1, floor(config.maxComplexSamplesPerBatch/M)));
```

最后一个批次还要受剩余 bit 数限制。任何批次都必须至少包含一个符号。

每点新增以下诊断：

- `peak_complex_samples_per_batch`
- `estimated_peak_memory_bytes`
- `peak_matlab_memory_bytes`
- `peak_matlab_memory_delta_bytes`

`peak_matlab_memory_bytes` 在 Windows MATLAB 中通过 `memory` 于主要分配阶段
采样。由于 FFT 内部临时区不保证能被采样捕获，报告同时给出基于同时驻留
复数矩阵的保守估算 `estimated_peak_memory_bytes`，并明确标记测量方法。

## 8. 随机种子与停止规则

符号和噪声使用两个独立 `RandStream('mt19937ar',...)`。点种子由基础种子与
场景、时间模式、模型、SF、SNR 的稳定整数索引组合得到，不能依赖全局 RNG
的先前状态。

每点停止条件：

- `bit_errors >= targetBitErrors`，记录
  `stop_reason="target_bit_errors"`；或
- `total_bits >= maxBitsPerPoint`，记录
  `stop_reason="maximum_bits"`。

BER 和 SER 分别由累计错误数除以累计数量。若零错误，则保存 `ber=0` 或
`ser=0`，并额外保存 `ber_upper_bound=1/total_bits` 与
`ser_upper_bound=1/total_symbols`，避免在结果表中产生 NaN。

## 9. 输出字段

每个 BER 点至少包含用户要求的全部字段：

- `profile`
- `orbit_scenario`
- `time_mode`
- `doppler_model`
- `sf`
- `snr_db`
- `orbit_start_time_s`
- `orbit_initial_doppler_hz`
- `orbit_initial_doppler_rate_hz_per_s`
- `symbol_duration_s`
- `fft_bin_spacing_hz`
- `half_bin_tolerance_hz`
- `normalized_initial_bin_offset`
- `doppler_change_over_symbol_hz`
- `normalized_rate_sweep_bins`
- `quadratic_phase_span_rad`
- `ber`
- `bit_errors`
- `total_bits`
- `ser`
- `symbol_errors`
- `total_symbols`
- `monte_carlo_batches`
- `symbols_per_batch`
- `seed_symbols`
- `seed_noise`
- `stop_reason`
- `elapsed_seconds`

并附加零错误上界和内存诊断字段。

轨道初始 Doppler 和 Doppler rate 由
`lora_orbit_doppler_trajectory(t0, geometry.configA)` 计算。

## 10. 测试设计

至少覆盖：

1. 配置严格包含 24 个 smoke 组合；
2. 场景时刻等于 `lora_figure17_geometry().sharedFirstSec` 两端点；
3. 修改论文近似 metadata 不影响场景时刻；
4. `paper_piecewise_linear` 相位逐样点等于现有函数的
   `linearPhaseRad`；
5. `exact_orbit_sampled` 相位逐样点等于现有函数的
   `exactPhaseRad`；
6. no-Doppler 测试配置下检测与原接收机一致；
7. 动态 BER 路径不调用 `simulate_lora_css_awgn_point`；
8. 批大小满足复采样上限且非空；
9. natural-binary bit 错误统计与手工 `bitxor/bitget` 一致；
10. fixed 模式重复符号的起始时间和初相位不推进；
11. continuous 模式起始时间按 `Ts` 推进且相位跨边界连续；
12. 相同双随机种子得到完全一致结果；
13. 不同噪声种子改变结果但不改变符号流；
14. 结果字段有限，无 NaN、Inf、空批次和越界检测 bin；
15. runner 生成三个指定产物且不生成 Figure 17 图。

正式验收还将重新运行原 AWGN 测试和前四轮全部动态 Doppler 测试。

## 11. 本轮产物

- `dynamic_doppler_ber_smoke.csv`
- `dynamic_doppler_ber_smoke_report.md`
- `test_dynamic_doppler_ber_results.txt`

Markdown 和 TXT 审查文件使用中文。CSV 字段保持英文 snake_case，方便
MATLAB 和后续 Figure 17 runner 读取。

