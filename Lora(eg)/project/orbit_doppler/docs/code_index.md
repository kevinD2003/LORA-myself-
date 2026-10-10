# 轨道与连续多普勒：源码功能索引

[项目入口](../README.md) · [结果索引](result_index.md)

文件按功能分类，链接指向实际源码位置；名称与目录保留原样。描述取源码开头注释，完整行为以源码和测试为准。

## 信号与载荷生成（1）

| 文件 | 内容 |
|---|---|
| [senloraModulateLoRaSymbol.m](../senloraModulateLoRaSymbol.m) | Generate one unit-power LoRa CSS symbol. |

## 回归测试（1）

| 文件 | 内容 |
|---|---|
| [senloraBinomialBounds95Test.m](../senloraBinomialBounds95Test.m) | Tests for exact binomial confidence bounds. |

## 实验、报告与维护入口（9）

| 文件 | 内容 |
|---|---|
| [run_senlora_ber_smoke.m](../run_senlora_ber_smoke.m) | Small raw-Monte-Carlo BER checkpoint. |
| [run_senlora_confidence_orbit_demo.m](../run_senlora_confidence_orbit_demo.m) | CONFIDENCE ORBIT DEMO Exercise SenLoRa mask iteration. |
| [run_senlora_continuous_orbit_demo.m](../run_senlora_continuous_orbit_demo.m) | Generate stage-2 frame diagnostics. |
| [run_senlora_orbit_model_demo.m](../run_senlora_orbit_model_demo.m) | Plot the stage-1 orbit/Doppler validation. |
| [run_senlora_virtual_pilot_demo.m](../run_senlora_virtual_pilot_demo.m) | VIRTUAL PILOT DEMO Validate trajectory tracking without truth input. |
| [run_senloraReferenceComparison.m](../run_senloraReferenceComparison.m) | Compare the new channel with lora(CFO). |
| [run_senloraRegressionTests.m](../run_senloraRegressionTests.m) | Check orbit constants, phase continuity, and masks. |
| [runSenLoRaOrbitBer.m](../runSenLoRaOrbitBer.m) | Resumable formal SenLoRa orbit BER entry point. |
| [train_senloraConfidenceParameters.m](../train_senloraConfidenceParameters.m) | Train and validate adaptive thresholds. |

## 接收与补偿（8）

| 文件 | 内容 |
|---|---|
| [senloraBlindHardUpdateDecode.m](../senloraBlindHardUpdateDecode.m) | Update every hard decision without SenLoRa. |
| [senloraDecodeRaw.m](../senloraDecodeRaw.m) | Uncompensated noncoherent dechirp-FFT detector. |
| [senloraEstimateBootstrapPilots.m](../senloraEstimateBootstrapPilots.m) | Robust joint acquisition from known pilots. |
| [senloraHardDemodulate.m](../senloraHardDemodulate.m) | Dechirp and noncoherent FFT decision. |
| [senloraIdealPhaseDecode.m](../senloraIdealPhaseDecode.m) | Ideal reference using the true sample phase. |
| [senloraPhaseRotationEstimate.m](../senloraPhaseRotationEstimate.m) | Estimate a LoRa CFO with PREC rotation. |
| [senloraStaticPrecDecode.m](../senloraStaticPrecDecode.m) | Four-pilot constant-CFO PREC baseline. |
| [senloraTruthFilteredDecode.m](../senloraTruthFilteredDecode.m) | Evaluation-only correct-symbol upper bound. |

## 理论与统计（3）

| 文件 | 内容 |
|---|---|
| [senloraBinomialBounds95.m](../senloraBinomialBounds95.m) | Two-sided 95% Clopper-Pearson bounds. |
| [senloraCountBitErrors.m](../senloraCountBitErrors.m) | Count Gray-mapped LoRa bit errors. |
| [senloraTheoreticalBerAwgn.m](../senloraTheoreticalBerAwgn.m) | Orthogonal-MFSK AWGN reference. |

## 编码与译码（1）

| 文件 | 内容 |
|---|---|
| [senloraGenerateCodedPayloadBins.m](../senloraGenerateCodedPayloadBins.m) | Build blocks consistent with SenLoRa LLRs. |

## 置信检测与软信息（1）

| 文件 | 内容 |
|---|---|
| [senloraDynamicConfidenceIteration.m](../senloraDynamicConfidenceIteration.m) | Run causal-style SenLoRa mask iterations. |

## 跟踪与状态更新（1）

| 文件 | 内容 |
|---|---|
| [trackSenLoRaVirtualPilots.m](../trackSenLoRaVirtualPilots.m) | Track dynamic CFO using accepted virtual pilots. |

## 轨道与信道（5）

| 文件 | 内容 |
|---|---|
| [generateSenLoRaOrbitFrame.m](../generateSenLoRaOrbitFrame.m) | Generate a continuous dynamic-Doppler LoRa frame. |
| [senloraDopplerPiecewiseLinear.m](../senloraDopplerPiecewiseLinear.m) | Port of the reference paper's Eq. (18)-(20). |
| [senloraFigure17Geometry.m](../senloraFigure17Geometry.m) | Single-device dynamic Doppler geometry. |
| [senloraOrbitDopplerTrajectory.m](../senloraOrbitDopplerTrajectory.m) | Evaluate shift and rate from orbit geometry. |
| [senloraVisibilityWindow.m](../senloraVisibilityWindow.m) | Visibility intervals used by the reference model. |

## 辅助工具与测试基础设施（1）

| 文件 | 内容 |
|---|---|
| [simulateSenLoRaBerPoint.m](../simulateSenLoRaBerPoint.m) | Common-random-number BER point. |

## 配置与冻结参数（2）

| 文件 | 内容 |
|---|---|
| [senloraChannelConfig.m](../senloraChannelConfig.m) | Single-device continuous-frame simulation settings. |
| [senloraOrbitConfig.m](../senloraOrbitConfig.m) | Physical constants from the lora(CFO) reference model. |

