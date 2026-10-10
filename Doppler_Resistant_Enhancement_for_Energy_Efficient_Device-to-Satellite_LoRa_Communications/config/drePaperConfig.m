function config = drePaperConfig()
%DREPAPERCONFIG Frozen WSA 2025 paper-anchor configuration.

config = struct();
config.identity = 'dietl-wsa2025-table-iv-v1';
config.speedOfLightMps = 299792458;
config.gravityMps2 = 9.81;
config.earthRadiusM = 6371e3;
config.orbitHeightM = 400e3;
config.carrierFrequencyHz = 2.1e9;
config.reportedBandwidthHz = 62.6e3;
config.bandwidthHz = 62.5e3;
config.sampleRateHz = config.bandwidthHz;
config.sf = 12;
config.samplesPerSymbol = 2^config.sf;
config.symbolDurationSec = config.samplesPerSymbol/config.sampleRateHz;
config.fftBinSpacingHz = config.bandwidthHz/config.samplesPerSymbol;
config.packetSymbolCount = 51;
config.preambleSymbolCount = 8;
config.payloadSymbolCount = config.packetSymbolCount-config.preambleSymbolCount;
config.zeroPaddingFactor = 4;
config.centroidSampleCount = 10;
config.hannDefinition = 'periodic';
config.phaseModel = 'paper-equation-15-product';
config.snrDb = [0 -5 -10 -15 -20].';
config.randomSeed = 20250916;
config.paperAdaptiveSerPercent = [0 0 1.11 4.82 13.44].';
config.paperFixedSerPercent = [22.75 23.06 24.30 28.66 36.57].';
config.paperAdaptiveMeanErrorMagnitude = [0 0 2.16 2.58 491.17].';
config.paperFixedMeanErrorMagnitude = [1.56 1.58 1.57 1.59 126.32].';
config.packetGapSec = 0;
config.maximumPackets = inf;
config.algorithmVersion = 'fixed-and-adaptive-lr-eq18-to-eq22-v2';
end
