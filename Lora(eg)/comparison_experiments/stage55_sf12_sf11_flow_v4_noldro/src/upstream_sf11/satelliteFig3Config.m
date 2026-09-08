function config = satelliteFig3Config()
%SATELLITEFIG3CONFIG Single-device Figure 3 LoRa satellite configuration.
%   The constants reproduce the dynamic-Doppler setting in the satellite
%   orthogonality paper.  This project deliberately does not use the old
%   two-device Figure 17 geometry.

config = struct();
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

config.sf = 11;
config.bandwidthHz = 250e3;
config.sampleRateHz = config.bandwidthHz;
config.samplesPerSymbol = 2^config.sf;
config.symbolDurationSec = config.samplesPerSymbol/config.sampleRateHz;
config.fftBinSpacingHz = config.bandwidthHz/config.samplesPerSymbol;
config.cr = 3;
config.bootstrapPilotCount = 8;
config.payloadSymbolCount = 112; % 16 LoRa blocks x (4 + CR) symbols.
config.frameSymbolCount = config.bootstrapPilotCount + config.payloadSymbolCount;
config.virtualPilotHistoryLength = 8;
config.maxSenLoRaIterations = 5;
config.confidenceAlpha = 0.8;
config.confidenceThresholdScale = 1.0;
config.amendLlrMix = 0.5; % Default soft-decoder amendment strength.
% Receiver-only virtual-pilot confidence policy.  The two margins are the
% conservative Stage-7 soft-Hamming winner-versus-runner-up levels.  Below
% the SNR lock, candidates remain quarantined and cannot change the rolling
% eight-pilot Doppler state.
config.confidencePromotionSnrDb = -16;
config.confidenceAnchorMargin = 1.0e3;
config.confidencePromotionMargin = 2.0e3;
% A separately validated narrow low-SNR window.  It is intentionally not
% extended to -22 dB, where the independent feasibility test found no gain.
config.confidenceLowSnrCenterDb = -20;
config.confidenceLowSnrHalfWidthDb = 0.75;
config.confidenceLowSnrAnchorMargin = 55;
config.confidenceLowSnrPromotionMargin = 120;
config.confidenceAnchorBlockCount = 2;
config.confidenceMinimumAnchorCount = 2;
config.confidenceInnovationLimitBins = 0.22;
% SNR-independent five-pass SenLoRa admission.  Stage 55's disjoint-seed,
% gate-by-gate audit showed that 0.25 was the dominant pilot-starvation
% source.  A 0.15 floor retained zero false pilots in both independent
% audit sets while increasing rate-release coverage; it was not selected
% from the frozen Stage 53 BER curves.
config.senloraMinimumMarginRatio = 0.15;
config.senloraRequireSoftHardAgreement = true;
% Keep accepted virtual-pilot labels on the compensated hard LoRa decision
% even though the final delivered payload uses ML soft Hamming decoding.
config.senloraUseSoftDecodedPilotLabels = false;
% Confidence from one Hamming block may update the rolling history only
% after that complete block; it can compensate subsequent symbols only.
config.senloraUseCausalConfidenceTiming = true;
config.residualPeakRatioThreshold = 1.05;
config.decisionPeakRatioThreshold = 1.05;
config.historyDecay = 0.85;
config.huberThresholdBins = 0.15;
config.residualSearchBins = (-0.5:0.1:0.5).';
config.bootstrapSearchStepBins = 0.05;
config.maxRateBinsPerSec = 2.0;
config.rateReplayPriorHalfWidthBinsPerSec = 0.1;
config.rateReplayPriorStepBinsPerSec = 0.1;
config.senloraRateReleasePilotCount = 2;
config.senloraRateTrackingDeviationLimitBinsPerSec = 0.1;
% Stage55 quality-aware virtual-pilot tracking.  These values were frozen
% from the disjoint 202645xxxx CFO-quality audit, never from BER.  A raw
% single-symbol CFO observation has about 0.075-bin standard deviation;
% the 0.35 innovation gain is the corresponding variance-ratio fusion
% with the rolling prediction.  A phase-pair observation must agree both
% with the causal phase trajectory and with the independent single-symbol
% CFO observation before it can replace that noisier observation.
config.senloraVirtualPilotInnovationGain = 0.35;
config.senloraPhasePairInnovationGain = 0.60;
config.senloraVirtualPilotCfoStdBins = 0.075;
config.senloraPhasePairInnovationLimitBins = 0.10;
config.senloraPhasePairAgreementLimitBins = 0.15;
config.senloraVirtualPilotRateStdLimitBinsPerSec = 0.10;
% Hard PREC and SenLoRa share the same receiver-visible orbital rate
% prior.  Their only intended difference is virtual-pilot confidence.
config.hardPrecRateReleasePilotCount = 2;
config.hardPrecRateTrackingDeviationLimitBinsPerSec = 0.1;
% Trigger blind rate reacquisition only when the ordinary SenLoRa replay
% cannot confirm the minimum two independent payload anchors.
config.rateReplayMinimumBaselinePilots = ...
    config.confidenceMinimumAnchorCount;

config.trajectoryPlotHalfSpanSec = 400;
config.trajectoryTimeStepSec = 0.25;
config.scenarios = struct( ...
    'name', {'high_doppler_shift', 'high_doppler_rate'}, ...
    'startTimeSec', {NaN, NaN});
config.randomSeedSymbols = 20260804;
config.randomSeedNoise = 20260805;
end
