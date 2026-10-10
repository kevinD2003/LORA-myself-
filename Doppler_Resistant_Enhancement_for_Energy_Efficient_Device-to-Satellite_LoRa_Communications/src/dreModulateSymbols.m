function waveforms = dreModulateSymbols(symbols,config)
%DREMODULATESYMBOLS Unit-power LoRa CSS symbols sampled at the bandwidth.

symbols = double(symbols(:));
m = config.samplesPerSymbol;
if any(symbols < 0 | symbols >= m | symbols ~= floor(symbols))
    error('DRE:InvalidSymbol','Symbols must be integers in [0,2^SF-1].');
end
n = 0:m-1;
upchirp = exp(1i*2*pi*(n.^2/(2*m)-n/2));
waveforms = exp(1i*2*pi*(symbols*n)/m).*upchirp;
end

