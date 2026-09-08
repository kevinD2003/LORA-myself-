function waveform = senloraModulateLoRaSymbol(symbol, sf)
%SENLORAMODULATELORASYMBOL Generate one unit-power LoRa CSS symbol.

arguments
    symbol (1,1) double {mustBeInteger, mustBeNonnegative}
    sf (1,1) double {mustBeInteger, mustBePositive}
end

numSamples = 2^sf;
if symbol >= numSamples
    error("SenLoRa:InvalidSymbol", ...
        "Symbol must be in [0, 2^SF-1].");
end
sampleIndex = (0:numSamples-1).';
baseUpchirp = exp(1i*2*pi*(sampleIndex.^2/(2*numSamples)-sampleIndex/2));
waveform = (baseUpchirp .* ...
    exp(1i*2*pi*double(symbol)*sampleIndex/numSamples)).';
end
