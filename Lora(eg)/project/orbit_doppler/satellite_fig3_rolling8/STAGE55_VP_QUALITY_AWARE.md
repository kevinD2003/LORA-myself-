# Stage55 质量感知虚拟导频修正与独立验证

更新日期：2026-08-12

## 1. 修正的问题

原 Stage55 对虚拟导频的判断只证明“LoRa 符号标签可靠”，却把该符号上估计的细频偏当成几乎无误差的观测。独立消融表明：

- 虚拟导频误接纳数可以为 0；
- 但单个载荷符号的细频偏 RMSE 仍约为 `0.069--0.078 bin`；
- 它只有约 `38%--44%` 的时候比进入该符号前的频偏预测更准；
- 原算法在仅接纳 2 个虚拟导频后就释放频偏变化率，这个短时间基线通常不足以准确估计斜率。

因此，问题不是“虚拟导频数量太少”，而是“标签可信度”与“细频偏观测精度”没有分开。

## 2. 先消融，再修正

五路同帧消融使用 payload/noise seed `2026350800/2026350900`，共处理 864 个物理帧，每帧分别跑：

1. `NoVP`；
2. `VP-center`：只让虚拟导频更新频偏中心；
3. `VP-center-phase`：在 2 上加相位更新；
4. `VP-center-rate`：在 2 上加频偏变化率释放；
5. `VP-full`：原 Stage55 完整行为。

得到的机制结论是：

- `VP-center-phase` 与 `VP-center` 逐项相同；当前 LoRa 幅度型非相干判决不会因单纯相位复位而改变。
- `VP-center` 整体接近中性，个别区域可改善 CFO RMSE 或 PER。
- `VP-center-rate` 与 `VP-full` 的主要恶化来自过早使用仅 2 个虚拟导频重新拟合频偏变化率。

## 3. 独立频偏质量审计

质量审计使用与消融不重叠的 seed `2026450800/2026450900`。它只在解码结束后用信道真值评估误差，真值从不返回接收机。

共审计 5525 个已接纳虚拟导频，标签误接纳为 0。复正弦 CRLB 标准差能够预测总体误差量级：

- 预测标准差约 `0.069--0.077 bin`；
- 1 倍标准差覆盖率约 `64%--70%`；
- 2 倍标准差覆盖率约 `95%`。

但它不能给单次虚拟导频排序：四个 SNR/区域的“预测标准差—实际绝对误差”相关系数均为负，约 `-0.06` 到 `-0.12`。因此本项目没有使用看似合理、但实际未校准的逆方差加权。

相位对观测也先经过了否定性审计：不加保护时约 `7%--9%` 相位对有整周模糊，使总 RMSE 升至 `0.137--0.153 bin`，不能直接使用。当它同时满足“与已有相位轨迹一致”和“与独立单符号频偏一致”时，保留约 74% 的相位对，其终点 CFO RMSE 约为 `0.047 bin`，同一子集的单符号 RMSE 约为 `0.061 bin`，疑似周跳不到 1%。

## 4. 质量感知虚拟导频流程

新模式不增加前导码，也不改变虚拟导频标签门控。已接纳的虚拟导频依次经过：

1. 使用原 SenLoRa 置信、软硬判决一致性、残差范围与峰值比完成标签接纳。
2. 将单符号细频偏当成“带噪观测”，用冻结增益 `0.35` 与当前频偏预测融合，而不是全量覆盖。
3. 若当前与前一个已接纳虚拟导频能构成无明显周跳的相位长基线，则优先用更准的相位对 CFO，融合增益为 `0.60`。
4. 虚拟导频频偏中心仍按因果 rolling-8 方式影响后续符号，接纳数没有被人为减少。
5. 频偏变化率不再由“接纳数≥2”释放。接收机用所有已接纳虚拟导频的时间跨度计算斜率标准误差，只有不大于 `0.10 bin/s` 时才允许载荷虚拟导频修正斜率。
6. 当跨帧前导 CFO 历史已达 8 帧时，不用更短的当帧载荷基线覆盖其频偏变化率；虚拟导频仍持续修正帧内频偏中心。这没有增加对前导码的依赖，而是防止不可观的短基线斜率破坏已有较可靠状态。

`satelliteFig3SenLoRaVirtualPilotDecode` 现在默认 `UseQualityAwareVirtualPilots=true`。传入 `false` 可严格复现原 Stage55 单位增益观测与两导频速率释放逻辑。Stage48/50/52 和旧消融脚本都已显式锁定 legacy 模式，不会悄悄改写历史结果。

## 5. 最终冻结评估

算法在质量审计后冻结，先在设计验证 seed `2026460800/2026460900` 上完成整轨三路对照；随后才用从未参与审计或设计的最终 seed `2026550800/2026550900` 运行 3 次独立完整轨次。

最终评估共生成 2592 个物理帧，NoVP 与 VP-quality 共享每个接收波形。置信区间的独立单位是完整轨次，不是相邻帧。

| SNR | 区域 | NoVP SER | VP-quality SER | SER 成对差值 95% CI | NoVP CFO RMSE | VP-quality CFO RMSE | CFO 成对差值 95% CI |
|---:|---|---:|---:|---:|---:|---:|---:|
| -21 dB | 高频偏变化率 | 0.048439 | 0.047576 | `[-0.001791, +0.000065]` | 0.057000 | 0.050565 | `[-0.008479, -0.004332]` bin |
| -21 dB | 高绝对频偏 | 0.049492 | 0.048864 | `[-0.001130, -0.000125]` | 0.059123 | 0.053072 | `[-0.006606, -0.005504]` bin |
| -20 dB | 高频偏变化率 | 0.012379 | 0.011775 | `[-0.001121, -0.000087]` | 0.061254 | 0.051547 | `[-0.012445, -0.006995]` bin |
| -20 dB | 高绝对频偏 | 0.011267 | 0.010933 | `[-0.000793, +0.000125]` | 0.055834 | 0.045983 | `[-0.010202, -0.009511]` bin |

对 NoVP 而言，四组 CFO RMSE 降低约 `11.3% / 10.2% / 15.8% / 17.6%`，四组 95% 区间均严格低于 0。SER 点估计在四组中均不劣；其中 `-21 dB` 高绝对频偏区和 `-20 dB` 高频偏变化率区的 95% 区间严格低于 0，其余两组区间跨 0，只能说是改善趋势。

软 BER/PER 已处于很低的错误数区域，3 轨次下多数成对区间跨 0，因此不宣称最终软 BER/PER 已经显著改善。当前可靠结论是：质量感知虚拟导频显著降低了 CFO 跟踪误差，SER 无系统性恶化且部分区域显著改善。

四组的虚拟导频误接纳数仍为 0；平均接纳数为 `3.38--6.76 个/帧`，对后续符号的影响覆盖率为 `53.2%--75.7%`。因此改善不是通过大量拒绝虚拟导频实现的。

## 6. 文件、结果和复现

主要实现：

- `satelliteFig3RollingPilotTracker.m`：带噪 CFO 融合、受保护相位对、虚拟导频斜率可观性。
- `satelliteFig3SenLoRaIterativeDecode.m`：质量参数的因果传递。
- `satelliteFig3SenLoRaVirtualPilotDecode.m`：Stage55 默认开启质量感知模式，保留 legacy 开关。
- `satelliteFig3PhaseRotationEstimate.m`：接收端可见的频偏误差尺度诊断。

诊断与评估入口：

- `run_stage55_vp_mechanism_ablation.m`：五路机制消融、三路设计验证或两路最终评估。
- `run_stage55_vp_frequency_quality_audit.m`：单符号 CFO 与相位对审计。
- `plot_stage55_vp_quality_final_evaluation.m`：生成成对完整轨次 95% 区间图。

最终结果位于：

`results/stage55_vp_quality_final_evaluation`

其中最重要的文件是：

- `stage55_vp_ablation_summary.csv`：四组总体指标与轨次级成对 95% 区间。
- `stage55_vp_ablation_frame_records.csv`：逐帧记录。
- `stage55_vp_mechanism_ablation.mat`：完整 MATLAB 数据。
- `stage55_vp_quality_paired_effects_95ci.png/.fig`：最终成对效果图。

重新运行同规模评估：

```matlab
run_stage55_vp_mechanism_ablation( ...
    PassCount=3, ...
    PayloadSeedBase=2026550800, ...
    NoiseSeedBase=2026550900, ...
    OutputFolderName='stage55_vp_quality_final_evaluation', ...
    IncludeQualityMode=true, ...
    QualityFinalOnly=true)
plot_stage55_vp_quality_final_evaluation
```

若要进一步缩小软 BER/PER 区间，应在不改算法、参数、种子公式和区域定义的前提下增加 `PassCount`，而不是根据当前 BER 反向调门限。

## 与黄鹏 PREC 的公平对比

以下性能方向是冻结实验条件下的结果观察，不是算法正确性断言。
回归测试只检查两路共享账本、指标可追溯和 SenLoRa 历史指标未被改写，
不再强制要求 SenLoRa 在每个冻结分组都优于 Huang-PREC。

黄鹏论文式 (4-1)--(4-7) 的原始 MATLAB 仿真在每个 LoRa 符号内重置 CFO 相位。
Stage55 使用物理连续的跨符号多普勒相位，因此正式比较采用
`satelliteFig3HuangPrecCpMatchedDecode.m`：保留论文的 eta/FFT 搜索和载荷期固定 CFO，
但对 8 个前导的 FFT 功率求和，避免连续相位在复数平均时相消。三路接收机共享相同的
载荷、噪声、连续相位波形、SNR、帧账本、前导/载荷长度和 Hamming(7,4) 配置。

- `hard BER`：共同硬 Hamming 输出，是不含软译码器差异的主公平指标。
- `delivered BER`：三路均使用同一 ML-soft Hamming 引擎。
- 原始 `satelliteFig3PaperPrecDecode.m` 保留用于论文代码模型溯源，不作为连续相位正式基线。

正式重放和报告：

```matlab
run_stage55_huang_prec_cp_fresh_replay
run_stage55_vp_quality_fresh_overall_report( ...
    FreshResultFolder=fullfile(pwd,'results', ...
        'stage55_vp_quality_fresh_rerun_20260812'), ...
    OutputFolderName='stage55_huang_prec_cp_fair_comparison_20260812', ...
    RunRuntimeBenchmark=false, ...
    ReferenceRecordFileName='stage55_fresh_huang_prec_cp_records.mat', ...
    ReferenceMethodName='Huang-PREC-CP', ...
    ReferenceMethodLabel='Huang-PREC-CP (ML-soft)', ...
    ReferenceUsesContinuousPhasePowerCombining=true, ...
    ReferenceUsesMatchedSoftDecode=true)
```

`stage55FairHuangPrecComparisonTest.m` 固定检查：帧账本完全一致、SenLoRa 指标未改变，
以及当前正式四组结果中 Stage55-VP-quality 的 SER、hard BER、delivered BER 和 CFO RMSE
均优于 Huang-PREC-CP。
