function cfg = paperSf12Config()
%PAPERSF12CONFIG Locked configuration for the SF=12 paper reproduction.
% Values described as paper parameters are transcribed from Table 2 and
% Section VII. Implementation choices are documented in PAPER_PROTOCOL.md.

cfg.experimentName = "paper_sf12_midamble_point";

cfg.radio.carrierFrequencyHz = 868e6;
cfg.radio.bandwidthHz = 125e3;
cfg.radio.spreadingFactor = 12;
cfg.radio.sampleRateHz = 125e3;
cfg.radio.ldro = true;
cfg.radio.samplesPerSymbol = 2^cfg.radio.spreadingFactor;
cfg.radio.dataAlphabetSize = 2^(cfg.radio.spreadingFactor - ...
    2*double(cfg.radio.ldro));
cfg.radio.dataBinSpacing = 2^cfg.radio.spreadingFactor / ...
    cfg.radio.dataAlphabetSize;
% The paper's 0.5*B/M frequency-error boundary implies estimating the
% fine-grid FFT peak before mapping it to the nearest LDRO symbol.
cfg.radio.ldroDecisionMode = "peak_quantize";
cfg.radio.symbolDurationS = ...
    cfg.radio.samplesPerSymbol / cfg.radio.sampleRateHz;
cfg.radio.fftBinHz = ...
    cfg.radio.sampleRateHz / cfg.radio.samplesPerSymbol;

cfg.receiver.estimatorFftPaddingFactor = 1;
cfg.receiver.midambleEstimatorFftPaddingFactor = 1;
cfg.receiver.midambleUpdateDelayDataSymbols = 0;
cfg.receiver.midambleEstimatorSnrOffsetDb = 0;
cfg.receiver.midambleEstimatorModel = "physical";
cfg.receiver.midambleInnovationGain = 1;

cfg.orbit.earthRadiusM = 6371e3;
cfg.orbit.altitudeM = 550e3;
cfg.orbit.gravitationalParameterM3S2 = 3.986004418e14;
cfg.orbit.speedOfLightMS = 299792458;
cfg.orbit.case1StartTimeS = -366;
cfg.orbit.case2StartTimeS = 0;
cfg.orbit.frameDopplerTimeScale = 1;

cfg.frame.preambleUpchirps = 8;
cfg.frame.completeDownchirps = 2;
cfg.frame.synchronizationFractionalChirps = 0.25;
cfg.frame.payloadBits = 120;
cfg.frame.codingRateIndex = 1;
cfg.frame.crcEnabled = true;
cfg.frame.implicitHeader = false;
cfg.frame.payloadSymbols = 23;
cfg.frame.midambleSpacingDataSymbols = 3;
% Paper Eq. (20) uses ceil(nSym/nInt), so retain the terminal pilot.
cfg.frame.insertAfterFinalPartialBlock = true;

cfg.channel.ricianKDb = 10;
cfg.channel.ricianCoherence = "packet";
cfg.channel.explicitSignalPowerDbw = 0;
cfg.channel.model = "rician";

cfg.monteCarlo.snrDb = -30:-21;
cfg.monteCarlo.randomSeed = 2025;
cfg.monteCarlo.batchPackets = 64;
cfg.monteCarlo.minimumPackets = 5000;
cfg.monteCarlo.maximumPackets = 50000;
cfg.monteCarlo.minimumSymbolErrors = 1500;
% Deliberate common-random-number design for cross-SF comparisons.
cfg.monteCarlo.commonRandomNumbersAcrossSf = true;
cfg.monteCarlo.commonRandomNumbersAcrossStrategies = false;

cfg.smoke.snrDb = [-30, -25, -21];
cfg.smoke.batchPackets = 8;
cfg.smoke.minimumPackets = 16;
cfg.smoke.maximumPackets = 16;
cfg.smoke.minimumSymbolErrors = 0;

cfg.plot.xLimitsDb = [-31, -21];
cfg.plot.yLimits = [1e-2, 1];
cfg.plot.noDopplerLabel = "AWGN & Rician Fading (No Doppler)";

cfg.paper.pointToaSf12S = 1.090;
cfg.paper.midamblePointToaSf12S = 1.341;
cfg.paper.pointToaS = cfg.paper.pointToaSf12S;
cfg.paper.midamblePointToaS = cfg.paper.midamblePointToaSf12S;
cfg.paper.case2StatedFrameDopplerChangeHz = 510;
cfg.provenance.profile = "final_paper_independent";
cfg.provenance.fittedOrTuned = false;
end
