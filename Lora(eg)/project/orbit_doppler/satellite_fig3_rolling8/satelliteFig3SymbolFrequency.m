function frequencyHz = satelliteFig3SymbolFrequency(symbol, sf, bandwidthHz)
%SATELLITEFIG3SYMBOLFREQUENCY Wrapped instantaneous complex-baseband CSS frequency.

m = 2^sf;
if ~isscalar(symbol) || symbol ~= floor(symbol) || symbol < 0 || symbol >= m
    error('SatelliteFig3:InvalidSymbol', 'Symbol must be in [0,2^SF-1].');
end
n = (0:m-1).';
frequencyHz = bandwidthHz*(mod(n + double(symbol), m)/m - 0.5);
end
