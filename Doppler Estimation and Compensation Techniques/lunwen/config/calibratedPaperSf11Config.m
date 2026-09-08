function cfg = calibratedPaperSf11Config()
%CALIBRATEDPAPERSF11CONFIG 由SF7/SF12校准机制插值得到的SF11配置。

cfg = paperSf11Config();
cfg.experimentName = "calibrated_paper_sf11";
cfg.channel.ricianKDb = 12.75;
cfg.receiver.estimatorFftPaddingFactor = 4;
cfg.receiver.midambleEstimatorFftPaddingFactor = 1;
cfg.receiver.midambleUpdateDelayDataSymbols = 1;
cfg.receiver.midambleEstimatorSnrOffsetDb = -0.30;
cfg.receiver.midambleEstimatorModel = "legacy_snr_offset";
cfg.receiver.midambleInnovationGain = 1;
% SF11没有论文目标曲线，并将作为Stage55桥梁，因此保留物理轨道尺度。
cfg.orbit.frameDopplerTimeScale = 1;
cfg.monteCarlo.randomSeed = 271828;
cfg.monteCarlo.commonRandomNumbersAcrossStrategies = true;
cfg.provenance.profile = "sf11_interpolated_calibrated_receiver";
cfg.provenance.fittedOrTuned = true;
cfg.provenance.rationale = ...
    "SF11接收机参数由SF7/SF12校准配置插值得到，未使用SF11目标曲线。";
end
