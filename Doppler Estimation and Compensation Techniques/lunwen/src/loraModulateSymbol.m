function waveform = loraModulateSymbol(symbol, spreadingFactor)
%LORAMODULATESYMBOL Generate a discrete LoRa symbol waveform.

arguments
    symbol (1,1) double {mustBeInteger, mustBeNonnegative}
    spreadingFactor (1,1) double {mustBeInteger, mustBeInRange(spreadingFactor, 5, 12)}
end

numSamples = 2^spreadingFactor;
validateattributes(symbol, {'numeric'}, ...
    {'scalar', 'integer', '>=', 0, '<', numSamples});
sampleIndex = (0:numSamples-1).';
tone = exp(1j*2*pi*double(symbol)*sampleIndex/numSamples);
waveform = loraPureUpchirp(spreadingFactor).*tone;
end
