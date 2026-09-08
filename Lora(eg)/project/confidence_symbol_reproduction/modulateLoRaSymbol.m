function waveform = modulateLoRaSymbol(symbolBin, sf)
%MODULATELORASYMBOL Generate one LoRa symbol at one sample per FFT bin.

arguments
    symbolBin (1,1) double {mustBeInteger, mustBeNonnegative}
    sf (1,1) double {mustBeInteger, mustBePositive}
end

numSamples = 2 ^ sf;
if symbolBin >= numSamples
    error("SenLoRa:InvalidSymbolBin", ...
        "symbolBin must be in [0, 2^SF - 1].");
end

sampleIndex = 0:(numSamples - 1);
frequencyShift = exp(1i * 2 * pi * symbolBin * sampleIndex / numSamples);
waveform = loraBaseUpchirp(sf) .* frequencyShift;

end
