function [rxSymbols, txSymbols, truePhaseStart] = ...
    generateDopplerLoRaSymbols(symbolBins, sf, cfoBins, sampleSnrDb)
%GENERATEDOPPLERLORASYMBOLS Generate noisy LoRa symbols with smooth CFO.
%
% cfoBins is normalized by the LoRa FFT-bin spacing. Phase is accumulated
% continuously across symbol boundaries.

arguments
    symbolBins (:,1) double {mustBeInteger, mustBeNonnegative}
    sf (1,1) double {mustBeInteger, mustBePositive}
    cfoBins (:,1) double
    sampleSnrDb (1,1) double
end

numSymbols = numel(symbolBins);
numSamples = 2 ^ sf;
if numel(cfoBins) ~= numSymbols
    error("SenLoRa:CfoLengthMismatch", ...
        "cfoBins must have one value per LoRa symbol.");
end
if any(symbolBins >= numSamples)
    error("SenLoRa:InvalidSymbolBin", ...
        "symbolBins must be in [0, 2^SF - 1].");
end

sampleIndex = 0:(numSamples - 1);
txSymbols = complex(zeros(numSymbols, numSamples));
truePhaseStart = zeros(numSymbols, 1);
phaseState = 0;

for symbolIdx = 1:numSymbols
    truePhaseStart(symbolIdx) = phaseState;
    dopplerPhase = phaseState + ...
        2 * pi * cfoBins(symbolIdx) * sampleIndex / numSamples;
    txSymbols(symbolIdx, :) = ...
        modulateLoRaSymbol(symbolBins(symbolIdx), sf) .* exp(1i * dopplerPhase);
    phaseState = phaseState + 2 * pi * cfoBins(symbolIdx);
end

sampleSnr = 10 ^ (sampleSnrDb / 10);
noiseSigma = sqrt(1 / (2 * sampleSnr));
noise = noiseSigma * ...
    (randn(size(txSymbols)) + 1i * randn(size(txSymbols)));
rxSymbols = txSymbols + noise;

end
