# V4 与指定 SF11 project 的算法对应和修订记录

日期：2026-09-07。关联方案：`SF12无LDRO双轨完整实验V4方案_审计修订版.md`，标识 `V4-noLDRO-plan-R3-project-aligned`。

## 1. 唯一标准与核对范围

用户指定根目录：`D:\codex\Lora(eg)\project`。

规范Stage55子目录：`D:\codex\Lora(eg)\project\orbit_doppler\satellite_fig3_rolling8`。其CANONICAL_PROJECT.md及project/confidence_symbol_reproduction/README.md均明确该规范位置。当前核对基于实际源码字节，不以“最新修改时间”代替规范身份。

原R2列出的 `D:\codex\Lora(eg)\senlora_orbit_doppler\satellite_fig3_rolling8` 本次路径检查不存在，已从有效来源中撤销。早期orbit_doppler四前导demo、confidence_symbol_reproduction简化交织demo不作为Stage55主接收机标准。

本轮只修改方案与本记录；未修改任何MATLAB代码，未运行测试、标定、smoke或formal。交付前已复核project下211个MATLAB文件：文件数相同，改前/改后SHA-256差异为0。以下26个关键文件的哈希用于方案依据追溯，完整V4 source_manifest/依赖闭包仍由阶段0生成，不能将本表冒充完整运行签名。

## 2. 主调用链

```text
satelliteFig3SenLoRaVirtualPilotDecode (UseQualityAwareVirtualPilots=true)
  → satelliteFig3HuangPrecCpBootstrapEstimate
      → satelliteFig3BootstrapJointPhaseEstimate
  → satelliteFig3CrossFrameRateUpdate (有连续帧时间时)
  → satelliteFig3SenLoRaIterativeDecode
      → satelliteFig3RollingPilotTracker
          → satelliteFig3PhaseRotationEstimate
          → satelliteFig3HardDecision
      → satelliteFig3SenLoRaConfidence
      → satelliteFig3HardPayloadBits
```

Huang主控制：satelliteFig3HuangPrecCpMatchedDecode → satelliteFig3HuangPrecStaticCpDecode → 同一bootstrap/tracker以及共同confidence ML输出。旧satelliteFig3PaperPrecDecode是Huang论文直接复平均溯源代码，不是Farhat的Midamble-Point，不能因为名字含Paper就用错文献方法。

部分历史Stage48/50/52/消融入口显式使用UseQualityAwareVirtualPilots=false；V4应使用默认质量模式，而不是复制这些legacy选项。run_stage55_vp_mechanism_ablation中IncludeQualityMode=true与QualityFinalOnly=true可识别对应质量分支，不能默认运行其五路legacy消融当作新主项目。

## 3. 逐项算法对应

| 项目 | 指定project实际行为 | R3决定 |
|---|---|---|
| bootstrap | 8前导逐chirp FFT功率相加，eta/整数峰搜索 | 保留，eta步长独立标定 |
| 共同CFO | cfoBins八项均为epsilonHatBins | 保留，不替换成V3局部CFO曲线 |
| 前导相位 | 各前导去共同CFO后相干均值角 | 保留源时间约定并独立检验偏差 |
| 孤立帧rate | 当前前导joint phase quadratic fit | 恢复该回退，取消R2无条件0 |
| 跨帧1/2/3–8项 | 前导fallback/线性/二次拟合 | 保留，观测时刻为frameStart+4T |
| 帧内rolling-8 | 当前八前导先填满，VP替换最旧 | 恢复，不能只存VP空启动 |
| rate证据 | 本帧所有已接纳VP raw single CFO | 单独命名vpRateEvidence，≤112 |
| ≥8帧history | VP不覆盖跨帧rate，继续更新CFO中心 | 保留该默认quality策略 |
| VP稳定 | 两轮proposed且置信重编码符号一致 | 保留，不改为任意一次硬判决稳定 |
| VP标签 | tracker当前补偿后硬LoRa标签 | 保存实际使用标签及应用时间 |
| soft-hard agreement | 平方置信码字重编码与硬标签比较 | 不用最终ML码字替换 |
| 置信修正 | raw LLR、平方评分margin、mix、EMA | 保留数学式，维度改12 |
| 最终ML | raw bit LLR的线性签名码字评分 | 与置信平方评分分开 |
| 噪声估计 | unitary FFT；8前导排除bin0后均值 | 取消R2峰±2bin排除及默认clip |
| SNR门 | 主入口UseEstimatedSnrGate=false | 不启用config遗留的-16dB门 |
| 相位对 | 帧内连续预测相位+残余角，双门保护 | 不对两个累计相位各自取模再相减 |
| Doppler | -(fc+fBB[n])*vRad/c逐样本积分 | B保留full-RF近似，A保留载波模型 |
| BER序列 | MATLAB dataBits(:)列主序 | row最快、信息位列其次、block最后 |
| 源收敛退出 | >=2轮且nextMask==mask，全帧判据 | 先前缀因果测试，失败显式修复 |

### 固定结构与标定数值分离

源的maxIterations=5、historyLength=8、alpha=0.8、mix=0.5、thresholdScale=1是本轮对应基准。源中的0.22创新门、0.15 Huber、0.15 marginRatio、0.35/0.60融合增益、0.075 CFO标准差、0.1相位/速率门、2 bin/s最大rate等只是SF11来源值，不能当作SF12已冻结参数。实际候选组按机制、单位与预注册预算独立建立。

FFT幅度peak ratio和FFT能量ratio也不能混用：源hard detector为最大幅度/次大幅度；rotation estimator为相干幅度peak/候选背景中位数。V4须保持指标定义再标定阈值。

## 4. 与SF11保留的实验差异

| 维度 | 指定SF11 | V4 Track B |
|---|---|---|
| SF/BW/Fs | 11/250k/250k | 12/125k/125k |
| 数据维度/信息量 | 11行、704bit | 12行、768bit |
| CR/块数/数据符号 | CR3/16/112 | 相同 |
| 主信道 | AWGN+连续Doppler | 相同方向，保留full-RF积分 |
| Rician | 非该主生成器信道 | 独立补充，参数不另调优 |
| Paper方法 | 不能拿名为PaperPrec的Huang溯源代码替代Farhat | Farhat Midamble-Point adapted，37M |
| 帧时钟 | 120T | native120T/157T；controlled157T |
| 区域 | 部分源脚本按每帧drift≥0.5bin划分 | visible-all主区及10–30/30–50°补充分区 |
| 生成相位跨盲区 | inspected消融脚本可见段开始置0 | V4生成器跨盲区连续，receiver断观测重置 |
| 统计 | 源多种历史预算 | R3固定50pass/结果组，paired cluster CI |
| 发布时间 | 离线多轮接收机输出 | 必须补前缀测试与输出发布时间 |

这些是显式实验设计，不因“以project为标准”就把SF改回11、BW改回250k或取消用户指定的no-LDRO与双轨。A独立天顶轨道、120bit元数据/23标签及整数Paper-native保持不变。

单位核对：相同Hz/s下V4 bin/s为4倍，单符号Hz漂移为4倍，单符号bin漂移为16倍。不同门不能统一乘同一个倍数。

## 5. 尚需执行的准入证据

| 状态 | 项目 |
|---|---|
| 已完成静态核对 | 指定目录、规范入口、核心算法对应及本表哈希 |
| 待阶段0 | 全依赖闭包、论文PDF哈希/页码、V4实际文件source manifest |
| 待阶段1–4 | SF11同配置兼容对照、12bit golden vectors、完整raw-LLR/平方margin/ML测试 |
| 必须验证 | 全帧收敛退出的前缀因果性；不能据源有此逻辑就宣布已通过 |
| 必须验证 | 大CFO/长gap下相位双门、实际M时间间隔、前导rate回退数值稳定性 |
| 待阶段5 | full-RF共享参考phase与native自然phase的配对规则、盲区mask/geometry erasure |
| formal前 | 完整输出契约与恢复、成本估算、固定预算、版本拒绝续跑 |

源有潜在问题时，先展示独立反例，再在V4中作显式修正并更新参数/签名；不得修改标准project来让对照自动一致，亦不得放宽容差追逐通过。

## 6. 关键源码SHA-256

以下文件均相对规范Stage55子目录，哈希为本次读取实测值。

| 文件 | SHA-256 |
|---|---|
| satelliteFig3Config.m | `63c0d752a67bf594cddc51eab3490c76a4e8b153cd53a20f8f33402bbff9a563` |
| satelliteFig3SenLoRaVirtualPilotDecode.m | `26eff184d1bfc40df39e45e0b8722a04171138458d7d21c4cfd75dac18fd0740` |
| satelliteFig3HuangPrecCpBootstrapEstimate.m | `c0ec184220745f27d06e13ea8428ef09905e499918d59aeef2d4770fc4681985` |
| satelliteFig3BootstrapJointPhaseEstimate.m | `46c7ec378e24435f1b84fea8ebdfd5368f127eb502771a4db7488c274fa472f2` |
| satelliteFig3CrossFrameRateUpdate.m | `4ce3d9c5519bfb0ddd7b19b35c70fc11d0ac5cc8d0dc6c3ad5fc4f215553abad` |
| satelliteFig3RollingPilotTracker.m | `61806a40c35db896eeff31f314808f52063bfacce63ce22b984135d625f22047` |
| satelliteFig3SenLoRaIterativeDecode.m | `2b5a5192131c1004925990d6b2235d4624e5c8de699707f9374b4ebd690aca5d` |
| satelliteFig3SenLoRaConfidence.m | `e961ce4a1aeb47e244b331847b417854b77e8251a5c3f90cdd65d2bd7e76ba66` |
| satelliteFig3HuangPrecCpMatchedDecode.m | `120e37c724edaf561a6dd2dbb92cb9d8e7db4507f7a7e4a26989949c79fbebc5` |
| satelliteFig3HuangPrecStaticCpDecode.m | `50d0479758255638f3525e0914b9344b0b448005c7d37939803dbe12d77e70b2` |
| satelliteFig3PhaseRotationEstimate.m | `055daf8168a7eab57e964ed2461980131f082c860f9b5c6b3fa966a2957e588d` |
| satelliteFig3GeneratePayload.m | `65f10d10b911f47fcdb8cbd1304f3ff49d497927774fc107e46856a53cb17689` |
| satelliteFig3HardPayloadBits.m | `c6153dc53dd7f5ec017b605666b271d1025ffc569de4e24318b17652088fcd21` |
| satelliteFig3DiagonalInterleave.m | `f138e1da73148c55ab5a05639ec7bb63cd2de8f949c710346ab4f897e98bad64` |
| satelliteFig3DiagonalDeinterleave.m | `463d7157055a87b4444c30b1cc5fa41531e13be32c6ff006006d5bdad0868c2e` |
| satelliteFig3GrayEncode.m | `cd2e2f642833cc34ebed383e88fc3ccfff94ccdceac4b3c23808b275fb522108` |
| satelliteFig3GrayDecode.m | `8ca0466d712d072c14e40d2861aa4ed6550ffed1c50dffb4eae4f1e60524c034` |
| satelliteFig3ModulateSymbol.m | `04835fdd6078a3c79706f9e2c1c835e5fe863dc9c25502847e71d9d9544bce77` |
| satelliteFig3SymbolFrequency.m | `3267abeb9490dd13db6e67c87d6228d890fc0253b6fe9036087e793c8e72b3c4` |
| satelliteFig3HardDecision.m | `ceb061ecbeb45154f8f8e017ee1866871b4ba8a40896ad56ec1912de6a84d96b` |
| satelliteFig3Trajectory.m | `af72eff5aae69dd77a36e3de7c5ea858f05e34546b39e61420b06035e98a1c0b` |
| satelliteFig3VisibilityWindow.m | `2d12142b45c0eed3fe5a218adf146cff5c2707e82ae4f4491817825ce04916ef` |
| satelliteFig3ContinuousPassSchedule.m | `7d9cfa5edcc50f449a0abe53d6abe402ede08a5a93e565c0238037ce519a88c0` |
| generateContinuousSatelliteFrame.m | `b9b36e009f0566a10300ff36d42cde801fc45ae5f26249758fee9ba5ef6daa5b` |
| run_stage55_vp_mechanism_ablation.m | `46b6706d8987d84c2fcd91a13fa63c7481b93bb2b45508b76c47e1f652b84ff4` |
| runStage55ProjectTests.m | `967da494e674296547ae094057d25a25a0d0f582022d674c1d7eefcd3d3d5430` |

## 7. 文件修改范围

本次修改：
- comparison_experiments/SF12无LDRO双轨完整实验V4方案_审计修订版.md：R3原位修订；
- comparison_experiments/V4_SF11_PROJECT_ALIGNMENT.md：本对应记录。

不修改主任务中其他旧版方案、状态文件或V4代码骨架，避免侧对话写入干扰主任务。本R3和本记录应作为后续实现的明确输入；其他旧文档不自动获得同版身份。
