function config = sf12Sf11FlowConfig()
%SF12SF11FLOWCONFIG Frozen experiment identity for the SF12 V3 project.

config = struct();
config.projectRoot = fileparts(fileparts(mfilename('fullpath')));

config.speedOfLightMps = 3e8;
config.gravityMps2 = 9.8;
config.earthRadiusM = 6371e3;
config.earthRotationRadPerSec = 7.292e-5;
config.orbitHeightM = 550e3;
config.inclinationRad = deg2rad(15);
config.carrierFrequencyHz = 868e6;
config.theoreticalMaxElevationRad = deg2rad(56);
config.minimumElevationRad = deg2rad(10);
config.maximumElevationRad = deg2rad(50);
config.centralVisibilityTimeSec = 0;

config.physicalSf = 12;
config.effectiveDataSf = 10;
config.dataAlphabetSize = 2^config.effectiveDataSf;
config.dataBinSpacing = 2^(config.physicalSf-config.effectiveDataSf);
config.bandwidthHz = 125e3;
config.sampleRateHz = config.bandwidthHz;
config.samplesPerSymbol = 2^config.physicalSf;
config.symbolDurationSec = config.samplesPerSymbol/config.sampleRateHz;
config.fftBinSpacingHz = config.bandwidthHz/config.samplesPerSymbol;

config.cr = 3;
config.hammingCodewordLength = 4+config.cr;
config.hammingBlockCount = 16;
config.payloadSymbolCount = config.hammingBlockCount*config.hammingCodewordLength;
config.informationBitCount = config.hammingBlockCount*config.effectiveDataSf*4;
config.bootstrapPilotCount = 8;
config.maxSenLoRaIterations = 5;
config.virtualPilotHistoryLength = 8;
config.paperMidambleInterval = 3;
config.paperMidambleCount = ceil(config.payloadSymbolCount/config.paperMidambleInterval);
config.noMidambleFrameSymbolCount = config.bootstrapPilotCount+config.payloadSymbolCount;
config.commonTimelineSymbolCount = config.noMidambleFrameSymbolCount+config.paperMidambleCount;

config.ricianKDb = 10;
config.ricianModel = 'packet-flat';
config.usesOrbitPrior = false;
config.snrDb = (-30:-21).';
config.minimumFormalPassesPerSnr = 5;
config.maximumFormalPassesPerSnr = 20;

config.methodNames = { ...
    'Huang-PREC-static-CP-SF12'; ...
    'Stage55-VP-quality-CR3-SF12'; ...
    'Paper-Midamble-Point-SF12-CR3-adapted'};

config.seeds = struct( ...
    'mechanismPayloadBase',2028000000, ...
    'mechanismNoiseBase',2029000000, ...
    'mechanismChannelBase',2030000000, ...
    'validationPayloadBase',2031000000, ...
    'validationNoiseBase',2032000000, ...
    'validationChannelBase',2033000000, ...
    'formalPayloadBase',2034000000, ...
    'formalNoiseBase',2035000000, ...
    'formalChannelBase',2036000000, ...
    'bootstrapResampleBase',2037000000);

% Stage 5 must replace these NaNs from independent mechanism calibration.
config.calibrationStatus = 'unfrozen';
config.receiver = struct( ...
    'bootstrapSearchStepBins',NaN, ...
    'singleSymbolCfoStdBins',NaN, ...
    'innovationLimitBins',NaN, ...
    'huberThresholdBins',NaN, ...
    'phasePairInnovationLimitBins',NaN, ...
    'phasePairAgreementLimitBins',NaN, ...
    'virtualPilotRateStdLimitBinsPerSec',NaN, ...
    'softHammingMarginRatio',NaN, ...
    'confidenceSnrWindowDb',[NaN NaN], ...
    'historyRateDeviationLimitBinsPerSec',NaN);

v3ValidateConfig(config);
end
