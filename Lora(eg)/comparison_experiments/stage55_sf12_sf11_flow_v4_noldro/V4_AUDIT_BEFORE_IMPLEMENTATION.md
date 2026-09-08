# V4 实现前审计

审计日期：2026-09-07

审计范围：`stage55_sf12_sf11_flow_v4_noldro` 当前骨架、修订版方案、V2/V3/SF11 只读边界。

## A. 审计结论

结论：R3 方案身份已冻结；实现层仍有多项 NEEDS_CHANGE。当前禁止 calibration、validation、smoke 和 formal。

盘点：V4 共 86 个 MATLAB 文件，其中 34 个是冻结 SF11 来源副本；V4 `results` 中没有文件。活动代码是 V3 的机械改名副本，尚未完成 no-LDRO 适配。

## B. PASS

| 项目 | 状态 | 证据/说明 |
|---|---|---|
| V4 独立目录 | PASS | 未覆盖 V2/V3/SF11 |
| 历史结果隔离 | PASS | V4 results 文件数为 0 |
| SF11 来源快照 | PASS | `src/upstream_sf11` 有 34 个冻结文件 |
| 双轨身份 | PASS | 修订方案分开 Track A/Track B |
| Paper 身份 | PASS | 方案已区分 native/adapted |
| 两种公平口径 | PASS | controlled-time/native-overhead 已分开 |
| Rician 相位理论 | PASS | 方案已区分 Doppler phase 与 `angle(h_k)` |
| 统计单位 | PASS | Track A=packet，Track B=complete pass |
| 性能中立 | PASS | 无 Stage55 必须领先的门 |
| 大规模运行 | PASS | 本轮未运行 calibration/formal |

## C. NEEDS_CHANGE

| 项目 | 状态 | 当前问题 |
|---|---|---|
| no-LDRO 配置 | NEEDS_CHANGE | `effectiveDataSf=10` 仍残留 |
| 标签空间 | NEEDS_CHANGE | validator/test 仍要求 1024、spacing=4 |
| 软解调 | NEEDS_CHANGE | `v4SymbolLikelihood` 仍聚合 1024 个 LDRO 区域 |
| Payload 映射 | NEEDS_CHANGE | 仍通过 `logicalBins*dataBinSpacing` 间接映射 |
| CR3 维度测试 | NEEDS_CHANGE | 仍断言 10×7×16、640 bit |
| 独立 golden vectors | NEEDS_CHANGE | 当前只有同源 TX→RX roundtrip |
| Track A 代码 | NEEDS_CHANGE | 当前目录没有独立 paper-anchor 实现 |
| Paper-native estimator | NEEDS_CHANGE | 当前 Paper 代码调用 sub-bin rotation estimator |
| Paper-Point 基线 | NEEDS_CHANGE | 未实现 |
| No-Doppler 基线 | NEEDS_CHANGE | 未形成 Track A 独立诊断入口 |
| controlled-time | NEEDS_CHANGE | 仍使用单一共同 raw frame 设计 |
| native-overhead | NEEDS_CHANGE | 未实现自然帧调度和独立结果目录 |
| 时间 manifest | NEEDS_CHANGE | 缺 scheduleType/frameStartTimes/interFrameGap |
| Rician phase 审计 | NEEDS_CHANGE | 现有测试只验证 Doppler phase bridge，未注入包间 `angle(h_k)` 跳变 |
| 参数 manifest | NEEDS_CHANGE | V4 独立 manifest 尚不存在 |
| source manifest | NEEDS_CHANGE | V4 派生来源和哈希尚未生成 |
| 种子域 | NEEDS_CHANGE | 活动代码仍携带 V3 seed bases |
| 正式统计 | NEEDS_CHANGE | copied formal 仍是 min 5/max 20 passes、2000 bootstrap |
| 报告身份 | NEEDS_CHANGE | copied report 仍是 V3 单轨结构 |
| auditV4 | NEEDS_CHANGE | copied audit 依赖尚不存在的旧式结果结构 |

## D. BLOCKER

`BLOCKER = 0` 仅指无需用户补充方案决策；任何未通过的实施阶段均构成后续阶段准入阻塞。

已在方案层解决：Paper-native/adapted 身份、Midamble raw-sample 公平性冲突、双时间轴、显式 frame timing、Rician phase jump、Track A 指标边界、golden-vector 独立性和 cluster 统计规则。

注意：BLOCKER 为 0 只表示可以按阶段开始实现，不表示当前代码可以运行实验。所有 NEEDS_CHANGE 必须按阶段门完成。

## E. 需要修改的现有文件

配置：

- `config/sf12NoLdroSf11FlowConfig.m`
- `config/v4ValidateConfig.m`
- `config/v4LoadFrozenReceiverParameters.m`

公共 PHY/编码：

- `src/phy/v4SymbolLikelihood.m`
- `src/phy/v4BuildFrameLayout.m`
- `src/phy/v4GenerateContinuousFrame.m`
- `src/phy/v4ContinuousPassSchedule.m`
- `src/coding/v4GeneratePayload.m`
- `src/coding/v4DecodePayload.m`
- `src/coding/v4DiagonalInterleave.m`
- `src/coding/v4DiagonalDeinterleave.m`

Track B 接收机与统计：

- `src/stage55/v4DecodeThreeMethods.m`
- `src/stage55/v4Stage55Decode.m`
- `src/stage55/v4RollingTrackerPass.m`
- `src/paper/v4PaperMidambleDecode.m`
- `src/statistics/v4RunCompletePass.m`
- `src/statistics/v4RunFormalSnrPoint.m`
- `src/statistics/v4RandomLedger.m`

入口：

- `scripts/runV4Tests.m`
- `scripts/runV4MechanismCalibration.m`
- `scripts/runV4ContinuousPassSmoke.m`
- `scripts/runV4FormalComparison.m`
- `scripts/buildV4Report.m`
- `scripts/auditV4.m`

现有四个测试文件全部需要改写 no-LDRO 断言。

## F. 需要新增的文件

配置与 manifest：

- `config/commonNoLdroConfig.m`
- `config/paperNoLdroConfig.m`
- `config/flowNoLdroConfig.m`
- `config/paperReceiverParameterManifest.json`
- `config/flowReceiverParameterManifest.json`
- `config/source_manifest.json`
- `config/frameTimingManifest.json`

Track A：

- `src/paper_anchor/v4PaperNativePointEstimate.m`
- `src/paper_anchor/v4PaperNativeMidambleDecode.m`
- `src/paper_anchor/v4PaperPointBaseline.m`
- `src/paper_anchor/v4PaperNoDopplerBaseline.m`
- `src/paper_anchor/v4GeneratePaperAnchorPacket.m`
- `src/paper_anchor/v4RunPaperPairedPacket.m`

双时间轴：

- `src/phy/v4ControlledTimeSchedule.m`
- `src/phy/v4NativeOverheadSchedule.m`
- `src/phy/v4RandomRealizationLedger.m`
- `src/statistics/v4NativeOverheadMetrics.m`

新测试：

- `tests/V4IndependentChirpGoldenVectorTest.m`
- `tests/V4GrayInterleaverGoldenVectorTest.m`
- `tests/V4NoLdroDimensionTest.m`
- `tests/V4PaperNativeEstimatorIsolationTest.m`
- `tests/V4PaperAnchorDiagnosticTest.m`
- `tests/V4ControlledTimeFairnessTest.m`
- `tests/V4NativeOverheadScheduleTest.m`
- `tests/V4FrameTimingManifestTest.m`
- `tests/V4RicianPhaseBoundaryTest.m`
- `tests/V4ReceiverCausalityTest.m`
- `tests/V4ClusterStatisticsTest.m`
- `tests/V4SeedDomainTest.m`
- `tests/V4CheckpointSignatureTest.m`

独立入口：

- `scripts/runV4PaperCalibration.m`
- `scripts/runV4FlowCalibration.m`
- `scripts/runV4PaperSmoke.m`
- `scripts/runV4ControlledTimeSmoke.m`
- `scripts/runV4NativeOverheadSmoke.m`
- `scripts/runV4PaperFormal.m`
- `scripts/runV4ControlledTimeFormal.m`
- `scripts/runV4NativeOverheadFormal.m`

## G. 测试门

以修订方案第 16 节的 22 项为强制门。特别强调：

- 4096/4096 roundtrip 与独立 golden vectors 必须同时通过；
- 第 11、12 bit 必须有人工构造的翻转测试；
- Paper-native 测试必须证明调用图中没有 sub-bin estimator；
- controlled-time 只验证公共 D 时刻和随机账本映射，不比较整帧 raw array；
- Rician boundary 测试必须随机改变 `angle(h_k)` 并证明跨帧 CFO/rate 不被当作 Doppler phase jump；
- cluster bootstrap 必须以完整 pass 为唯一 Track B 重采样单位。

## H. Statistical protocol

Track A：每 Case/SNR 固定 20000 paired packets，250 包 checkpoint；完成后计算 CI，不允许 precision stopping。

Track B：每 channel×mode×SNR 固定 50 complete passes，每个完整 pass checkpoint；完成后做 10000 次 paired-cluster bootstrap，不允许 precision stopping。

## I. Implementation order

1. 生成 source/config/timing manifest 骨架并冻结边界；
2. 完成公共 no-LDRO PHY 和独立 golden vectors；
3. 完成 12-row CR3、768-bit 硬/软编码链；
4. 完成 Track A Paper-native 和两个诊断基线；
5. 完成 Track B 三方法及因果门；
6. 完成 controlled-time/native-overhead 双调度；
7. 完成 Rician phase boundary 与恢复测试；
8. 完成 Track A/Track B 独立 calibration/validation；
9. 只运行小规模 smoke；
10. 所有门通过后才建议 formal。

## J. 仍未解决的问题

理论和统计设计问题：无 BLOCKER。

实现问题：上述 NEEDS_CHANGE 尚未执行。尤其是当前活动配置仍为 10-bit/1024/spacing-4，因此任何当前 V4 数值运行都无效，禁止把复制骨架的输出当作 no-LDRO 结果。
