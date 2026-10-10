# SF12 / no-LDRO V4：源码功能索引

[项目入口](../README.md) · [结果索引](result_index.md)

文件按功能分类，链接指向实际源码位置；名称与目录保留原样。描述取源码开头注释，完整行为以源码和测试为准。

## Midamble-Point 接收机（8）

| 文件 | 内容 |
|---|---|
| [v4PaperIntegerPointEstimate.m](../src/paper/v4PaperIntegerPointEstimate.m) | Full-FFT integer-bin Point estimator. |
| [v4PaperLocalResidualEstimate.m](../src/paper/v4PaperLocalResidualEstimate.m) | Physically bounded Midamble residual search. |
| [v4PaperMidambleDecode.m](../src/paper/v4PaperMidambleDecode.m) | Known Midamble, n_int=3, cumulative residual CFO. |
| [v4PaperMidamblePointDecodeV2.m](../src/paper/v4PaperMidamblePointDecodeV2.m) | Paper-native piecewise-constant Point updates. |
| [v4PaperMidamblePointTrendDecodeV3.m](../src/paper/v4PaperMidamblePointTrendDecodeV3.m) | Causal trend-aided Point updates. |
| [v4PaperMidamblePointUnifiedV4.m](../src/paper/v4PaperMidamblePointUnifiedV4.m) | One adapted Eq.(17) receiver for both cases. |
| [v4PaperMidamblePointUnifiedV6.m](../src/paper/v4PaperMidamblePointUnifiedV6.m) | Observable legacy/trend Point receiver. |
| [v4PaperRefinedPointEstimate.m](../src/paper/v4PaperRefinedPointEstimate.m) | Integer FFT acquisition plus local refinement. |

## PowerShell 运行与维护脚本（11）

| 文件 | 内容 |
|---|---|
| [continue_v30_preview_to_p10.ps1](../scripts/continue_v30_preview_to_p10.ps1) | PowerShell 启动脚本；运行前核对本机 MATLAB 路径与参数 |
| [run_b_case2_paper_fig11_v7.ps1](../scripts/run_b_case2_paper_fig11_v7.ps1) | PowerShell 启动脚本；运行前核对本机 MATLAB 路径与参数 |
| [run_b_case_anchor_awgn_v1.ps1](../scripts/run_b_case_anchor_awgn_v1.ps1) | PowerShell 启动脚本；运行前核对本机 MATLAB 路径与参数 |
| [run_b_case_anchor_awgn_v3.ps1](../scripts/run_b_case_anchor_awgn_v3.ps1) | PowerShell 启动脚本；运行前核对本机 MATLAB 路径与参数 |
| [run_b_case_anchor_awgn_v4.ps1](../scripts/run_b_case_anchor_awgn_v4.ps1) | PowerShell 启动脚本；运行前核对本机 MATLAB 路径与参数 |
| [run_b_case_anchor_awgn_v5.ps1](../scripts/run_b_case_anchor_awgn_v5.ps1) | PowerShell 启动脚本；运行前核对本机 MATLAB 路径与参数 |
| [run_b_case_anchor_awgn_v6.ps1](../scripts/run_b_case_anchor_awgn_v6.ps1) | PowerShell 启动脚本；运行前核对本机 MATLAB 路径与参数 |
| [run_v30_awgn_expedited.ps1](../scripts/run_v30_awgn_expedited.ps1) | PowerShell 启动脚本；运行前核对本机 MATLAB 路径与参数 |
| [run_v30_awgn_p10.ps1](../scripts/run_v30_awgn_p10.ps1) | PowerShell 启动脚本；运行前核对本机 MATLAB 路径与参数 |
| [run_v30_formal_sequence.ps1](../scripts/run_v30_formal_sequence.ps1) | PowerShell 启动脚本；运行前核对本机 MATLAB 路径与参数 |
| [run_v30_morning_preview.ps1](../scripts/run_v30_morning_preview.ps1) | PowerShell 启动脚本；运行前核对本机 MATLAB 路径与参数 |

## Stage55 与 PREC 接收机（31）

| 文件 | 内容 |
|---|---|
| [v4BIndividualPreambleRate.m](../src/stage55/v4BIndividualPreambleRate.m) | MATLAB 函数或脚本 |
| [v4CrossFrameRateUpdate.m](../src/stage55/v4CrossFrameRateUpdate.m) | Receiver-visible causal rolling-8 preamble CFO fit. |
| [v4DecodeThreeMethods.m](../src/stage55/v4DecodeThreeMethods.m) | Run the three fixed V4 branches on one observation. |
| [v4HuangPrecCpDecodeV5.m](../src/stage55/v4HuangPrecCpDecodeV5.m) | Continuous-phase adaptation of eight-upchirp PREC. |
| [v4HuangPrecDecodeV3.m](../src/stage55/v4HuangPrecDecodeV3.m) | Source-faithful eight-upchirp PREC receiver. |
| [v4HuangPrecUnifiedDecodeV6.m](../src/stage55/v4HuangPrecUnifiedDecodeV6.m) | Observable continuous-phase PREC adapter. |
| [v4HuangPrecUnifiedDecodeV8.m](../src/stage55/v4HuangPrecUnifiedDecodeV8.m) | Frozen project-aligned Huang PREC entry. |
| [v4HuangPrecUnifiedDecodeV9.m](../src/stage55/v4HuangPrecUnifiedDecodeV9.m) | Equal-domain project-aligned Huang PREC. |
| [v4HuangStaticDecode.m](../src/stage55/v4HuangStaticDecode.m) | Common-bootstrap fixed-CFO control receiver. |
| [v4HuangUnifiedDecodeV2.m](../src/stage55/v4HuangUnifiedDecodeV2.m) | Observable static/rate-aware PREC adapter. |
| [v4RollingTrackerPass.m](../src/stage55/v4RollingTrackerPass.m) | One causal replay with an eight-observation history. |
| [v4Stage55BootstrapFromJointPreambleMl.m](../src/stage55/v4Stage55BootstrapFromJointPreambleMl.m) | Build an unaliased phase model. |
| [v4Stage55CaseAnchorDecodeV5.m](../src/stage55/v4Stage55CaseAnchorDecodeV5.m) | Observable static guard plus joint-rate VP. |
| [v4Stage55CaseAnchorDecodeV6.m](../src/stage55/v4Stage55CaseAnchorDecodeV6.m) | Observable CFO-regime guard plus joint-rate VP. |
| [v4Stage55CaseAnchorDecodeV7.m](../src/stage55/v4Stage55CaseAnchorDecodeV7.m) | Robust observable regime guard. |
| [v4Stage55CaseProfileDecodeV8.m](../src/stage55/v4Stage55CaseProfileDecodeV8.m) | User-authorized known-case profile selection. |
| [v4Stage55CausalBlockBankDecodeV16.m](../src/stage55/v4Stage55CausalBlockBankDecodeV16.m) | Causal block-local recovery bank. |
| [v4Stage55CausalBlockBankDecodeV17.m](../src/stage55/v4Stage55CausalBlockBankDecodeV17.m) | Audit-correct wrapper for v16 behavior. |
| [v4Stage55CfoBankDecode.m](../src/stage55/v4Stage55CfoBankDecode.m) | MATLAB 函数或脚本 |
| [v4Stage55Confidence.m](../src/stage55/v4Stage55Confidence.m) | Project-aligned squared-codeword amendment and EMA. |
| [v4Stage55CrossAnchoredDualBlockDecodeV21.m](../src/stage55/v4Stage55CrossAnchoredDualBlockDecodeV21.m) | Block-causal VP/no-VP selector. |
| [v4Stage55CrossFrameBootstrapUpdate.m](../src/stage55/v4Stage55CrossFrameBootstrapUpdate.m) | Receiver-only CFO/rate anchored bootstrap. |
| [v4Stage55Decode.m](../src/stage55/v4Stage55Decode.m) | Up to five confidence replays with hard-label VPs. |
| [v4Stage55DualBootstrapDecodeV24.m](../src/stage55/v4Stage55DualBootstrapDecodeV24.m) | Observable bootstrap and profile selection. |
| [v4Stage55DualBootstrapDecodeV28.m](../src/stage55/v4Stage55DualBootstrapDecodeV28.m) | MATLAB 函数或脚本 |
| [v4Stage55DualBootstrapDecodeV30.m](../src/stage55/v4Stage55DualBootstrapDecodeV30.m) | MATLAB 函数或脚本 |
| [v4Stage55JointPreambleMlBootstrap.m](../src/stage55/v4Stage55JointPreambleMlBootstrap.m) | Joint CFO/rate ML on known preambles. |
| [v4Stage55ObservableModeSelectorV10.m](../src/stage55/v4Stage55ObservableModeSelectorV10.m) | Receiver-only static/dynamic evidence. |
| [v4Stage55PreambleRegimeClassifier.m](../src/stage55/v4Stage55PreambleRegimeClassifier.m) | Equal-domain coherent CFO/rate search. |
| [v4Stage55UnifiedDecodeV16.m](../src/stage55/v4Stage55UnifiedDecodeV16.m) | Observable unified historical dynamic VP path. |
| [v4ValidateReceiverParameters.m](../src/stage55/v4ValidateReceiverParameters.m) | Validate mechanism parameters without freezing them. |

## 冻结 SF11 来源快照（3）

| 文件 | 内容 |
|---|---|
| [satelliteFig3BootstrapJointPhaseEstimate.m](../src/upstream_sf11/satelliteFig3BootstrapJointPhaseEstimate.m) | Joint CFO/rate from pilot phase. |
| [satelliteFig3HuangPrecCpBootstrapEstimate.m](../src/upstream_sf11/satelliteFig3HuangPrecCpBootstrapEstimate.m) | Continuous-phase Huang PREC. |
| [satelliteFig3ModulateSymbol.m](../src/upstream_sf11/satelliteFig3ModulateSymbol.m) | Unit-power discrete-time LoRa CSS up-chirp. |

## 回归测试（23）

| 文件 | 内容 |
|---|---|
| [v4IdealBoundTest.m](../src/statistics/v4IdealBoundTest.m) | One-sided Wilson test against an exact SER lower bound. |
| [Sf12NoLdroCr3Test.m](../tests/Sf12NoLdroCr3Test.m) | MATLAB 测试类 |
| [V4BCaseAnchorJointPreambleV5Test.m](../tests/V4BCaseAnchorJointPreambleV5Test.m) | MATLAB 测试类 |
| [V4BCaseAnchorMechanismTest.m](../tests/V4BCaseAnchorMechanismTest.m) | MATLAB 测试类 |
| [V4CommonBootstrapTest.m](../tests/V4CommonBootstrapTest.m) | MATLAB 测试类 |
| [V4ContinuousFrameTest.m](../tests/V4ContinuousFrameTest.m) | MATLAB 测试类 |
| [V4GrayInterleaverGoldenVectorTest.m](../tests/V4GrayInterleaverGoldenVectorTest.m) | MATLAB 测试类 |
| [V4HuangPrecCpV5Test.m](../tests/V4HuangPrecCpV5Test.m) | MATLAB 测试类 |
| [V4HuangPrecUnifiedV6Test.m](../tests/V4HuangPrecUnifiedV6Test.m) | MATLAB 测试类 |
| [V4HuangPrecUnifiedV8Test.m](../tests/V4HuangPrecUnifiedV8Test.m) | MATLAB 测试类 |
| [V4HuangPrecUnifiedV9Test.m](../tests/V4HuangPrecUnifiedV9Test.m) | MATLAB 测试类 |
| [V4HuangPrecV3Test.m](../tests/V4HuangPrecV3Test.m) | MATLAB 测试类 |
| [V4HuangStageUnifiedV16Test.m](../tests/V4HuangStageUnifiedV16Test.m) | MATLAB 测试类 |
| [V4IdealReferenceV1Test.m](../tests/V4IdealReferenceV1Test.m) | MATLAB 测试类 |
| [V4IndependentChirpGoldenVectorTest.m](../tests/V4IndependentChirpGoldenVectorTest.m) | MATLAB 测试类 |
| [V4KnownCaseProfileV8Test.m](../tests/V4KnownCaseProfileV8Test.m) | MATLAB 测试类 |
| [V4NativeOverheadScheduleTest.m](../tests/V4NativeOverheadScheduleTest.m) | MATLAB 测试类 |
| [V4NoiseChannelMechanismTest.m](../tests/V4NoiseChannelMechanismTest.m) | MATLAB 测试类 |
| [V4NoLdroDimensionTest.m](../tests/V4NoLdroDimensionTest.m) | MATLAB 测试类 |
| [V4PaperMidamblePointTrendV3Test.m](../tests/V4PaperMidamblePointTrendV3Test.m) | MATLAB 测试类 |
| [V4PaperMidamblePointV2Test.m](../tests/V4PaperMidamblePointV2Test.m) | MATLAB 测试类 |
| [V4PaperUnifiedV6Test.m](../tests/V4PaperUnifiedV6Test.m) | MATLAB 测试类 |
| [V4Stage55V30MechanismTest.m](../tests/V4Stage55V30MechanismTest.m) | MATLAB 测试类 |

## 实验、报告与维护入口（56）

| 文件 | 内容 |
|---|---|
| [aggregateAndAuditV4BFormalGroupV30.m](../scripts/aggregateAndAuditV4BFormalGroupV30.m) | MATLAB 函数或脚本 |
| [aggregateV4BControlledValidationV30.m](../scripts/aggregateV4BControlledValidationV30.m) | MATLAB 函数或脚本 |
| [aggregateV4BNativeValidationV30.m](../scripts/aggregateV4BNativeValidationV30.m) | MATLAB 函数或脚本 |
| [auditV4BCaseAnchorV3.m](../scripts/auditV4BCaseAnchorV3.m) | MATLAB 函数或脚本 |
| [auditV4BCaseAnchorV4.m](../scripts/auditV4BCaseAnchorV4.m) | MATLAB 函数或脚本 |
| [auditV4BCaseAnchorV5.m](../scripts/auditV4BCaseAnchorV5.m) | MATLAB 函数或脚本 |
| [auditV4BCaseAnchorV6.m](../scripts/auditV4BCaseAnchorV6.m) | MATLAB 函数或脚本 |
| [auditV4BSmokeV30.m](../scripts/auditV4BSmokeV30.m) | MATLAB 函数或脚本 |
| [auditV4PaperCurveV7.m](../scripts/auditV4PaperCurveV7.m) | MATLAB 函数或脚本 |
| [buildV4BCaseAnchorReportV1.m](../scripts/buildV4BCaseAnchorReportV1.m) | MATLAB 函数或脚本 |
| [buildV4BCaseAnchorReportV2.m](../scripts/buildV4BCaseAnchorReportV2.m) | Aggregate V5 paired cells and draw SER/BER. |
| [buildV4BCaseAnchorReportV3.m](../scripts/buildV4BCaseAnchorReportV3.m) | MATLAB 函数或脚本 |
| [buildV4BCaseAnchorReportV4.m](../scripts/buildV4BCaseAnchorReportV4.m) | MATLAB 函数或脚本 |
| [buildV4BCaseAnchorReportV5.m](../scripts/buildV4BCaseAnchorReportV5.m) | MATLAB 函数或脚本 |
| [buildV4BCaseAnchorReportV6.m](../scripts/buildV4BCaseAnchorReportV6.m) | MATLAB 函数或脚本 |
| [buildV4ExpeditedAwgnFinalV30.m](../scripts/buildV4ExpeditedAwgnFinalV30.m) | MATLAB 函数或脚本 |
| [buildV4ExpeditedAwgnP10FinalV30.m](../scripts/buildV4ExpeditedAwgnP10FinalV30.m) | MATLAB 函数或脚本 |
| [buildV4ExperimentBNativeRegimePlotsP10.m](../scripts/buildV4ExperimentBNativeRegimePlotsP10.m) | Plot native P10 by Doppler regime. |
| [buildV4ExperimentBPlotsP10.m](../scripts/buildV4ExperimentBPlotsP10.m) | Plot AWGN P10 SER, hard BER and ML BER. |
| [buildV4HardBerOnlyPlotV7.m](../scripts/buildV4HardBerOnlyPlotV7.m) | Plot Hard BER only; ML BER is excluded. |
| [buildV4MorningPreviewV30.m](../scripts/buildV4MorningPreviewV30.m) | MATLAB 函数或脚本 |
| [buildV4PaperCurveReportV7.m](../scripts/buildV4PaperCurveReportV7.m) | MATLAB 函数或脚本 |
| [buildV4UnifiedV17TestReport.m](../scripts/buildV4UnifiedV17TestReport.m) | Merge paired Huang V3, Stage V16, Paper V6. |
| [buildV4UnifiedV19TestReport.m](../scripts/buildV4UnifiedV19TestReport.m) | Merge Huang V6, Stage V16, and Paper V6. |
| [buildV4UnifiedV21TestReport.m](../scripts/buildV4UnifiedV21TestReport.m) | Merge Huang V8, Stage V16, and Paper V6. |
| [buildV4UnifiedV22TestReport.m](../scripts/buildV4UnifiedV22TestReport.m) | Merge Huang V9, Stage V16, and Paper V6. |
| [buildV4UnifiedV23TestReport.m](../scripts/buildV4UnifiedV23TestReport.m) | Equality-aware 1000-packet Huang V9 report. |
| [promoteV5ToV6KnownCaseProfile.m](../scripts/promoteV5ToV6KnownCaseProfile.m) | Exact paired-record profile remapping. |
| [runV4BCaseAnchorCellV1.m](../scripts/runV4BCaseAnchorCellV1.m) | MATLAB 函数或脚本 |
| [runV4BCaseAnchorCellV2.m](../scripts/runV4BCaseAnchorCellV2.m) | MATLAB 函数或脚本 |
| [runV4BCaseAnchorCellV3.m](../scripts/runV4BCaseAnchorCellV3.m) | MATLAB 函数或脚本 |
| [runV4BCaseAnchorCellV4.m](../scripts/runV4BCaseAnchorCellV4.m) | MATLAB 函数或脚本 |
| [runV4BCaseAnchorCellV5.m](../scripts/runV4BCaseAnchorCellV5.m) | MATLAB 函数或脚本 |
| [runV4BCaseAnchorFormalV2Worker.m](../scripts/runV4BCaseAnchorFormalV2Worker.m) | MATLAB 函数或脚本 |
| [runV4BCaseAnchorFormalV3Worker.m](../scripts/runV4BCaseAnchorFormalV3Worker.m) | MATLAB 函数或脚本 |
| [runV4BCaseAnchorFormalV4Worker.m](../scripts/runV4BCaseAnchorFormalV4Worker.m) | MATLAB 函数或脚本 |
| [runV4BCaseAnchorFormalV5Worker.m](../scripts/runV4BCaseAnchorFormalV5Worker.m) | MATLAB 函数或脚本 |
| [runV4BCaseAnchorMechanismV5.m](../scripts/runV4BCaseAnchorMechanismV5.m) | MATLAB 函数或脚本 |
| [runV4BCaseAnchorMechanismV6.m](../scripts/runV4BCaseAnchorMechanismV6.m) | MATLAB 函数或脚本 |
| [runV4BCaseAnchorMechanismV7.m](../scripts/runV4BCaseAnchorMechanismV7.m) | MATLAB 函数或脚本 |
| [runV4BCaseAnchorMechanismV8.m](../scripts/runV4BCaseAnchorMechanismV8.m) | MATLAB 函数或脚本 |
| [runV4BControlledSmokeV30.m](../scripts/runV4BControlledSmokeV30.m) | MATLAB 函数或脚本 |
| [runV4BControlledValidationV30Pass.m](../scripts/runV4BControlledValidationV30Pass.m) | MATLAB 函数或脚本 |
| [runV4BFormalPassV30.m](../scripts/runV4BFormalPassV30.m) | MATLAB 函数或脚本 |
| [runV4BNativeSmokeV30.m](../scripts/runV4BNativeSmokeV30.m) | MATLAB 函数或脚本 |
| [runV4BNativeValidationV30Pass.m](../scripts/runV4BNativeValidationV30Pass.m) | MATLAB 函数或脚本 |
| [runV4HuangV3TestGrid.m](../scripts/runV4HuangV3TestGrid.m) | Two-case, ten-SNR, 1000-packet PREC grid. |
| [runV4HuangV6TestGrid.m](../scripts/runV4HuangV6TestGrid.m) | Two-case, ten-SNR, 1000-packet unified PREC grid. |
| [runV4HuangV8TestGrid.m](../scripts/runV4HuangV8TestGrid.m) | Two-case, ten-SNR, 1000-packet Huang grid. |
| [runV4HuangV9TestGrid.m](../scripts/runV4HuangV9TestGrid.m) | Two-case, ten-SNR, 1000-packet Huang grid. |
| [runV4PaperCurveCellV7.m](../scripts/runV4PaperCurveCellV7.m) | MATLAB 函数或脚本 |
| [runV4PaperCurveFormalV7Worker.m](../scripts/runV4PaperCurveFormalV7Worker.m) | MATLAB 函数或脚本 |
| [runV4PaperCurveValidationV7.m](../scripts/runV4PaperCurveValidationV7.m) | MATLAB 函数或脚本 |
| [runV4Tests.m](../scripts/runV4Tests.m) | Run the currently implemented V4 regression gates. |
| [runV4UnifiedV16TestGrid.m](../scripts/runV4UnifiedV16TestGrid.m) | Two-case, ten-SNR, 1000-packet paired grid. |
| [v4SetupPaths.m](../scripts/v4SetupPaths.m) | Add only V4 implementation paths, excluding frozen SF11 code. |

## 物理层与信道（19）

| 文件 | 内容 |
|---|---|
| [v4BootstrapJointPhaseEstimate.m](../src/phy/v4BootstrapJointPhaseEstimate.m) | Quadratic phase fit on eight known upchirps. |
| [v4BootstrapStateAtSymbol.m](../src/phy/v4BootstrapStateAtSymbol.m) | Extrapolate the receiver-only quadratic fit. |
| [v4BuildFrameLayout.m](../src/phy/v4BuildFrameLayout.m) | Common bootstrap/data/Midamble physical timeline. |
| [v4BuildNativeFrameLayout.m](../src/phy/v4BuildNativeFrameLayout.m) | MATLAB 函数或脚本 |
| [v4CommonBootstrap.m](../src/phy/v4CommonBootstrap.m) | Project-aligned eight-upchirp Huang power-combined eta search. |
| [v4CompensateSymbol.m](../src/phy/v4CompensateSymbol.m) | Continuous phase, CFO, and linear-rate compensation. |
| [v4ContinuousPassSchedule.m](../src/phy/v4ContinuousPassSchedule.m) | Complete common-timeline frames over one pass. |
| [v4GenerateBCaseAnchorFrame.m](../src/phy/v4GenerateBCaseAnchorFrame.m) | CR3 frame under the independent Track A orbit. |
| [v4GenerateContinuousFrame.m](../src/phy/v4GenerateContinuousFrame.m) | Paired SF12 frame with continuous Doppler phase. |
| [v4GenerateNativeFrame.m](../src/phy/v4GenerateNativeFrame.m) | MATLAB 函数或脚本 |
| [v4InitializeReceiverStates.m](../src/phy/v4InitializeReceiverStates.m) | Replicate one common bootstrap to three methods. |
| [v4ModulateSymbol.m](../src/phy/v4ModulateSymbol.m) | Unit-power SF12 CSS symbol at a physical FFT bin. |
| [v4NativeOverheadSchedule.m](../src/phy/v4NativeOverheadSchedule.m) | MATLAB 函数或脚本 |
| [v4PhaseRotationEstimate.m](../src/phy/v4PhaseRotationEstimate.m) | Receiver-only signed CFO and start-phase estimate. |
| [v4RicianCoefficient.m](../src/phy/v4RicianCoefficient.m) | Unit-mean-power packet-flat Rician K=10 dB samples. |
| [v4SymbolFrequency.m](../src/phy/v4SymbolFrequency.m) | Wrapped instantaneous CSS baseband frequency. |
| [v4SymbolLikelihood.m](../src/phy/v4SymbolLikelihood.m) | Direct 4096-bin no-LDRO hard and soft metric. |
| [v4Trajectory.m](../src/phy/v4Trajectory.m) | Exact circular-orbit single-device trajectory from SF11. |
| [v4VisibilityWindow.m](../src/phy/v4VisibilityWindow.m) | Two-lobe communication window and central blind area. |

## 统计与正式实验（23）

| 文件 | 内容 |
|---|---|
| [v4AdvanceFrameSequence.m](../src/statistics/v4AdvanceFrameSequence.m) | Deterministic frame advancement for resume tests. |
| [v4BCaseAnchorAdmissionV2.m](../src/statistics/v4BCaseAnchorAdmissionV2.m) | Evaluate the preregistered pointwise ordering. |
| [v4BCaseAnchorExtendedAdmissionV4.m](../src/statistics/v4BCaseAnchorExtendedAdmissionV4.m) | Ordering and requested curve-shape gates. |
| [v4EvaluateFrame.m](../src/statistics/v4EvaluateFrame.m) | Outer truth-only evaluator for one paired frame. |
| [v4EventRandomLedger.m](../src/statistics/v4EventRandomLedger.m) | Complete-key payload/noise/channel seed ledger. |
| [v4IdealSerReference.m](../src/statistics/v4IdealSerReference.m) | Load and verify the read-only Ideal Oracle SER curve. |
| [v4LoadCheckpoint.m](../src/statistics/v4LoadCheckpoint.m) | Refuse resume when code/config/seed signature changes. |
| [v4RandomLedger.m](../src/statistics/v4RandomLedger.m) | Disjoint payload/noise/channel seeds by experiment identity. |
| [v4RunBCaseAnchorCellV1.m](../src/statistics/v4RunBCaseAnchorCellV1.m) | MATLAB 函数或脚本 |
| [v4RunBCaseAnchorCellV2.m](../src/statistics/v4RunBCaseAnchorCellV2.m) | Fixed 200-packet V5 case/SNR cell. |
| [v4RunBCaseAnchorCellV3.m](../src/statistics/v4RunBCaseAnchorCellV3.m) | Fixed 200-packet V6 case/SNR cell. |
| [v4RunBCaseAnchorCellV4.m](../src/statistics/v4RunBCaseAnchorCellV4.m) | Fixed 200-packet extended Paper-native cell. |
| [v4RunBCaseAnchorCellV5.m](../src/statistics/v4RunBCaseAnchorCellV5.m) | Fixed 200-packet robust-regime extended cell. |
| [v4RunBControlledSmokePassV30.m](../src/statistics/v4RunBControlledSmokePassV30.m) | MATLAB 函数或脚本 |
| [v4RunBControlledValidationPassV24.m](../src/statistics/v4RunBControlledValidationPassV24.m) | MATLAB 函数或脚本 |
| [v4RunBNativeValidationPassV28.m](../src/statistics/v4RunBNativeValidationPassV28.m) | MATLAB 函数或脚本 |
| [v4RunHuangV3TestCell.m](../src/statistics/v4RunHuangV3TestCell.m) | Fixed 1000-packet source-faithful PREC cell. |
| [v4RunHuangV6TestCell.m](../src/statistics/v4RunHuangV6TestCell.m) | Fixed 1000-packet unified Huang PREC cell. |
| [v4RunHuangV8TestCell.m](../src/statistics/v4RunHuangV8TestCell.m) | Fixed 1000-packet frozen Huang cell. |
| [v4RunHuangV9TestCell.m](../src/statistics/v4RunHuangV9TestCell.m) | Fixed 1000-packet equal-domain Huang cell. |
| [v4RunPaperCurveCellV7.m](../src/statistics/v4RunPaperCurveCellV7.m) | Paper-only Case2 formal cell on V6 paired packets. |
| [v4RunUnifiedV16TestCell.m](../src/statistics/v4RunUnifiedV16TestCell.m) | Fixed 1000-packet three-method paired cell. |
| [v4WriteCheckpointAtomic.m](../src/statistics/v4WriteCheckpointAtomic.m) | Save a versioned checkpoint by atomic rename. |

## 编码与译码（7）

| 文件 | 内容 |
|---|---|
| [v4DecodePayload.m](../src/coding/v4DecodePayload.m) | Hard and matched-ML soft CR3 decoding for SF12 no-LDRO. |
| [v4DiagonalDeinterleave.m](../src/coding/v4DiagonalDeinterleave.m) | Inverse of the twelve-row V4 interleaver. |
| [v4DiagonalInterleave.m](../src/coding/v4DiagonalInterleave.m) | SF11 ordering generalized to twelve no-LDRO rows. |
| [v4GeneratePayload.m](../src/coding/v4GeneratePayload.m) | Generate 16 complete SF12 no-LDRO CR3 blocks. |
| [v4GrayDecode.m](../src/coding/v4GrayDecode.m) | Gray-code integer to binary integer. |
| [v4GrayEncode.m](../src/coding/v4GrayEncode.m) | Binary integer to Gray-code integer. |
| [v4Hamming74Table.m](../src/coding/v4Hamming74Table.m) | SF11-compatible systematic Hamming(7,4) code table. |

## 论文条件适配（1）

| 文件 | 内容 |
|---|---|
| [v4TrackAOrbit.m](../src/paper_anchor/v4TrackAOrbit.m) | Independent zenith circular-orbit model for Track A. |

## 路径、来源与基础设施（4）

| 文件 | 内容 |
|---|---|
| [v4CanonicalJson.m](../src/infrastructure/v4CanonicalJson.m) | Stable JSON encoding with recursively sorted struct fields. |
| [v4KeyedSeed.m](../src/infrastructure/v4KeyedSeed.m) | Map a complete canonical key to a call-order-independent seed. |
| [v4Sha256.m](../src/infrastructure/v4Sha256.m) | SHA-256 of a file or UTF-8 text. |
| [v4VerifyReadOnlySources.m](../src/infrastructure/v4VerifyReadOnlySources.m) | Verify the canonical source and its frozen snapshot. |

## 配置与冻结参数（6）

| 文件 | 内容 |
|---|---|
| [sf12NoLdroSf11FlowConfig.m](../config/sf12NoLdroSf11FlowConfig.m) | Frozen experiment identity for the SF12 V4 project. |
| [v4BCalibrationCandidates.m](../config/v4BCalibrationCandidates.m) | MATLAB 函数或脚本 |
| [v4DefaultBParameters.m](../config/v4DefaultBParameters.m) | Project-structure defaults expressed in SF12 units; calibration must freeze. |
| [v4LoadMethodAlignedParametersV1.m](../config/v4LoadMethodAlignedParametersV1.m) | Load the quality-selected frozen candidate. |
| [v4LoadMethodAlignedR3ParametersV1.m](../config/v4LoadMethodAlignedR3ParametersV1.m) | Load frozen V14 receiver parameters. |
| [v4ValidateConfig.m](../config/v4ValidateConfig.m) | Enforce the non-calibrated identity fixed by the V4 plan. |

