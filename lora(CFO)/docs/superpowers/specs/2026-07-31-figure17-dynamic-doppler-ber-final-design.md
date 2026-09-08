# Figure 17 正式动态 Doppler BER 扫描设计

## 目标

在已通过的粗网格预检之后，复用既有轨道、shared visibility window、动态 Doppler 相位与完整时域 BER 引擎，运行论文参考配置下的正式 Figure 17 Monte Carlo 扫描。正式结果是本项目仿真数据，不将论文图像或数字化曲线作为结果替代物。

## 主扫描配置

- profile：\`paper_figure17_reference\`；
- \`B=Fs=250e3 Hz\`、\`fc=868e6 Hz\`、\`SF=5:12\`；
- SNR：\`-30:1:10 dB\`。论文未公开 Figure 17 的 Monte Carlo SNR 步长，本项目明确声明该 1 dB 网格为项目选择；
- 场景：既有 \`high_doppler_rate\` 和 \`high_doppler_shift\`，仍由 \`lora_figure17_geometry\` 的 shared visibility window 自动选择；
- 时间模式：\`fixed_orbit_start_independent_symbols\`；
- 主模型：\`paper_piecewise_linear\`；
- 无干扰、无 Doppler 补偿，保持单位功率复基带 AWGN、理想符号边界、自然二进制映射与非相干 dechirp–FFT–argmax。

每点以 \`targetBitErrors=2000\` 或 \`maxBitsPerPoint=5e7\` 的先到条件停止；两个字段均可在正式配置中覆盖。不会按 BER 外观或趋势手动提前停止。

## 复用与最小扩展

继续直接复用：

- \`lora_figure17_geometry\`、\`lora_orbit_doppler_trajectory\`、\`lora_doppler_piecewise_linear\`；
- \`simulate_lora_dynamic_doppler_ber_point\` 的完整时域链路；
- \`lora_css_modulate\` 与 \`lora_css_demodulate\`。

新增正式配置、runner、配对 exact 抽查和正式测试文件。通用 BER 点函数只增加可选的分层种子覆盖及可选的配对诊断输出，不改变缺省种子行为、pilot 行为或 AWGN 基准。

## 零错误与原始结果

内部 BER 引擎继续使用原始比值 \`bit_errors/total_bits\`，以免影响既有调用方。正式 runner 写出 CSV 时，对 \`bit_errors=0\` 的行写入：

- \`ber=NaN\`；
- \`one_count_level=1/total_bits\`；
- \`upper_95_approx=-log(0.05)/total_bits\`。

报告明确：\`one_count_level\` 只是“一错误计数水平”，不是严格统计上界。CSV 始终保留 \`bit_errors\`、\`total_bits\`、\`symbol_errors\`、\`total_symbols\` 和停止原因。

## 分层种子与 exact 配对

主扫描的种子继续为场景、SF、SNR、批次和流角色的确定性函数；符号和 AWGN 使用独立随机流，种子写入 CSV。

exact 抽查的 24 点为每个场景的 SF \`[5,7,8,12]\` 与 SNR \`[-10,0,10]\`。paper/exact 在每个批次使用同一 transmitted-symbol 流和同一 AWGN 流。共同批次策略为：

1. 两模型锁步读取相同的下一批符号和噪声；
2. 任一模型先达到自身阈值后仍继续累计；
3. 直到两模型都达到 2000 bit errors，或共同达到 \`5e7 bit\` 上限。

这保留 paired Monte Carlo 样本对应关系。抽查会保存 BER、SER、bit/symbol 错误计数、无噪声 FFT 峰值与能量分布差异、最大符号内 Doppler 误差和 RMS phase error。

一致性门限为 \`max(3*combined_standard_error, 0.1*max(BER_piecewise,BER_exact))\`，其中 10% 相对项只在任一 BER 大于 \`1e-3\` 时启用。失败点逐条报告，不平滑或隐藏。

## 输出与图形

生成：

- \`dynamic_doppler_ber_results.csv\`；
- \`dynamic_doppler_ber_figure17.png\` 与 \`.pdf\`；
- \`dynamic_doppler_ber_metadata.json\`；
- \`dynamic_doppler_ber_report.md\`；
- 另存 exact 抽查 CSV/报告，供主报告引用。

主图只含两个 panel：(a) High Doppler Rate、(b) High Doppler Shift。每 panel 绘制 SF5–SF12 的本项目原始 Monte Carlo 点与连线；y 轴为对数；标题写明 no interference、no Doppler compensation。零错误点以 \`upper_95_approx\` 的空心下三角显示，并在图注中说明它是图形可见性标记而非 BER 值。

报告以中文说明论文没有完整公开 Figure 17 的接收机和 SNR 细节、本项目假设以及与论文趋势的任何差异。不得改变 Doppler、SNR 定义或噪声方差去拟合论文。

## 验证

- 单元测试：正式配置、零错误映射、种子可复现与分离、主 runner checkpoint、主图/PDF/metadata、配对 exact 的相同输入与比较门限；
- 回归测试：所有已有 AWGN、轨道、动态信道、近似、smoke 和 pilot 测试；
- MATLAB 实跑：656 个主点与 24 个 paired exact 点；
- 审核：原始计数、键唯一性、NaN 仅在零错误 BER 字段、无空批/非法 FFT bin、内存批处理上限、趋势及 exact 差异。

