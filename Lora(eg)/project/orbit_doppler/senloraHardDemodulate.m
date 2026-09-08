function [detectedBin, peakRatio, spectrum] = ...
    senloraHardDemodulate(symbolSamples, sf)
%SENLORAHARDDEMODULATE Dechirp and noncoherent FFT decision.

arguments
    symbolSamples (1,:) double
    sf (1,1) double {mustBeInteger, mustBePositive}
end

numSamples = 2^sf;
if numel(symbolSamples) ~= numSamples
    error("SenLoRa:InvalidDemodSymbolLength", ...
        "symbolSamples must contain 2^SF samples.");
end
sampleIndex = (0:numSamples-1).';
baseUpchirp = exp(1i*2*pi*(sampleIndex.^2/(2*numSamples)-sampleIndex/2));
dechirped = symbolSamples(:).*conj(baseUpchirp);
spectrum = fft(dechirped)/sqrt(numSamples);
magnitude = abs(spectrum);
sortedMagnitude = sort(magnitude, "descend");
[~, peakIndex] = max(magnitude);
detectedBin = peakIndex-1;
peakRatio = sortedMagnitude(1)/max(sortedMagnitude(2), eps);
end
