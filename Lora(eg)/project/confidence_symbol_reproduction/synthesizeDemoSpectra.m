function [payloadFft, preambleFft] = synthesizeDemoSpectra(targetBins, sf, symbolSnrDb)
%SYNTHESIZEDEMOSPECTRA Create noisy FFT spectra for the demo and tests.

arguments
    targetBins (:,1) double {mustBeInteger, mustBeNonnegative}
    sf (1,1) double {mustBeInteger, mustBePositive}
    symbolSnrDb (:,1) double
end

numBins = 2 ^ sf;
numSymbols = numel(targetBins);

if numel(symbolSnrDb) ~= numSymbols
    error("SenLoRa:InvalidSnrLength", ...
        "symbolSnrDb must have one value per target bin.");
end

if any(targetBins >= numBins)
    error("SenLoRa:InvalidTargetBin", ...
        "targetBins must be in [0, 2^SF - 1].");
end

noiseSigma = 1;
preambleFft = complex(noiseSigma * randn(8, numBins), ...
    noiseSigma * randn(8, numBins));
preambleFft(:, 1) = preambleFft(:, 1) + 20;

payloadFft = complex(noiseSigma * randn(numSymbols, numBins), ...
    noiseSigma * randn(numSymbols, numBins));

for symbolIdx = 1:numSymbols
    amp = 10 ^ (symbolSnrDb(symbolIdx) / 20);
    payloadFft(symbolIdx, targetBins(symbolIdx) + 1) = ...
        payloadFft(symbolIdx, targetBins(symbolIdx) + 1) + amp;
end

end

