function cfg = paperSf11Config()
%PAPERSF11CONFIG Derived SF=11 experiment after SF=7/12 validation.

cfg = paperSf12Config();
cfg.experimentName = "derived_sf11_midamble_point";

cfg.radio.spreadingFactor = 11;
cfg.radio.ldro = true;
cfg.radio.samplesPerSymbol = 2^cfg.radio.spreadingFactor;
cfg.radio.dataAlphabetSize = 2^(cfg.radio.spreadingFactor - 2);
cfg.radio.dataBinSpacing = cfg.radio.samplesPerSymbol/ ...
    cfg.radio.dataAlphabetSize;
cfg.radio.symbolDurationS = ...
    cfg.radio.samplesPerSymbol/cfg.radio.sampleRateHz;
cfg.radio.fftBinHz = ...
    cfg.radio.sampleRateHz/cfg.radio.samplesPerSymbol;

cfg.frame.payloadSymbols = 28;
spacing = deriveMidambleSpacing(11, 12, 3, cfg);
cfg.frame.midambleSpacingDataSymbols = ...
    spacing.selectedIntegerSpacing;

cfg.monteCarlo.snrDb = -27:-18;
cfg.smoke.snrDb = [-27, -22, -18];

cfg.plot.xLimitsDb = [-28, -18];
cfg.plot.yLimits = [1e-2, 1];

cfg.paper.pointToaS = 0.626688;
cfg.paper.midamblePointToaS = 0.675840;
cfg.paper.pointToaSource = "derived, not reported by paper";
cfg.paper.midamblePointToaSource = "derived, not reported by paper";
cfg.paper.case2StatedFrameDopplerChangeHz = NaN;
cfg.paper.midambleSpacingDerivation = spacing;
end
