function result = trackSenLoRaVirtualPilots( ...
        rxSymbols, config, knownPilotBins, acceptedMask, options)
%TRACKSENLORAVIRTUALPILOTS Track dynamic CFO using accepted virtual pilots.
%
% KNOWNPILOTBINS contains only bootstrap symbols. ACCEPTEDMASK comes from
% the previous SenLoRa confidence pass; payload truth is never consumed.

arguments
    rxSymbols (:,:) double
    config (1,1) struct
    knownPilotBins (:,1) double
    acceptedMask (:,1) logical = false(0,1)
    options.PilotConfidence (:,1) double = zeros(0,1)
    options.PilotThreshold (1,1) double = NaN
    options.HistoryDecay (1,1) double {mustBeGreaterThan(options.HistoryDecay,0),mustBeLessThanOrEqual(options.HistoryDecay,1)} = 0.85
    options.PeakRatioThreshold (1,1) double = 1.05
    options.HuberThresholdBins (1,1) double = 0.15
    options.InitialStep (1,1) double {mustBePositive} = 0.1
    options.ResidualOffsets (:,1) double = (-0.5:0.1:0.5).'
    options.ForceAccept (1,1) logical = false
    options.DecisionPeakRatioThreshold (1,1) double = 1.05
    options.MinResidualPeakMetric (1,1) double = 0.6
    options.MaxRateBinsPerSec (1,1) double = 1.5
end

numSymbols = size(rxSymbols, 1);
numSamples = 2^config.sf;
bootstrapCount = numel(knownPilotBins);
if size(rxSymbols, 2) ~= numSamples
    error("SenLoRa:InvalidTrackingWaveform", ...
        "rxSymbols must have 2^SF samples per row.");
end
if bootstrapCount < 2 || bootstrapCount >= numSymbols
    error("SenLoRa:InvalidBootstrapCount", ...
        "At least two bootstrap pilots and one payload symbol are required.");
end
if any(knownPilotBins < 0 | knownPilotBins >= numSamples)
    error("SenLoRa:InvalidBootstrapBin", ...
        "Known pilot bins must be in [0,2^SF-1].");
end
if isempty(acceptedMask)
    acceptedMask = false(numSymbols, 1);
elseif numel(acceptedMask) ~= numSymbols
    error("SenLoRa:InvalidPilotMask", ...
        "acceptedMask must contain one entry per frame symbol.");
end
if isempty(options.PilotConfidence)
    pilotConfidenceInput = nan(numSymbols, 1);
elseif numel(options.PilotConfidence) == numSymbols
    pilotConfidenceInput = options.PilotConfidence;
else
    error("SenLoRa:InvalidPilotConfidence", ...
        "PilotConfidence must be empty or one value per symbol.");
end

sampleIndex = 0:(numSamples-1);
sampleTime = sampleIndex/config.sampleRateHz;
symbolDuration = config.symbolDurationSec;

detectedBins = zeros(numSymbols, 1);
peakRatio = nan(numSymbols, 1);
predictedCfoBins = nan(numSymbols, 1);
predictedCfoHz = nan(numSymbols, 1);
predictedRateBinsPerSec = nan(numSymbols, 1);
predictedRateHzPerSec = nan(numSymbols, 1);
predictedPhaseStartRad = nan(numSymbols, 1);
measuredCfoBins = nan(numSymbols, 1);
measuredResidualBins = nan(numSymbols, 1);
measuredResidualPhaseRad = nan(numSymbols, 1);
residualPeakRatio = nan(numSymbols, 1);
pilotUpdateFlag = false(numSymbols, 1);
pilotUpdateRequested = acceptedMask;
pilotCount = zeros(numSymbols, 1);
effectiveHistoryCount = zeros(numSymbols, 1);
compensatedSymbols = complex(zeros(size(rxSymbols)));

pilotIndices = zeros(0,1);
pilotCfoBins = zeros(0,1);
pilotPhaseStartRad = zeros(0,1);
pilotConfidence = zeros(0,1);
pilotPeakRatio = zeros(0,1);
phaseState = 0;

bootstrapEstimate = senloraEstimateBootstrapPilots( ...
    rxSymbols(1:bootstrapCount,:),knownPilotBins,config.sf, ...
    Step=options.InitialStep);

for symbolIdx = 1:bootstrapCount
    estimate = bootstrapEstimate.cfoBins(symbolIdx);
    ratio = bootstrapEstimate.peakRatio(symbolIdx);
    phaseEstimate = bootstrapEstimate.phaseStartRad(symbolIdx);
    detectedBins(symbolIdx) = knownPilotBins(symbolIdx);
    predictedCfoBins(symbolIdx) = estimate;
    predictedCfoHz(symbolIdx) = estimate*config.fftBinSpacingHz;
    measuredCfoBins(symbolIdx) = estimate;
    measuredResidualBins(symbolIdx) = estimate;
    measuredResidualPhaseRad(symbolIdx) = phaseEstimate;
    residualPeakRatio(symbolIdx) = ratio;
    peakRatio(symbolIdx) = ratio;
    predictedPhaseStartRad(symbolIdx) = phaseEstimate;
    pilotUpdateFlag(symbolIdx) = true;
    pilotIndices(end+1,1) = symbolIdx; %#ok<AGROW>
    pilotCfoBins(end+1,1) = estimate; %#ok<AGROW>
    pilotPhaseStartRad(end+1,1) = phaseEstimate; %#ok<AGROW>
    pilotConfidence(end+1,1) = 1; %#ok<AGROW>
    pilotPeakRatio(end+1,1) = max(ratio, options.PeakRatioThreshold); %#ok<AGROW>
    correction = exp(-1i*(phaseEstimate + ...
        2*pi*estimate*sampleIndex/numSamples));
    compensatedSymbols(symbolIdx,:) = rxSymbols(symbolIdx,:).*correction;
    if symbolIdx == bootstrapCount
        [~, bootstrapRate] = fitPilotTrajectory( ...
            pilotIndices, pilotCfoBins, pilotConfidence, pilotPeakRatio, ...
            symbolIdx+1, config, options);
        phaseState = phaseEstimate + 2*pi*integratedCfoBins( ...
            estimate, bootstrapRate, symbolDuration);
    end
end

for symbolIdx = (bootstrapCount+1):numSymbols
    [predictedCenter, predictedRate] = fitPilotTrajectory( ...
        pilotIndices, pilotCfoBins, pilotConfidence, pilotPeakRatio, ...
        symbolIdx, config, options);
    predictedCfoBins(symbolIdx) = predictedCenter;
    predictedCfoHz(symbolIdx) = predictedCenter*config.fftBinSpacingHz;
    predictedRateBinsPerSec(symbolIdx) = predictedRate;
    predictedRateHzPerSec(symbolIdx) = predictedRate*config.fftBinSpacingHz;
    predictedPhaseStartRad(symbolIdx) = phaseState;
    predictedStartCfo = predictedCenter - predictedRate*symbolDuration/2;
    predictedPhase = phaseState + 2*pi*( ...
        predictedStartCfo*(sampleTime/symbolDuration) + ...
        0.5*predictedRate*sampleTime.^2/symbolDuration);
    compensated = rxSymbols(symbolIdx,:).*exp(-1i*predictedPhase);
    compensatedSymbols(symbolIdx,:) = compensated;
    [detectedBin, decisionRatio] = senloraHardDemodulate(compensated, config.sf);
    detectedBins(symbolIdx) = detectedBin;
    peakRatio(symbolIdx) = decisionRatio;

    if acceptedMask(symbolIdx)
        [residual, ~, residualRatio, residualPhase, residualDetails] = ...
            senloraPhaseRotationEstimate(compensated, detectedBin, config.sf, ...
            CandidateOffsets=options.ResidualOffsets, LocalOnly=true);
        residualPeakRatio(symbolIdx) = residualRatio;
        if options.ForceAccept || (residualRatio >= options.PeakRatioThreshold && ...
                ~residualDetails.peakAtBoundary && ...
                decisionRatio >= options.DecisionPeakRatioThreshold && ...
                residualDetails.peakMetric >= options.MinResidualPeakMetric)
            measuredResidualBins(symbolIdx) = residual;
            measuredResidualPhaseRad(symbolIdx) = residualPhase;
            measuredCfoBins(symbolIdx) = predictedCenter + residual;
            measuredCenterPhase = phaseState + residualPhase;
            confidenceValue = pilotConfidenceInput(symbolIdx);
            if ~isfinite(confidenceValue)
                confidenceValue = 1;
            end
            pilotIndices(end+1,1) = symbolIdx; %#ok<AGROW>
            pilotCfoBins(end+1,1) = measuredCfoBins(symbolIdx); %#ok<AGROW>
            pilotPhaseStartRad(end+1,1) = measuredCenterPhase; %#ok<AGROW>
            pilotConfidence(end+1,1) = confidenceValue; %#ok<AGROW>
            pilotPeakRatio(end+1,1) = residualRatio; %#ok<AGROW>
            pilotUpdateFlag(symbolIdx) = true;
            phaseState = measuredCenterPhase + 2*pi*integratedCfoBins( ...
                measuredCfoBins(symbolIdx), predictedRate, symbolDuration);
        else
            phaseState = phaseState + 2*pi*integratedCfoBins( ...
                predictedCenter, predictedRate, symbolDuration);
        end
    else
        phaseState = phaseState + 2*pi*integratedCfoBins( ...
            predictedCenter, predictedRate, symbolDuration);
    end
    pilotCount(symbolIdx) = numel(pilotIndices);
    effectiveHistoryCount(symbolIdx) = sum( ...
        options.HistoryDecay.^(symbolIdx-pilotIndices));
end

pilotCount(1:bootstrapCount) = (1:bootstrapCount).';
effectiveHistoryCount(1:bootstrapCount) = (1:bootstrapCount).';
result = struct( ...
    "detectedBins", detectedBins, ...
    "peakRatio", peakRatio, ...
    "predictedCfoBins", predictedCfoBins, ...
    "predictedCfoHz", predictedCfoHz, ...
    "predictedRateBinsPerSec", predictedRateBinsPerSec, ...
    "predictedRateHzPerSec", predictedRateHzPerSec, ...
    "predictedPhaseStartRad", predictedPhaseStartRad, ...
    "measuredCfoBins", measuredCfoBins, ...
    "measuredResidualBins", measuredResidualBins, ...
    "measuredResidualPhaseRad", measuredResidualPhaseRad, ...
    "residualPeakRatio", residualPeakRatio, ...
    "pilotUpdateRequested", pilotUpdateRequested, ...
    "pilotUpdateFlag", pilotUpdateFlag, ...
    "pilotCount", pilotCount, ...
    "effectiveHistoryCount", effectiveHistoryCount, ...
    "compensatedSymbols", compensatedSymbols, ...
    "pilotIndices", pilotIndices, ...
    "pilotCfoBins", pilotCfoBins, ...
    "pilotPhaseStartRad", pilotPhaseStartRad, ...
    "pilotConfidence", pilotConfidence, ...
    "pilotPeakRatio", pilotPeakRatio, ...
    "staticCfoEstimate", mean(pilotCfoBins(1:bootstrapCount)), ...
    "bootstrapPilotCount", bootstrapCount);
end

function [predictedCenter, predictedRate] = fitPilotTrajectory( ...
        pilotIndices, pilotCfoBins, pilotConfidence, pilotPeakRatio, ...
        targetIndex, config, options)
targetTime = (targetIndex-0.5)*config.symbolDurationSec;
pilotTime = (pilotIndices-0.5)*config.symbolDurationSec;
age = max(0, targetIndex-pilotIndices);
weights = options.HistoryDecay.^age;
if isfinite(options.PilotThreshold)
    confidenceWeight = min(4, max(1, pilotConfidence/options.PilotThreshold));
else
    confidenceWeight = ones(size(weights));
end
peakWeight = min(3, max(1, pilotPeakRatio));
weights = weights.*confidenceWeight.*peakWeight;

if numel(pilotIndices) < 2
    predictedCenter = pilotCfoBins(end);
    predictedRate = 0;
    return
end

x = pilotTime-targetTime;
design = [ones(size(x)), x];
beta = weightedLinearFit(design, pilotCfoBins, weights);
residual = pilotCfoBins-design*beta;
huberWeight = min(1, options.HuberThresholdBins./max(abs(residual), eps));
beta = weightedLinearFit(design, pilotCfoBins, weights.*huberWeight);
predictedRate = min(max(beta(2), -options.MaxRateBinsPerSec), ...
        options.MaxRateBinsPerSec);
% If the robust rate is limited, recompute the value at the target time;
% retaining beta(1) from the unconstrained fit would silently preserve the
% original excessive slope as a frequency offset.
predictedCenter = sum((weights.*huberWeight) .* ...
    (pilotCfoBins-predictedRate*x))/sum(weights.*huberWeight);
end

function beta = weightedLinearFit(design, response, weights)
sqrtWeight = sqrt(max(weights, eps));
weightedDesign = design.*sqrtWeight;
weightedResponse = response.*sqrtWeight;
beta = weightedDesign\weightedResponse;
end

function phaseCycles = integratedCfoBins(centerCfo, rateBinsPerSec, symbolDuration)
startCfo = centerCfo-rateBinsPerSec*symbolDuration/2;
% CFO is expressed in FFT bins (cycles per LoRa symbol), while the
% fitted rate is bins per second.  Integrating over one symbol therefore
% divides the time integral by symbolDuration.
phaseCycles = startCfo + 0.5*rateBinsPerSec*symbolDuration;
end
