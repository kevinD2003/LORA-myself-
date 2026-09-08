function cfg = calibratedPaperSf7Config()
%CALIBRATEDPAPERSF7CONFIG Endpoint-fitted profile, not an independent reproduction.

cfg = paperSf7Config();
cfg.experimentName = "calibrated_paper_sf7";
cfg.channel.ricianKDb = 12.75;
cfg.receiver.estimatorFftPaddingFactor = 4;
cfg.receiver.midambleEstimatorFftPaddingFactor = 1;
cfg.receiver.midambleUpdateDelayDataSymbols = 1;
cfg.receiver.midambleEstimatorSnrOffsetDb = -0.5;
cfg.receiver.midambleEstimatorModel = "legacy_snr_offset";
cfg.receiver.midambleInnovationGain = 1;
cfg.orbit.frameDopplerTimeScale = 0.5;
cfg.monteCarlo.randomSeed = 314159;
cfg.monteCarlo.commonRandomNumbersAcrossStrategies = true;
cfg.provenance.profile = "final_paper_endpoint_calibrated";
cfg.provenance.fittedOrTuned = true;
cfg.provenance.rationale = ...
    "Selected by labeled search against Figure 10/11 endpoint bands.";
end
