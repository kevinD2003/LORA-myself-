# Figure 17 动态 Doppler BER 粗网格预检设计

## 背景与目标

本设计在第 5 轮已通过的动态 Doppler BER smoke 引擎上，使用论文的 Figure 17 几何参考配置，运行 336 个原始 Monte Carlo BER 点，作为最终 Figure 17 扫描前的趋势预检。该工作只增加配置、调度、诊断和绘图；不重写轨道、shared visibility window、Doppler 相位、AWGN 或接收机模块。

## 已复用的实现

- \`lora_figure17_geometry\`：从 A/B 几何与 shared visibility window 自动给出 high Doppler shift 和 high Doppler rate 场景的起始时刻。
- \`lora_orbit_doppler_trajectory\` 与 \`lora_visibility_window\`：轨道几何与可见窗口。
- \`lora_doppler_piecewise_linear\`：已验证的 \`paper_piecewise_linear\` 及 \`exact_orbit_sampled\` 频率/相位轨迹。
- \`simulate_lora_dynamic_doppler_ber_point\`：完整时域 CSS 波形、动态相位、复基带 AWGN、原 dechirp–FFT–argmax 检测、自然二进制 bit 统计与批处理。
- \`lora_css_modulate\`、\`lora_css_demodulate\`：原始 AWGN 基准的调制和检测行为。

上述函数中不重新写入轨道公式，不硬编码 \`18.6 kHz\`、\`571 Hz\` 或场景时刻。

## 参考配置

Pilot 配置的 \`profile\` 固定为 \`paper_figure17_reference\`，并显式覆盖：

- \`fc=868e6 Hz\`，\`B=Fs=250e3 Hz\`，\`H=550e3 m\`，倾角 \`15 deg\`；
- \`c=3e8 m/s\`，\`g=9.8 m/s^2\`，\`R=6371e3 m\`，\`omega_E=7.292e-5 rad/s\`；
- A/B 的理论最大仰角为 \`89/89.2 deg\`，最小/最大仰角均为 \`10/88 deg\`，A/B 地面距离为 \`10 km\`；
- \`SF=5:12\`、\`SNR=-30:2:10 dB\`；
- 场景为 \`high_doppler_rate\` 和 \`high_doppler_shift\`；
- 时间模式为 \`fixed_orbit_start_independent_symbols\`，模型为 \`paper_piecewise_linear\`；
- 每点 \`targetBitErrors=500\`、\`maxBitsPerPoint=1e7\`，不引入干扰或 Doppler 补偿。

该配置仍由 \`lora_figure17_geometry\` 提供场景起始时刻，因而没有由本配置直接写入候选时刻。

## 方案比较与选择

### 方案 A：独立 pilot 配置与可续跑调度器（采用）

新增小型 pilot 配置函数和调度器。调度器逐点调用现有 BER 点函数，每完成一点立即写入完整原始结果 CSV；若同一 profile、场景、SF、SNR、时间模式和模型的结果已存在，则安全跳过。完成或续跑完成后，再从原始表生成诊断表和图像。

优点是物理链路只有一套、运行中断可恢复、结果与诊断可审计。

### 方案 B：复用 smoke runner 后另行后处理（不采用）

这会复用循环结构，但 smoke 文件名和停止条件不匹配，且没有逐点 checkpoint。覆盖 smoke 输出也会损害第 5 轮证据。

### 方案 C：新增 FFT 域确定性均值向量加速（不采用）

虽然可减少高 SNR 点的运行时间，但当前没有独立等价性证明，且会扩大本轮范围；不能用于正式 pilot 结果。

## 文件职责

- 新建 \`lora_dynamic_doppler_figure17_pilot_config.m\`：从既有 BER 配置派生出 paper reference 粗网格配置与文件名。
- 新建 \`run_lora_dynamic_doppler_figure17_pilot.m\`：逐点可续跑调度、checkpoint、原始表写入、调用诊断和绘图。
- 新建 \`lora_dynamic_doppler_pilot_diagnostics.m\`：把 336 行原始表归并为 16 行场景/SF 诊断表，并给出趋势状态和需要检查的项目。
- 新建 \`test_lora_dynamic_doppler_figure17_pilot.m\`：验证配置、复用场景、checkpoint、诊断字段、绘图产物和禁止项。

不修改 \`simulate_lora_dynamic_doppler_ber_point\`，除非测试证明其结果字段不足以满足本轮输出；当前字段已覆盖所需指标。

## 原始数据、诊断与绘图

### 原始结果

\`dynamic_doppler_ber_pilot_results.csv\` 保存全部 336 点。每行保留现有 BER 点函数输出，包括 \`bit_errors\`、\`total_bits\`、\`ber\`、\`ber_upper_bound\`、场景起始 Doppler 与 Doppler rate、归一化偏移、批数、耗时、内存和 FFT 映射检查结果。

checkpoint 在每一个成功点后以完整表覆盖写入同一个 CSV；重新运行时只有完全匹配的 \`profile/orbit_scenario/time_mode/doppler_model/sf/snr_db\` 键才会被跳过。

### 诊断表

\`dynamic_doppler_ber_pilot_diagnostics.csv\` 为每个场景/SF 一行，包含：

- 初始 Doppler、Doppler rate、half-bin tolerance、归一化初始偏移和归一化 rate sweep；
- \`-30 dB\`、\`-10 dB\`、\`10 dB\` 的原始 BER；
- \`strict_monotonic_improvement\`：所有相邻原始 BER 均不增加；
- \`mc_tolerance_monotonic_improvement\`：以相邻点 Bernoulli 标准误差的 95% 合成界排除统计噪声后的趋势判断；
- \`monotonic_violation_count\`；
- \`estimated_high_snr_ber_floor\`：\`6/8/10 dB\` 三个原始 BER 的中位数；
- \`trend_assessment\` 和 \`required_checklist\`。

\`strict_monotonic_improvement\` 是按用户要求的原始值诊断。它可能因有限 Monte Carlo 统计出现轻微假阳性；因此同时保存容差版本，但两者都不修改任何仿真数据。

### 图像

\`dynamic_doppler_ber_figure17_pilot.png\` 有两个半对数 panel：

- (a) High Doppler Rate；
- (b) High Doppler Shift。

每个 panel 绘制 SF5–SF12 的原始 Monte Carlo 曲线。图中不平滑、不拟合、不加理论线、不对 SNR 平移，也不使用论文数字化曲线。对 \`bit_errors=0\` 的点，CSV 保持 \`ber=0\`；由于对数纵轴不能显示零，图上以空心下三角绘制已有 \`ber_upper_bound\`，并在图例/报告中明确为“零错误上界标记”，不将它解释为 Monte Carlo BER。

## 趋势预检与暂停规则

预检只诊断，不对结果施加校正。

- 对 high-rate 的 SF5–SF7，检查从 \`-30 dB\` 到 \`10 dB\` 是否存在显著改善；
- 对 high-rate 的 SF8–SF12，报告高 SNR floor 或改善有限；
- 对 high-shift，报告全范围差 BER 的程度；
- 若出现与预期相反的整体趋势，报告标记为 \`investigate_before_final_scan\`，不启动最终 Figure 17 扫描。

\`required_checklist\` 逐项列出：SNR/AWGN 方差、carrier/baseband Hz、弧度/角度、\`2*pi\`、\`cd\` 单位、每秒与每采样混用、chirp wrap 的 \`Delta_f_k\` 符号、FFT bin 方向、场景是否颠倒、连续时间推进、意外补偿，以及 \`B=125 kHz\` 误配。

## 内存与运行策略

继续使用现有 \`maxComplexSamplesPerBatch=2e6\` 和自动 batch size。每一批生成一组符号、波形、相位、噪声和 FFT 判决后立即累计，不保留跨批波形。每点已有 peak memory、estimated memory 和 elapsed time 字段；最终报告汇总最大值和最慢点。

全量 336 点中，高 SNR 的 low-SF high-rate 点可能达到 \`1e7 bit\` 上限，故预计总运行时间为数十分钟。checkpoint 是长运行可靠性的必要部分，不改变随机种子或物理模型。

## 验证范围

- 配置精确包含要求的网格和停止条件；
- 场景时刻等于 \`lora_figure17_geometry\` 的公式推导值，而非常数；
- 以缩小网格验证 runner 写入原始结果、续跑时不重复计算、生成图与诊断；
- 验证诊断字段从原始表计算，零 BER 不产生 NaN/Inf；
- 验证 pilot 生产文件不调用 AWGN order-statistic、人工 FFT bin shift、Doppler 补偿或 continuous mode；
- 完整执行新测试、既有 51 个回归测试以及 MATLAB Code Analyzer；
- MATLAB 实跑完整 336 点，并审核输出行数、键唯一性、异常值和趋势状态。

