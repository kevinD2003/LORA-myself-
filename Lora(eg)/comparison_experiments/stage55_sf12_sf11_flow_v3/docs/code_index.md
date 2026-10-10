# SF12 / LDRO V3：源码功能索引

[项目入口](../README.md) · [结果索引](result_index.md)

文件按功能分类，链接指向实际源码位置；名称与目录保留原样。描述取源码开头注释，完整行为以源码和测试为准。

## Midamble-Point 接收机（1）

| 文件 | 内容 |
|---|---|
| [v3PaperMidambleDecode.m](../src/paper/v3PaperMidambleDecode.m) | Known Midamble, n_int=3, cumulative residual CFO. |

## Stage55 与 PREC 接收机（7）

| 文件 | 内容 |
|---|---|
| [v3CrossFrameRateUpdate.m](../src/stage55/v3CrossFrameRateUpdate.m) | Receiver-visible causal rolling-8 preamble CFO fit. |
| [v3DecodeThreeMethods.m](../src/stage55/v3DecodeThreeMethods.m) | Run the three fixed V3 branches on one observation. |
| [v3HuangStaticDecode.m](../src/stage55/v3HuangStaticDecode.m) | Common-bootstrap fixed-CFO control receiver. |
| [v3RollingTrackerPass.m](../src/stage55/v3RollingTrackerPass.m) | One causal replay with an eight-observation history. |
| [v3Stage55Confidence.m](../src/stage55/v3Stage55Confidence.m) | Block-causal soft-Hamming confidence and EMA gate. |
| [v3Stage55Decode.m](../src/stage55/v3Stage55Decode.m) | Up to five confidence replays with hard-label VPs. |
| [v3ValidateReceiverParameters.m](../src/stage55/v3ValidateReceiverParameters.m) | Validate mechanism parameters without freezing them. |

## 冻结 SF11 来源快照（34）

| 文件 | 内容 |
|---|---|
| [generateContinuousSatelliteFrame.m](../src/upstream_sf11/generateContinuousSatelliteFrame.m) | Exact full-RF dynamic-Doppler CSS frame. |
| [satelliteFig3ApplyConfidenceGate.m](../src/upstream_sf11/satelliteFig3ApplyConfidenceGate.m) | Apply trained, receiver-only pilot gate. |
| [satelliteFig3BerInterval95.m](../src/upstream_sf11/satelliteFig3BerInterval95.m) | Binomial BER display value and 95% bounds. |
| [satelliteFig3BootstrapEstimate.m](../src/upstream_sf11/satelliteFig3BootstrapEstimate.m) | Joint large-CFO acquisition from known pilots. |
| [satelliteFig3BootstrapJointPhaseEstimate.m](../src/upstream_sf11/satelliteFig3BootstrapJointPhaseEstimate.m) | Joint CFO/rate from pilot phase. |
| [satelliteFig3Config.m](../src/upstream_sf11/satelliteFig3Config.m) | Single-device Figure 3 LoRa satellite configuration. |
| [satelliteFig3ContinuousPassSchedule.m](../src/upstream_sf11/satelliteFig3ContinuousPassSchedule.m) | Contiguous complete frames in one pass. |
| [satelliteFig3CrossFrameRateUpdate.m](../src/upstream_sf11/satelliteFig3CrossFrameRateUpdate.m) | Causal rolling-8 frame-rate state. |
| [satelliteFig3DiagonalDeinterleave.m](../src/upstream_sf11/satelliteFig3DiagonalDeinterleave.m) | Inverse LoRa cyclic diagonal interleaver. |
| [satelliteFig3DiagonalInterleave.m](../src/upstream_sf11/satelliteFig3DiagonalInterleave.m) | LoRa cyclic diagonal interleaver. |
| [satelliteFig3GeneratePayload.m](../src/upstream_sf11/satelliteFig3GeneratePayload.m) | Make coded, diagonally-interleaved CSS payload. |
| [satelliteFig3GrayDecode.m](../src/upstream_sf11/satelliteFig3GrayDecode.m) | Gray-code integer to binary integer. |
| [satelliteFig3GrayEncode.m](../src/upstream_sf11/satelliteFig3GrayEncode.m) | Binary integer to Gray-code integer. |
| [satelliteFig3HardDecision.m](../src/upstream_sf11/satelliteFig3HardDecision.m) | Dechirp and map MATLAB FFT bin to CSS labels. |
| [satelliteFig3HardPayloadBits.m](../src/upstream_sf11/satelliteFig3HardPayloadBits.m) | Hard Hamming decode for the no-compensation arm. |
| [satelliteFig3HardPrecDecode.m](../src/upstream_sf11/satelliteFig3HardPrecDecode.m) | Hard-decision rolling-8 PREC receiver. |
| [satelliteFig3HuangPrecCpBootstrapEstimate.m](../src/upstream_sf11/satelliteFig3HuangPrecCpBootstrapEstimate.m) | Continuous-phase Huang PREC. |
| [satelliteFig3HuangPrecCpMatchedDecode.m](../src/upstream_sf11/satelliteFig3HuangPrecCpMatchedDecode.m) | Fair Huang-PREC comparison arm. |
| [satelliteFig3HuangPrecStaticCpDecode.m](../src/upstream_sf11/satelliteFig3HuangPrecStaticCpDecode.m) | Static Huang-PREC CP baseline. |
| [satelliteFig3ModulateSymbol.m](../src/upstream_sf11/satelliteFig3ModulateSymbol.m) | Unit-power discrete-time LoRa CSS up-chirp. |
| [satelliteFig3PaperPrecDecode.m](../src/upstream_sf11/satelliteFig3PaperPrecDecode.m) | Thesis PREC with one CFO estimate per frame. |
| [satelliteFig3PhaseRotationEstimate.m](../src/upstream_sf11/satelliteFig3PhaseRotationEstimate.m) | Signed CFO/residual estimate by rotation. |
| [satelliteFig3PiecewiseDoppler.m](../src/upstream_sf11/satelliteFig3PiecewiseDoppler.m) | Exact full-RF Doppler and Eq. (18)-(20) proxy. |
| [satelliteFig3PilotConfidenceFeatures.m](../src/upstream_sf11/satelliteFig3PilotConfidenceFeatures.m) | Receiver-visible virtual-pilot features. |
| [satelliteFig3QualityGatedSenLoRaDecode.m](../src/upstream_sf11/satelliteFig3QualityGatedSenLoRaDecode.m) | SNR-independent rolling-8 SenLoRa. |
| [satelliteFig3RollingPilotTracker.m](../src/upstream_sf11/satelliteFig3RollingPilotTracker.m) | Causal 8-slot virtual-pilot Doppler tracker. |
| [satelliteFig3SenLoRaConfidence.m](../src/upstream_sf11/satelliteFig3SenLoRaConfidence.m) | SenLoRa soft confidence on 7-symbol blocks. |
| [satelliteFig3SenLoRaIterativeDecode.m](../src/upstream_sf11/satelliteFig3SenLoRaIterativeDecode.m) | Five-pass SenLoRa confidence iteration. |
| [satelliteFig3SenLoRaVirtualPilotDecode.m](../src/upstream_sf11/satelliteFig3SenLoRaVirtualPilotDecode.m) | No-orbit-prior SenLoRa path. |
| [satelliteFig3Stage52WriteArtifacts.m](../src/upstream_sf11/satelliteFig3Stage52WriteArtifacts.m) | Formal complete-pass-only products. |
| [satelliteFig3SymbolFrequency.m](../src/upstream_sf11/satelliteFig3SymbolFrequency.m) | Wrapped instantaneous complex-baseband CSS frequency. |
| [satelliteFig3Trajectory.m](../src/upstream_sf11/satelliteFig3Trajectory.m) | Exact circular-orbit single-device trajectory. |
| [satelliteFig3TwoTierPilotDecision.m](../src/upstream_sf11/satelliteFig3TwoTierPilotDecision.m) | Immediate and quarantined pilot classes. |
| [satelliteFig3VisibilityWindow.m](../src/upstream_sf11/satelliteFig3VisibilityWindow.m) | Figure 3 two-lobe single-device window. |

## 回归测试（8）

| 文件 | 内容 |
|---|---|
| [Sf12LdroCr3Test.m](../tests/Sf12LdroCr3Test.m) | MATLAB 测试类 |
| [V3CalibrationArtifactTest.m](../tests/V3CalibrationArtifactTest.m) | MATLAB 测试类 |
| [V3CommonBootstrapTest.m](../tests/V3CommonBootstrapTest.m) | MATLAB 测试类 |
| [V3ContinuousFrameTest.m](../tests/V3ContinuousFrameTest.m) | MATLAB 测试类 |
| [V3FormalArtifactTest.m](../tests/V3FormalArtifactTest.m) | MATLAB 测试类 |
| [V3ReportArtifactTest.m](../tests/V3ReportArtifactTest.m) | MATLAB 测试类 |
| [V3SmokeArtifactTest.m](../tests/V3SmokeArtifactTest.m) | MATLAB 测试类 |
| [V3ThreeReceiverTest.m](../tests/V3ThreeReceiverTest.m) | MATLAB 测试类 |

## 实验、报告与维护入口（7）

| 文件 | 内容 |
|---|---|
| [auditV3.m](../scripts/auditV3.m) | Unified final self-audit for source, tests, formal artifacts, and scope. |
| [buildV3Report.m](../scripts/buildV3Report.m) | Build formal tables, pass-paired intervals, plots, and report. |
| [runV3ContinuousPassSmoke.m](../scripts/runV3ContinuousPassSmoke.m) | One complete paired pass, wiring evidence only. |
| [runV3FormalComparison.m](../scripts/runV3FormalComparison.m) | Preregistered paired complete-pass SNR experiment. |
| [runV3MechanismCalibration.m](../scripts/runV3MechanismCalibration.m) | Calibrate SF12 units without formal SER curves. |
| [runV3Tests.m](../scripts/runV3Tests.m) | Run the currently implemented V3 regression gates. |
| [v3SetupPaths.m](../scripts/v3SetupPaths.m) | Add only V3 implementation paths, excluding frozen SF11 code. |

## 物理层与信道（15）

| 文件 | 内容 |
|---|---|
| [v3BootstrapJointPhaseEstimate.m](../src/phy/v3BootstrapJointPhaseEstimate.m) | Quadratic phase fit on eight known upchirps. |
| [v3BootstrapStateAtSymbol.m](../src/phy/v3BootstrapStateAtSymbol.m) | Extrapolate the receiver-only quadratic fit. |
| [v3BuildFrameLayout.m](../src/phy/v3BuildFrameLayout.m) | Common bootstrap/data/Midamble physical timeline. |
| [v3CommonBootstrap.m](../src/phy/v3CommonBootstrap.m) | Shared receiver-visible eight-upchirp initialization. |
| [v3CompensateSymbol.m](../src/phy/v3CompensateSymbol.m) | Continuous phase, CFO, and linear-rate compensation. |
| [v3ContinuousPassSchedule.m](../src/phy/v3ContinuousPassSchedule.m) | Complete common-timeline frames over one pass. |
| [v3GenerateContinuousFrame.m](../src/phy/v3GenerateContinuousFrame.m) | Paired SF12 frame with continuous Doppler phase. |
| [v3InitializeReceiverStates.m](../src/phy/v3InitializeReceiverStates.m) | Replicate one common bootstrap to three methods. |
| [v3ModulateSymbol.m](../src/phy/v3ModulateSymbol.m) | Unit-power SF12 CSS symbol at a physical FFT bin. |
| [v3PhaseRotationEstimate.m](../src/phy/v3PhaseRotationEstimate.m) | Receiver-only signed CFO and start-phase estimate. |
| [v3RicianCoefficient.m](../src/phy/v3RicianCoefficient.m) | Unit-mean-power packet-flat Rician K=10 dB samples. |
| [v3SymbolFrequency.m](../src/phy/v3SymbolFrequency.m) | Wrapped instantaneous CSS baseband frequency. |
| [v3SymbolLikelihood.m](../src/phy/v3SymbolLikelihood.m) | Aggregate 4096 FFT bins into 1024 LDRO regions. |
| [v3Trajectory.m](../src/phy/v3Trajectory.m) | Exact circular-orbit single-device trajectory from SF11. |
| [v3VisibilityWindow.m](../src/phy/v3VisibilityWindow.m) | Two-lobe communication window and central blind area. |

## 统计与正式实验（8）

| 文件 | 内容 |
|---|---|
| [v3AdvanceFrameSequence.m](../src/statistics/v3AdvanceFrameSequence.m) | Deterministic frame advancement for resume tests. |
| [v3AlgorithmSignature.m](../src/statistics/v3AlgorithmSignature.m) | SHA-256 over V3 MATLAB code, source manifest, and parameters. |
| [v3EvaluateFrame.m](../src/statistics/v3EvaluateFrame.m) | Outer truth-only evaluator for one paired frame. |
| [v3LoadCheckpoint.m](../src/statistics/v3LoadCheckpoint.m) | Refuse resume when code/config/seed signature changes. |
| [v3RandomLedger.m](../src/statistics/v3RandomLedger.m) | Disjoint payload/noise/channel seeds by experiment identity. |
| [v3RunCompletePass.m](../src/statistics/v3RunCompletePass.m) | Run one complete paired formal pass. |
| [v3RunFormalSnrPoint.m](../src/statistics/v3RunFormalSnrPoint.m) | Checkpointed complete-pass sampling for one SNR. |
| [v3WriteCheckpointAtomic.m](../src/statistics/v3WriteCheckpointAtomic.m) | Save a versioned checkpoint by atomic rename. |

## 编码与译码（7）

| 文件 | 内容 |
|---|---|
| [v3DecodePayload.m](../src/coding/v3DecodePayload.m) | Hard and matched-ML soft CR3 decoding for SF12 LDRO. |
| [v3DiagonalDeinterleave.m](../src/coding/v3DiagonalDeinterleave.m) | Inverse of the ten-row V3 interleaver. |
| [v3DiagonalInterleave.m](../src/coding/v3DiagonalInterleave.m) | SF11 ordering on ten LDRO data rows. |
| [v3GeneratePayload.m](../src/coding/v3GeneratePayload.m) | Generate 16 complete SF12-LDRO CR3 blocks. |
| [v3GrayDecode.m](../src/coding/v3GrayDecode.m) | Gray-code integer to binary integer. |
| [v3GrayEncode.m](../src/coding/v3GrayEncode.m) | Binary integer to Gray-code integer. |
| [v3Hamming74Table.m](../src/coding/v3Hamming74Table.m) | SF11-compatible systematic Hamming(7,4) code table. |

## 配置与冻结参数（3）

| 文件 | 内容 |
|---|---|
| [sf12Sf11FlowConfig.m](../config/sf12Sf11FlowConfig.m) | Frozen experiment identity for the SF12 V3 project. |
| [v3LoadFrozenReceiverParameters.m](../config/v3LoadFrozenReceiverParameters.m) | Load only a validated frozen Stage-5 manifest. |
| [v3ValidateConfig.m](../config/v3ValidateConfig.m) | Enforce the non-calibrated identity fixed by the V3 plan. |

