function tx = lora_css_modulate(symbols, sf)
%LORA_CSS_MODULATE Generate unit-power discrete LoRa CSS symbols.
%   TX = LORA_CSS_MODULATE(SYMBOLS, SF) returns an M-by-N complex matrix,
%   where M = 2^SF and each column is one modulated symbol.

validateattributes(sf, {'numeric'}, ...
    {'scalar', 'integer', '>=', 1, '<=', 20}, mfilename, 'sf');

m = 2^sf;
symbols = double(symbols(:).');
if any(symbols < 0 | symbols >= m | symbols ~= floor(symbols))
    error('lora:InvalidSymbol', ...
        'Every symbol must be an integer in [0, 2^SF-1].');
end

n = (0:m-1).';
baseUpChirp = exp(1i * 2*pi * (n.^2/(2*m) - n/2));
symbolTones = exp(1i * 2*pi/m * (n * symbols));
tx = baseUpChirp .* symbolTones;
end
