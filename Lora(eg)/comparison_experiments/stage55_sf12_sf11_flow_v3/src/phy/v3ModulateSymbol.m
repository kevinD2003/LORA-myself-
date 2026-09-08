function waveform = v3ModulateSymbol(physicalBin,config)
%V3MODULATESYMBOL Unit-power SF12 CSS symbol at a physical FFT bin.

m = config.samplesPerSymbol;
if ~isscalar(physicalBin) || physicalBin ~= floor(physicalBin) || ...
        physicalBin < 0 || physicalBin >= m
    error('V3:InvalidPhysicalBin','Physical bin must be an integer in [0,4095].');
end
n = (0:m-1).';
upchirp = exp(1i*2*pi*(n.^2/(2*m)-n/2));
waveform = (upchirp.*exp(1i*2*pi*double(physicalBin)*n/m)).';
end

