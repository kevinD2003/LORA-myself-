function cfg = sf12PaperCommonConfig()
%SF12PAPERCOMMONCONFIG Frozen paper conditions and paired-run policy.

configFolder = fileparts(mfilename('fullpath'));
manifestFile = fullfile(configFolder,'sf12ReceiverParameterManifest.json');
manifest = jsondecode(fileread(manifestFile));

cfg.name = "stage55_sf12_paper_conditions_v2";
cfg.radio.sf = 12;
cfg.radio.bandwidthHz = 125e3;
cfg.radio.sampleRateHz = 125e3;
cfg.radio.carrierFrequencyHz = 868e6;
cfg.radio.ldro = true;
cfg.radio.samplesPerSymbol = 2^cfg.radio.sf;
cfg.radio.symbolDurationSec = cfg.radio.samplesPerSymbol/cfg.radio.sampleRateHz;
cfg.radio.fftBinHz = cfg.radio.bandwidthHz/cfg.radio.samplesPerSymbol;
cfg.radio.dataBinSpacing = 4;
cfg.radio.dataAlphabetSize = 2^(cfg.radio.sf-2);

cfg.frame.preambleUpchirps = 8;
cfg.frame.completeDownchirps = 2;
cfg.frame.synchronizationFractionalChirps = 0.25;
cfg.frame.payloadBits = 120;
cfg.frame.cr = 1;
cfg.frame.payloadSymbolCount = 23;
cfg.frame.midambleSpacing = 3;
cfg.frame.trackingMidambleCount = 7;
cfg.frame.toaMidambleCount = 8;

cfg.orbit.earthRadiusM = 6371e3;
cfg.orbit.altitudeM = 550e3;
cfg.orbit.gravitationalParameterM3S2 = 3.986004418e14;
cfg.orbit.speedOfLightMps = 299792458;
cfg.orbit.case1StartTimeSec = -366;
cfg.orbit.case2StartTimeSec = 0;
cfg.orbit.disableDoppler = false;

cfg.channel.model = "packet_flat_rician";
cfg.channel.ricianKDb = 10;
cfg.channel.signalPower = 1;
cfg.channel.disableNoise = false;

cfg.receiver.manifestFile = manifestFile;
cfg.receiver.manifest = manifest;
cfg.receiver.peakRatioThreshold = manifest.parameters.peakRatioThreshold;
cfg.receiver.residualSearchHalfWidthBins = ...
    manifest.parameters.residualSearchHalfWidthBins;
cfg.receiver.residualSearchStepBins = ...
    manifest.parameters.residualSearchStepBins;
cfg.receiver.innovationLimitHz = manifest.parameters.innovationLimitHz;
cfg.receiver.innovationGain = manifest.parameters.innovationGain;
cfg.receiver.maximumRateHzPerSec = manifest.parameters.maximumRateHzPerSec;
cfg.receiver.historyLength = manifest.parameters.historyLength;
cfg.receiver.singleSymbolCfoStdHz = ...
    manifest.parameters.singleSymbolCfoStdHz;
cfg.receiver.requireStableDecision = ...
    manifest.parameters.requireStableDecision;

cfg.monteCarlo.snrDb = -30:-21;
cfg.monteCarlo.minimumPackets = 5000;
cfg.monteCarlo.maximumPackets = 50000;
cfg.monteCarlo.minimumSymbolErrors = 1500;
cfg.monteCarlo.checkpointEveryPackets = 250;
cfg.seeds.calibrationPayloadBase = 2027121200;
cfg.seeds.calibrationNoiseBase = 2027121300;
cfg.seeds.validationPayloadBase = 2027122200;
cfg.seeds.validationNoiseBase = 2027122300;
cfg.seeds.formalPayloadBase = 2027123200;
cfg.seeds.formalNoiseBase = 2027123300;

cfg.provenance.profile = "SF12 paper conditions; no image calibration";
cfg.provenance.fittedOrTuned = false;
cfg.provenance.version = "v2-physics-gated-vp";
sf12ValidateConfig(cfg);
end
