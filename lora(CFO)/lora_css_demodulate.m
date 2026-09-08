function detectedSymbols = lora_css_demodulate(rx, sf)
%LORA_CSS_DEMODULATE Dechirp and noncoherently detect LoRa CSS symbols.
%   DETECTEDSYMBOLS = LORA_CSS_DEMODULATE(RX, SF) expects an M-by-N
%   matrix, where M = 2^SF and each column contains one received symbol.

validateattributes(sf, {'numeric'}, ...
    {'scalar', 'integer', '>=', 1, '<=', 20}, mfilename, 'sf');

m = 2^sf;
if isvector(rx)
    rx = rx(:);
end
if size(rx, 1) ~= m
    error('lora:InvalidWaveformLength', ...
        'RX must have 2^SF samples per column.');
end

n = (0:m-1).';
baseUpChirp = exp(1i * 2*pi * (n.^2/(2*m) - n/2));
dechirped = rx .* conj(baseUpChirp);
spectrum = fft(dechirped, m, 1);
[~, peakIndex] = max(abs(spectrum).^2, [], 1);
detectedSymbols = uint32(peakIndex - 1);
end
