function waveform = satelliteFig3ModulateSymbol(symbol, sf)
%SATELLITEFIG3MODULATESYMBOL Unit-power discrete-time LoRa CSS up-chirp.

m = 2^sf;
if ~isscalar(symbol) || symbol ~= floor(symbol) || symbol < 0 || symbol >= m
    error('SatelliteFig3:InvalidSymbol', 'Symbol must be in [0,2^SF-1].');
end
n = (0:m-1).';
upChirp = exp(1i*2*pi*(n.^2/(2*m) - n/2));
waveform = (upChirp .* exp(1i*2*pi*double(symbol)*n/m)).';
end
