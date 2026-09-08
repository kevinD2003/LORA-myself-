function config = senloraChannelConfig()
%SENLORACHANNELCONFIG Single-device continuous-frame simulation settings.
%
% The physical channel settings are aligned with lora(CFO).  The time mode
% is continuous because virtual-pilot tracking needs phase continuity from
% one LoRa symbol to the next.

geometry = senloraFigure17Geometry();
config = struct();
config.sf = 11;
config.bandwidthHz = 250e3;
config.sampleRateHz = config.bandwidthHz;
config.carrierFrequencyHz = geometry.config.carrierFrequencyHz;
config.spreadingFactorSamples = 2^config.sf;
config.symbolDurationSec = config.spreadingFactorSamples/config.bandwidthHz;
config.fftBinSpacingHz = config.bandwidthHz/config.spreadingFactorSamples;
config.cr = 3;
config.bootstrapPilotCount = 4;
config.payloadSymbolCount = 28;
config.frameSymbolCount = config.bootstrapPilotCount + ...
    config.payloadSymbolCount;
config.dopplerModel = "paper_piecewise_linear";
config.allowedDopplerModels = ["paper_piecewise_linear", "exact_orbit_sampled"];
config.channel = "unit-power complex baseband AWGN";
config.mapping = "LoRa Gray labels for BER accounting";
config.probMode = "paper";
config.amendMode = "decoded-sign";
config.confidenceThresholdMode = "global";
config.confidenceAlpha = 0.8;
config.confidenceThresholdScale = 1.0;
config.decisionPeakRatioThreshold = 1.05;
config.adaptiveConfidenceEnabled = true;
config.adaptiveConfidenceSwitchSnrDb = -19.5;
config.highSnrConfidenceThresholdScale = 0.65;
config.highSnrDecisionPeakRatioThreshold = 1.5;
config.maxSenLoRaIterations = 5;
config.peakRatioThreshold = 1.05;
config.huberThresholdBins = 0.15;
config.historyDecay = 0.85;
config.geometry = geometry;
config.orbit = geometry.config;
config.scenarios = struct( ...
    "name", {"high_doppler_shift", "high_doppler_rate"}, ...
    "startTimeSec", {geometry.highShiftTimeSec, geometry.highRateTimeSec});
config.randomSeedSymbols = 20260803;
config.randomSeedNoise = 20260804;
config.defaultSampleSnrDb = -15;
end
