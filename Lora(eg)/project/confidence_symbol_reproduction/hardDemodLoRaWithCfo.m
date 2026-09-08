function [detectedBins, peakRatio, spectra] = ...
    hardDemodLoRaWithCfo(rxSymbols, sf, cfoEstimate)
%HARDDEMODLORAWITHCFO Apply phase rotation, dechirp, FFT, and hard decision.

arguments
    rxSymbols (:,:) double
    sf (1,1) double {mustBeInteger, mustBePositive}
    cfoEstimate (:,1) double
end

numSymbols = size(rxSymbols, 1);
numSamples = 2 ^ sf;
if size(rxSymbols, 2) ~= numSamples
    error("SenLoRa:InvalidSymbolLength", ...
        "rxSymbols must have 2^SF columns.");
end
if isscalar(cfoEstimate)
    cfoEstimate = repmat(cfoEstimate, numSymbols, 1);
elseif numel(cfoEstimate) ~= numSymbols
    error("SenLoRa:CfoLengthMismatch", ...
        "cfoEstimate must be scalar or have one value per symbol.");
end

sampleIndex = 0:(numSamples - 1);
downchirp = conj(loraBaseUpchirp(sf));
detectedBins = zeros(numSymbols, 1);
peakRatio = zeros(numSymbols, 1);
spectra = complex(zeros(numSymbols, numSamples));

for symbolIdx = 1:numSymbols
    correction = exp(-1i * 2 * pi * ...
        cfoEstimate(symbolIdx) * sampleIndex / numSamples);
    dechirped = rxSymbols(symbolIdx, :) .* correction .* downchirp;
    spectra(symbolIdx, :) = fft(dechirped) / sqrt(numSamples);
    magnitudes = abs(spectra(symbolIdx, :));
    [sortedMagnitude, sortedIdx] = sort(magnitudes, "descend");
    detectedBins(symbolIdx) = sortedIdx(1) - 1;
    peakRatio(symbolIdx) = sortedMagnitude(1) / max(sortedMagnitude(2), eps);
end

end
