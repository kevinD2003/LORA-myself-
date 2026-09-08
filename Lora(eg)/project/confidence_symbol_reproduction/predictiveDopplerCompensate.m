function result = predictiveDopplerCompensate( ...
    rxSymbols, trueBins, cfg, correctSymbolMask)
%PREDICTIVEDOPPLERCOMPENSATE Track CFO using previously correct symbols.
%
% The first cfg.bootstrapPilotCount symbols are assumed correct. The count
% is configurable and is not fixed at four. Starting with the next symbol,
% a least-squares trend predicts the CFO. A correctly
% detected symbol is reconstructed and its PREC residual updates the pilot
% history. The oracle-correct update models the correct-symbol flags from
% the preceding SenLoRa detector under controlled simulation conditions.
% For integration, pass its ConfidentFlag as correctSymbolMask.

arguments
    rxSymbols (:,:) double
    trueBins (:,1) double {mustBeInteger, mustBeNonnegative}
    cfg struct
    correctSymbolMask (:,1) logical = false(0, 1)
end

if ~isfield(cfg, "bootstrapPilotCount")
    cfg.bootstrapPilotCount = 4;
end
if ~isfield(cfg, "historyLength")
    cfg.historyLength = 8;
end
if ~isfield(cfg, "predictorOrder")
    cfg.predictorOrder = 1;
end
if ~isfield(cfg, "initialSearchOffsets")
    cfg.initialSearchOffsets = (-1:0.1:1).';
end
if ~isfield(cfg, "residualSearchOffsets")
    cfg.residualSearchOffsets = (-0.5:0.1:0.5).';
end

sf = cfg.sf;
numSymbols = size(rxSymbols, 1);
numSamples = 2 ^ sf;
if size(rxSymbols, 2) ~= numSamples || numel(trueBins) ~= numSymbols
    error("SenLoRa:PredictorSizeMismatch", ...
        "rxSymbols and trueBins dimensions are inconsistent with SF.");
end
if ~isempty(correctSymbolMask) && numel(correctSymbolMask) ~= numSymbols
    error("SenLoRa:PilotMaskLengthMismatch", ...
        "correctSymbolMask must have one entry per symbol.");
end
if cfg.bootstrapPilotCount < 2 || ...
        cfg.bootstrapPilotCount >= numSymbols || ...
        mod(cfg.bootstrapPilotCount, 1) ~= 0
    error("SenLoRa:InvalidBootstrapCount", ...
        "bootstrapPilotCount must be an integer in [2, numSymbols - 1].");
end
if ~ismember(cfg.predictorOrder, [1 2])
    error("SenLoRa:InvalidPredictorOrder", ...
        "predictorOrder must be 1 (linear) or 2 (quadratic).");
end
if numSymbols < cfg.bootstrapPilotCount + 1
    error("SenLoRa:TooFewSymbols", ...
        "At least one data symbol must follow the initial pilots.");
end

if isfield(cfg, "initialRotationBank")
    initialBank = cfg.initialRotationBank;
else
    initialBank = makePhaseRotationBank(sf, cfg.initialSearchOffsets);
end
if isfield(cfg, "residualRotationBank")
    residualBank = cfg.residualRotationBank;
else
    residualBank = makePhaseRotationBank(sf, cfg.residualSearchOffsets);
end
sampleIndex = 0:(numSamples - 1);

detectedBins = zeros(numSymbols, 1);
predictedCfo = nan(numSymbols, 1);
measuredCfo = nan(numSymbols, 1);
measuredResidual = nan(numSymbols, 1);
predictedPhaseStart = nan(numSymbols, 1);
measuredPhaseError = nan(numSymbols, 1);
pilotUpdateFlag = false(numSymbols, 1);
correctFlag = false(numSymbols, 1);
peakRatio = nan(numSymbols, 1);
compensatedSymbols = complex(zeros(size(rxSymbols)));
pilotIndices = zeros(0, 1);
pilotCfo = zeros(0, 1);
phaseState = 0;

for symbolIdx = 1:cfg.bootstrapPilotCount
    [measuredCfo(symbolIdx), ~, peakRatio(symbolIdx), phaseAtPilot] = ...
        estimateResidualByPhaseRotation( ...
        rxSymbols(symbolIdx, :), trueBins(symbolIdx), sf, ...
        cfg.initialSearchOffsets, initialBank);
    predictedCfo(symbolIdx) = measuredCfo(symbolIdx);
    detectedBins(symbolIdx) = trueBins(symbolIdx);
    correctFlag(symbolIdx) = true;
    pilotUpdateFlag(symbolIdx) = true;
    predictedPhaseStart(symbolIdx) = phaseAtPilot;
    pilotIndices(end + 1, 1) = symbolIdx; %#ok<AGROW>
    pilotCfo(end + 1, 1) = measuredCfo(symbolIdx); %#ok<AGROW>
    pilotCorrection = exp(-1i * (phaseAtPilot + 2 * pi * ...
        measuredCfo(symbolIdx) * sampleIndex / numSamples));
    compensatedSymbols(symbolIdx, :) = ...
        rxSymbols(symbolIdx, :) .* pilotCorrection;
    if symbolIdx == cfg.bootstrapPilotCount
        phaseState = phaseAtPilot + 2 * pi * measuredCfo(symbolIdx);
    end
end

for symbolIdx = (cfg.bootstrapPilotCount + 1):numSymbols
    historyCount = min(cfg.historyLength, numel(pilotIndices));
    historyRange = ...
        (numel(pilotIndices) - historyCount + 1):numel(pilotIndices);
    fitIndices = pilotIndices(historyRange);
    fitCfo = pilotCfo(historyRange);

    if numel(fitIndices) >= 2
        centeredIndices = fitIndices - mean(fitIndices);
        fitOrder = min(cfg.predictorOrder, numel(fitIndices) - 1);
        coefficients = polyfit(centeredIndices, fitCfo, fitOrder);
        predictedCfo(symbolIdx) = polyval( ...
            coefficients, symbolIdx - mean(fitIndices));
    else
        predictedCfo(symbolIdx) = fitCfo(end);
    end

    predictedPhaseStart(symbolIdx) = phaseState;
    correction = exp(-1i * (phaseState + 2 * pi * ...
        predictedCfo(symbolIdx) * sampleIndex / numSamples));
    compensatedSymbol = rxSymbols(symbolIdx, :) .* correction;
    compensatedSymbols(symbolIdx, :) = compensatedSymbol;
    [decision, decisionRatio] = hardDemodLoRaWithCfo( ...
        compensatedSymbol, sf, 0);
    detectedBins(symbolIdx) = decision;
    peakRatio(symbolIdx) = decisionRatio;
    correctFlag(symbolIdx) = decision == trueBins(symbolIdx);

    if isempty(correctSymbolMask)
        updateAllowed = correctFlag(symbolIdx);
    else
        updateAllowed = correctSymbolMask(symbolIdx);
    end

    if updateAllowed
        [residualEstimate, ~, ~, phaseError] = ...
            estimateResidualByPhaseRotation( ...
            compensatedSymbol, decision, sf, ...
            cfg.residualSearchOffsets, residualBank);
        measuredResidual(symbolIdx) = residualEstimate;
        measuredPhaseError(symbolIdx) = phaseError;
        measuredCfo(symbolIdx) = ...
            predictedCfo(symbolIdx) + residualEstimate;
        pilotUpdateFlag(symbolIdx) = true;
        pilotIndices(end + 1, 1) = symbolIdx; %#ok<AGROW>
        pilotCfo(end + 1, 1) = measuredCfo(symbolIdx); %#ok<AGROW>
        phaseState = phaseState + phaseError + ...
            2 * pi * measuredCfo(symbolIdx);
    else
        phaseState = phaseState + 2 * pi * predictedCfo(symbolIdx);
    end
end

result = struct();
result.detectedBins = detectedBins;
result.correctFlag = correctFlag;
result.predictedCfo = predictedCfo;
result.measuredCfo = measuredCfo;
result.measuredResidual = measuredResidual;
result.predictedPhaseStart = predictedPhaseStart;
result.measuredPhaseError = measuredPhaseError;
result.pilotUpdateFlag = pilotUpdateFlag;
result.peakRatio = peakRatio;
result.compensatedSymbols = compensatedSymbols;
result.pilotIndices = pilotIndices;
result.pilotCfo = pilotCfo;
result.staticCfoEstimate = mean(measuredCfo(1:cfg.bootstrapPilotCount));
result.bootstrapPilotCount = cfg.bootstrapPilotCount;
result.usedExternalCorrectMask = ~isempty(correctSymbolMask);

end
