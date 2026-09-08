function frequencyHz = v3SymbolFrequency(physicalBin,config)
%V3SYMBOLFREQUENCY Wrapped instantaneous CSS baseband frequency.

m = config.samplesPerSymbol;
if physicalBin < 0 || physicalBin >= m || physicalBin ~= floor(physicalBin)
    error('V3:InvalidPhysicalBin','Invalid CSS physical bin.');
end
n = (0:m-1).';
frequencyHz = config.bandwidthHz*(mod(n+double(physicalBin),m)/m-0.5);
end

