function cfg = paperSf7Config()
%PAPERSF7CONFIG Locked configuration for the SF=7 paper reproduction.

cfg = paperSf12Config();
cfg.experimentName = "paper_sf7_midamble_point";

cfg.radio.spreadingFactor = 7;
cfg.radio.ldro = false;
cfg.radio.samplesPerSymbol = 2^cfg.radio.spreadingFactor;
cfg.radio.dataAlphabetSize = 2^cfg.radio.spreadingFactor;
cfg.radio.dataBinSpacing = 1;
cfg.radio.symbolDurationS = ...
    cfg.radio.samplesPerSymbol/cfg.radio.sampleRateHz;
cfg.radio.fftBinHz = ...
    cfg.radio.sampleRateHz/cfg.radio.samplesPerSymbol;

cfg.frame.payloadSymbols = 33;
cfg.frame.midambleSpacingDataSymbols = 12;

cfg.monteCarlo.snrDb = -15:-6;
cfg.smoke.snrDb = [-15, -10, -6];

cfg.plot.xLimitsDb = [-16, -6];
cfg.plot.yLimits = [1e-3, 1];

cfg.paper.pointToaS = 0.044;
cfg.paper.midamblePointToaS = 0.047;
cfg.paper.case2StatedFrameDopplerChangeHz = 25;
end
