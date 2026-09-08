function [offsetEstimate, metric, peakRatio, phaseEstimate] = ...
    estimateResidualByPhaseRotation( ...
    symbolSamples, knownBin, sf, candidateOffsets, rotationBank)
%ESTIMATERESIDUALBYPHASEROTATION Estimate CFO using the PREC rotation idea.
%
% After removing the known LoRa symbol, each candidate complex rotation is
% applied to the residual tone. The maximum coherent sum gives the offset.

arguments
    symbolSamples (1,:) double
    knownBin (1,1) double {mustBeInteger, mustBeNonnegative}
    sf (1,1) double {mustBeInteger, mustBePositive}
    candidateOffsets (:,1) double
    rotationBank (:,:) double = complex(zeros(0, 0))
end

numSamples = 2 ^ sf;
if numel(symbolSamples) ~= numSamples
    error("SenLoRa:InvalidSymbolLength", ...
        "symbolSamples must contain 2^SF samples.");
end
if knownBin >= numSamples
    error("SenLoRa:InvalidSymbolBin", ...
        "knownBin must be in [0, 2^SF - 1].");
end

if isempty(rotationBank)
    rotationBank = makePhaseRotationBank(sf, candidateOffsets);
elseif ~isequal(size(rotationBank), [numel(candidateOffsets), numSamples])
    error("SenLoRa:InvalidRotationBank", ...
        "rotationBank dimensions do not match candidates and SF.");
end

knownWaveform = modulateLoRaSymbol(knownBin, sf);
residualTone = symbolSamples .* conj(knownWaveform);
coherentOutput = rotationBank * residualTone.' / numSamples;
metric = abs(coherentOutput);

[peakMetric, peakIdx] = max(metric);
offsetEstimate = candidateOffsets(peakIdx);

% Quadratic interpolation improves the estimate below the scan step.
if peakIdx > 1 && peakIdx < numel(candidateOffsets)
    spacing = candidateOffsets(2) - candidateOffsets(1);
    localPower = metric((peakIdx - 1):(peakIdx + 1)) .^ 2;
    denominator = localPower(1) - 2 * localPower(2) + localPower(3);
    if abs(denominator) > eps
        fractionalIndex = 0.5 * ...
            (localPower(1) - localPower(3)) / denominator;
        fractionalIndex = min(max(fractionalIndex, -1), 1);
        offsetEstimate = offsetEstimate + fractionalIndex * spacing;
    end
end

sortedMetric = sort(metric, "descend");
if numel(sortedMetric) >= 2
    peakRatio = peakMetric / max(sortedMetric(2), eps);
else
    peakRatio = Inf;
end

sampleIndex = 0:(numSamples - 1);
coherentAtEstimate = sum(residualTone .* exp(-1i * 2 * pi * ...
    offsetEstimate * sampleIndex / numSamples)) / numSamples;
phaseEstimate = angle(coherentAtEstimate);

end
