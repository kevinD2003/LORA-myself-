# Stage55 SF11：源码功能索引

[项目入口](../README.md) · [结果索引](result_index.md)

文件按功能分类，链接指向实际源码位置；名称与目录保留原样。描述取源码开头注释，完整行为以源码和测试为准。

## PowerShell 运行与维护脚本（1）

| 文件 | 内容 |
|---|---|
| [queue_stage26_next_worker.ps1](../scripts/maintenance/queue_stage26_next_worker.ps1) | PowerShell 启动脚本；运行前核对本机 MATLAB 路径与参数 |

## 信号与载荷生成（3）

| 文件 | 内容 |
|---|---|
| [generateContinuousSatelliteFrame.m](../generateContinuousSatelliteFrame.m) | Exact full-RF dynamic-Doppler CSS frame. |
| [satelliteFig3GeneratePayload.m](../satelliteFig3GeneratePayload.m) | Make coded, diagonally-interleaved CSS payload. |
| [satelliteFig3ModulateSymbol.m](../satelliteFig3ModulateSymbol.m) | Unit-power discrete-time LoRa CSS up-chirp. |

## 回归测试（46）

| 文件 | 内容 |
|---|---|
| [satelliteFig3HuangPrecCpMatchedDecodeTest.m](../satelliteFig3HuangPrecCpMatchedDecodeTest.m) | Regression tests. |
| [stage55FairHuangPrecComparisonTest.m](../stage55FairHuangPrecComparisonTest.m) | Frozen fair-comparison gates. |
| [test_stage14_hard_prec.m](../test_stage14_hard_prec.m) | MATLAB unit-test wrapper for this stage regression. |
| [test_stage15_two_scenario_ber_wiring.m](../test_stage15_two_scenario_ber_wiring.m) | MATLAB unit-test wrapper for this stage regression. |
| [test_stage16_receiver_phase_continuity.m](../test_stage16_receiver_phase_continuity.m) | MATLAB unit-test wrapper for this stage regression. |
| [test_stage18_quality_gated_senlora.m](../test_stage18_quality_gated_senlora.m) | MATLAB unit-test wrapper for this stage regression. |
| [test_stage1_satellite_fig3.m](../test_stage1_satellite_fig3.m) | MATLAB unit-test wrapper for this stage regression. |
| [test_stage23_four_curve_ber_wiring.m](../test_stage23_four_curve_ber_wiring.m) | MATLAB unit-test wrapper for this stage regression. |
| [test_stage24_rate_replay.m](../test_stage24_rate_replay.m) | MATLAB unit-test wrapper for this stage regression. |
| [test_stage25_hamming_theory.m](../test_stage25_hamming_theory.m) | MATLAB unit-test wrapper for this stage regression. |
| [test_stage26_formal_checkpoint.m](../test_stage26_formal_checkpoint.m) | MATLAB unit-test wrapper for this stage regression. |
| [test_stage27_common_payload_metric.m](../test_stage27_common_payload_metric.m) | MATLAB unit-test wrapper for this stage regression. |
| [test_stage28_rate_release.m](../test_stage28_rate_release.m) | MATLAB unit-test wrapper for this stage regression. |
| [test_stage29_orbit_rate_prior.m](../test_stage29_orbit_rate_prior.m) | MATLAB unit-test wrapper for this stage regression. |
| [test_stage2_rolling8_receiver.m](../test_stage2_rolling8_receiver.m) | MATLAB unit-test wrapper for this stage regression. |
| [test_stage30_confidence_only_pilot_labels.m](../test_stage30_confidence_only_pilot_labels.m) | MATLAB unit-test wrapper for this stage regression. |
| [test_stage31_causal_confidence_timing.m](../test_stage31_causal_confidence_timing.m) | MATLAB unit-test wrapper for this stage regression. |
| [test_stage3_physics_layers.m](../test_stage3_physics_layers.m) | MATLAB unit-test wrapper for this stage regression. |
| [test_stage3_stable_admission.m](../test_stage3_stable_admission.m) | MATLAB unit-test wrapper for this stage regression. |
| [test_stage43_hard_prec_common_orbit_prior.m](../test_stage43_hard_prec_common_orbit_prior.m) | MATLAB unit-test wrapper for this stage regression. |
| [test_stage45_upper_ber_termination.m](../test_stage45_upper_ber_termination.m) | MATLAB unit-test wrapper for this stage regression. |
| [test_stage46_paper_prec_reference.m](../test_stage46_paper_prec_reference.m) | MATLAB unit-test wrapper for this regression. |
| [test_stage47_paper_prec_continuous_phase.m](../test_stage47_paper_prec_continuous_phase.m) | MATLAB unit-test wrapper for this regression. |
| [test_stage48_common_initialization.m](../test_stage48_common_initialization.m) | MATLAB unit-test wrapper for this regression. |
| [test_stage48_huang_prec_cp_source.m](../test_stage48_huang_prec_cp_source.m) | MATLAB unit-test wrapper for this regression. |
| [test_stage49_continuous_pass_frames.m](../test_stage49_continuous_pass_frames.m) | MATLAB unit-test wrapper for this regression. |
| [test_stage50_continuous_pass_smoke_wiring.m](../test_stage50_continuous_pass_smoke_wiring.m) | MATLAB unit-test wrapper for this regression. |
| [test_stage51_preregistered_snr_freeze.m](../test_stage51_preregistered_snr_freeze.m) | MATLAB unit-test wrapper for this regression. |
| [test_stage52_continuous_pass_checkpoint.m](../test_stage52_continuous_pass_checkpoint.m) | MATLAB unit-test wrapper for this regression. |
| [test_stage52_formal_artifact_wiring.m](../test_stage52_formal_artifact_wiring.m) | MATLAB unit-test wrapper for this regression. |
| [test_stage53_formal_result_acceptance.m](../test_stage53_formal_result_acceptance.m) | MATLAB unit-test wrapper for this regression. |
| [test_stage53_formal_wrapper_policy.m](../test_stage53_formal_wrapper_policy.m) | MATLAB unit-test wrapper for this regression. |
| [test_stage54_complexity_goodput_report.m](../test_stage54_complexity_goodput_report.m) | MATLAB unit-test wrapper for this regression. |
| [test_stage55_corrected_pass_wiring.m](../test_stage55_corrected_pass_wiring.m) | MATLAB unit-test wrapper for this regression. |
| [test_stage55_cross_frame_rate_state.m](../test_stage55_cross_frame_rate_state.m) | MATLAB unit-test wrapper for this regression. |
| [test_stage55_final_soft_decode.m](../test_stage55_final_soft_decode.m) | MATLAB unit-test wrapper for this regression. |
| [test_stage55_high_coverage_admission.m](../test_stage55_high_coverage_admission.m) | MATLAB unit-test wrapper for this regression. |
| [test_stage55_rate_release_bound.m](../test_stage55_rate_release_bound.m) | MATLAB unit-test wrapper for this regression. |
| [test_stage55_soft_hamming_ml.m](../test_stage55_soft_hamming_ml.m) | MATLAB unit-test wrapper for this regression. |
| [test_stage55_vp_control_switch.m](../test_stage55_vp_control_switch.m) | MATLAB unit-test wrapper for this regression. |
| [test_stage55_vp_control_wiring.m](../test_stage55_vp_control_wiring.m) | MATLAB unit-test wrapper for this regression. |
| [test_stage55_vp_frequency_uncertainty.m](../test_stage55_vp_frequency_uncertainty.m) | MATLAB unit-test wrapper for this regression. |
| [test_stage55_vp_mechanism_ablation.m](../test_stage55_vp_mechanism_ablation.m) | MATLAB unit-test wrapper for this regression. |
| [test_stage55_vp_quality_aware.m](../test_stage55_vp_quality_aware.m) | MATLAB unit-test wrapper for this regression. |
| [test_stage7_hamming_margin.m](../test_stage7_hamming_margin.m) | MATLAB unit-test wrapper for this stage regression. |
| [test_stage8_trusted_confidence.m](../test_stage8_trusted_confidence.m) | MATLAB unit-test wrapper for this stage regression. |

## 实验、报告与维护入口（50）

| 文件 | 内容 |
|---|---|
| [backfill_stage42_hard_prec.m](../backfill_stage42_hard_prec.m) | Recompute only the corrected hard-PREC arm. |
| [migrate_stage40_to_stage42.m](../migrate_stage40_to_stage42.m) | Preserve completed statistics for the new grid. |
| [migrate_stage42_to_stage45.m](../migrate_stage42_to_stage45.m) | Shorten grid and add the 1e-6 upper-bound stop. |
| [plot_stage53_region_ber_figures.m](../plot_stage53_region_ber_figures.m) | Compare high-dynamic BER at both SNRs. |
| [plot_stage55_corrected_results.m](../plot_stage55_corrected_results.m) | Visualise the frozen Stage-55 correction. |
| [plot_stage55_senlora_prec_ser_ber_trajectory.m](../plot_stage55_senlora_prec_ser_ber_trajectory.m) | Plot the fair two-method result. |
| [plot_stage55_vp_quality_final_evaluation.m](../plot_stage55_vp_quality_final_evaluation.m) | Paired full-pass effect intervals. |
| [run_stage10_anchor_diagnosis.m](../run_stage10_anchor_diagnosis.m) | Trace SER changes back to anchor CFO quality. |
| [run_stage11_independent_low_snr_validation.m](../run_stage11_independent_low_snr_validation.m) | Hold-out test for pair anchors. |
| [run_stage12_ber_smoke.m](../run_stage12_ber_smoke.m) | Four-arm fair BER interface smoke experiment. |
| [run_stage13_formal_ber.m](../run_stage13_formal_ber.m) | Checkpointed four-arm BER, no fitted smoothing. |
| [run_stage14_hard_prec_diagnostics.m](../run_stage14_hard_prec_diagnostics.m) | Inspect hard PREC in both orbit scenes. |
| [run_stage15_two_scenario_ber_smoke.m](../run_stage15_two_scenario_ber_smoke.m) | Common-random-number BER wiring check. |
| [run_stage16_confidence_audit.m](../run_stage16_confidence_audit.m) | Audit virtual pilots independently of BER. |
| [run_stage17_fivepass_feature_audit.m](../run_stage17_fivepass_feature_audit.m) | Inspect accepted-pilot feature separation. |
| [run_stage18_quality_gate_validation.m](../run_stage18_quality_gate_validation.m) | Independent pilot-quality validation. |
| [run_stage1_satellite_fig3_validation.m](../run_stage1_satellite_fig3_validation.m) | Generate first review figures. |
| [run_stage23_four_curve_ber_smoke.m](../run_stage23_four_curve_ber_smoke.m) | Validate the final BER experiment wiring. |
| [run_stage24_rate_replay_audit.m](../run_stage24_rate_replay_audit.m) | Independent audit of blind rate replay. |
| [run_stage26_formal_ber.m](../run_stage26_formal_ber.m) | Checkpointed two-scenario final BER experiment. |
| [run_stage2_rolling8_diagnostics.m](../run_stage2_rolling8_diagnostics.m) | Plot causal tracker state before BER runs. |
| [run_stage39_phase_layer_audit.m](../run_stage39_phase_layer_audit.m) | Locate apparent below-theory performance. |
| [run_stage3_layered_diagnostics.m](../run_stage3_layered_diagnostics.m) | Separate channel, compensation, and pilot errors. |
| [run_stage41_ideal_sample_audit.m](../run_stage41_ideal_sample_audit.m) | Same-seed ideal compensation error count. |
| [run_stage44_parallel_formal_batch.m](../run_stage44_parallel_formal_batch.m) | Parallel frame compute, serial merge. |
| [run_stage47_paper_prec_vs_senlora_smoke.m](../run_stage47_paper_prec_vs_senlora_smoke.m) | Same-channel four-curve check. |
| [run_stage48_common_bootstrap_validation.m](../run_stage48_common_bootstrap_validation.m) | Noiseless mechanism inspection. |
| [run_stage49_continuous_pass_validation.m](../run_stage49_continuous_pass_validation.m) | Time/visibility/phase inspection. |
| [run_stage4_confidence_visualization.m](../run_stage4_confidence_visualization.m) | Visual audit of per-symbol gate output. |
| [run_stage50_continuous_pass_smoke.m](../run_stage50_continuous_pass_smoke.m) | Paired time-axis full-pass smoke check. |
| [run_stage51_preregistered_snr_freeze.m](../run_stage51_preregistered_snr_freeze.m) | Freeze fixed-SNR time experiments. |
| [run_stage52_continuous_pass_formal.m](../run_stage52_continuous_pass_formal.m) | Checkpointed repeated full-pass study. |
| [run_stage53_formal_repeated_passes.m](../run_stage53_formal_repeated_passes.m) | Frozen formal time-axis experiment. |
| [run_stage54_complexity_goodput_report.m](../run_stage54_complexity_goodput_report.m) | Complexity and delivery-rate audit. |
| [run_stage55_admission_root_cause_audit.m](../run_stage55_admission_root_cause_audit.m) | Gate-by-gate SenLoRa VP audit. |
| [run_stage55_corrected_orbit_region_figures.m](../run_stage55_corrected_orbit_region_figures.m) | Stage-55 orbit-time figures. |
| [run_stage55_corrected_pass_validation.m](../run_stage55_corrected_pass_validation.m) | Corrected continuous-pass receiver. |
| [run_stage55_huang_prec_cp_fresh_replay.m](../run_stage55_huang_prec_cp_fresh_replay.m) | Fair Huang-PREC Stage55 replay. |
| [run_stage55_senior_prec_fresh_replay.m](../run_stage55_senior_prec_fresh_replay.m) | Exact senior-code PREC on fresh frames. |
| [run_stage55_three_method_runtime_benchmark.m](../run_stage55_three_method_runtime_benchmark.m) | Controlled fresh-frame timing. |
| [run_stage55_vp_control_comparison.m](../run_stage55_vp_control_comparison.m) | Paired Stage-55 virtual-pilot ablation. |
| [run_stage55_vp_frequency_quality_audit.m](../run_stage55_vp_frequency_quality_audit.m) | Calibrate receiver-only VP CFO error. |
| [run_stage55_vp_mechanism_ablation.m](../run_stage55_vp_mechanism_ablation.m) | Five-way paired Stage55 VP ablation. |
| [run_stage55_vp_quality_fresh_overall_report.m](../run_stage55_vp_quality_fresh_overall_report.m) | Fresh Stage55 result suite. |
| [run_stage5_two_tier_confidence_audit.m](../run_stage5_two_tier_confidence_audit.m) | Visualise safe immediate/provisional classes. |
| [run_stage7_hamming_margin_audit.m](../run_stage7_hamming_margin_audit.m) | Audit anchor-recompensation reliability. |
| [run_stage8_trusted_confidence_visualization.m](../run_stage8_trusted_confidence_visualization.m) | Audit the finished detector. |
| [run_stage9_low_snr_feasibility.m](../run_stage9_low_snr_feasibility.m) | Does low-SNR confidence recheck help? |
| [runStage55ProjectTests.m](../runStage55ProjectTests.m) | Run every canonical Stage55 regression test. |
| [train_stage4_confidence_gate.m](../train_stage4_confidence_gate.m) | Cross-validated conservative pilot gate. |

## 接收与补偿（14）

| 文件 | 内容 |
|---|---|
| [satelliteFig3AdaptiveRateReplaySenLoRaDecode.m](../satelliteFig3AdaptiveRateReplaySenLoRaDecode.m) | Physical-prior SenLoRa track. |
| [satelliteFig3BootstrapEstimate.m](../satelliteFig3BootstrapEstimate.m) | Joint large-CFO acquisition from known pilots. |
| [satelliteFig3BootstrapJointPhaseEstimate.m](../satelliteFig3BootstrapJointPhaseEstimate.m) | Joint CFO/rate from pilot phase. |
| [satelliteFig3HardDecision.m](../satelliteFig3HardDecision.m) | Dechirp and map MATLAB FFT bin to CSS labels. |
| [satelliteFig3HardPrecDecode.m](../satelliteFig3HardPrecDecode.m) | Hard-decision rolling-8 PREC receiver. |
| [satelliteFig3HuangPrecCpBootstrapEstimate.m](../satelliteFig3HuangPrecCpBootstrapEstimate.m) | Continuous-phase Huang PREC. |
| [satelliteFig3HuangPrecCpMatchedDecode.m](../satelliteFig3HuangPrecCpMatchedDecode.m) | Fair Huang-PREC comparison arm. |
| [satelliteFig3HuangPrecStaticCpDecode.m](../satelliteFig3HuangPrecStaticCpDecode.m) | Static Huang-PREC CP baseline. |
| [satelliteFig3PaperPrecDecode.m](../satelliteFig3PaperPrecDecode.m) | Thesis PREC with one CFO estimate per frame. |
| [satelliteFig3PhaseRotationEstimate.m](../satelliteFig3PhaseRotationEstimate.m) | Signed CFO/residual estimate by rotation. |
| [satelliteFig3QualityGatedSenLoRaDecode.m](../satelliteFig3QualityGatedSenLoRaDecode.m) | SNR-independent rolling-8 SenLoRa. |
| [satelliteFig3RateReplaySenLoRaDecode.m](../satelliteFig3RateReplaySenLoRaDecode.m) | Blind frame-level rate acquisition. |
| [satelliteFig3SenLoRaIterativeDecode.m](../satelliteFig3SenLoRaIterativeDecode.m) | Five-pass SenLoRa confidence iteration. |
| [satelliteFig3SenLoRaVirtualPilotDecode.m](../satelliteFig3SenLoRaVirtualPilotDecode.m) | No-orbit-prior SenLoRa path. |

## 理论与统计（3）

| 文件 | 内容 |
|---|---|
| [satelliteFig3BerInterval95.m](../satelliteFig3BerInterval95.m) | Binomial BER display value and 95% bounds. |
| [satelliteFig3TheoreticalBerAwgn.m](../satelliteFig3TheoreticalBerAwgn.m) | Uncoded orthogonal-CSS AWGN reference. |
| [satelliteFig3TheoreticalHammingBerAwgn.m](../satelliteFig3TheoreticalHammingBerAwgn.m) | Coded AWGN BER reference. |

## 编码与译码（5）

| 文件 | 内容 |
|---|---|
| [satelliteFig3DiagonalDeinterleave.m](../satelliteFig3DiagonalDeinterleave.m) | Inverse LoRa cyclic diagonal interleaver. |
| [satelliteFig3DiagonalInterleave.m](../satelliteFig3DiagonalInterleave.m) | LoRa cyclic diagonal interleaver. |
| [satelliteFig3GrayDecode.m](../satelliteFig3GrayDecode.m) | Gray-code integer to binary integer. |
| [satelliteFig3GrayEncode.m](../satelliteFig3GrayEncode.m) | Binary integer to Gray-code integer. |
| [satelliteFig3HardPayloadBits.m](../satelliteFig3HardPayloadBits.m) | Hard Hamming decode for the no-compensation arm. |

## 置信检测与软信息（4）

| 文件 | 内容 |
|---|---|
| [satelliteFig3ApplyConfidenceGate.m](../satelliteFig3ApplyConfidenceGate.m) | Apply trained, receiver-only pilot gate. |
| [satelliteFig3PilotConfidenceFeatures.m](../satelliteFig3PilotConfidenceFeatures.m) | Receiver-visible virtual-pilot features. |
| [satelliteFig3SenLoRaConfidence.m](../satelliteFig3SenLoRaConfidence.m) | SenLoRa soft confidence on 7-symbol blocks. |
| [satelliteFig3TrustedConfidenceDecode.m](../satelliteFig3TrustedConfidenceDecode.m) | Receiver-only confidence pilot design. |

## 跟踪与状态更新（2）

| 文件 | 内容 |
|---|---|
| [satelliteFig3CrossFrameRateUpdate.m](../satelliteFig3CrossFrameRateUpdate.m) | Causal rolling-8 frame-rate state. |
| [satelliteFig3RollingPilotTracker.m](../satelliteFig3RollingPilotTracker.m) | Causal 8-slot virtual-pilot Doppler tracker. |

## 轨道与信道（4）

| 文件 | 内容 |
|---|---|
| [satelliteFig3OrbitRatePriorFromCfo.m](../satelliteFig3OrbitRatePriorFromCfo.m) | Receiver-visible orbit rate prior. |
| [satelliteFig3PiecewiseDoppler.m](../satelliteFig3PiecewiseDoppler.m) | Exact full-RF Doppler and Eq. (18)-(20) proxy. |
| [satelliteFig3Trajectory.m](../satelliteFig3Trajectory.m) | Exact circular-orbit single-device trajectory. |
| [satelliteFig3VisibilityWindow.m](../satelliteFig3VisibilityWindow.m) | Figure 3 two-lobe single-device window. |

## 辅助工具与测试基础设施（6）

| 文件 | 内容 |
|---|---|
| [satelliteFig3ContinuousPassSchedule.m](../satelliteFig3ContinuousPassSchedule.m) | Contiguous complete frames in one pass. |
| [satelliteFig3Stage52WriteArtifacts.m](../satelliteFig3Stage52WriteArtifacts.m) | Formal complete-pass-only products. |
| [satelliteFig3SymbolFrequency.m](../satelliteFig3SymbolFrequency.m) | Wrapped instantaneous complex-baseband CSS frequency. |
| [satelliteFig3TwoTierPilotDecision.m](../satelliteFig3TwoTierPilotDecision.m) | Immediate and quarantined pilot classes. |
| [SenLoRaStageTestCase.m](../SenLoRaStageTestCase.m) | Adds project folders for stage regression tests. |
| [stage55ProjectTestSuite.m](../stage55ProjectTestSuite.m) | Build the complete canonical Stage55 test suite. |

## 配置与冻结参数（1）

| 文件 | 内容 |
|---|---|
| [satelliteFig3Config.m](../satelliteFig3Config.m) | Single-device Figure 3 LoRa satellite configuration. |

