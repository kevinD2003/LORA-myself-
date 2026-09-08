function frequencyHz = lora_symbol_instantaneous_frequency( ...
        symbol, sf, bandwidthHz)
%LORA_SYMBOL_INSTANTANEOUS_FREQUENCY Return wrapped LoRa frequency.
%   FREQUENCYHZ = LORA_SYMBOL_INSTANTANEOUS_FREQUENCY(SYMBOL, SF,
%   BANDWIDTHHZ) returns the M-by-1 instantaneous complex-baseband
%   frequency for one LoRa symbol, where M = 2^SF. The frequency is in
%   hertz and is wrapped to [-B/2, B/2).

if ~isnumeric(sf) || ~isscalar(sf) || ~isfinite(sf) || ...
        sf ~= floor(sf) || sf < 1 || sf > 20
    error("lora:InvalidSpreadingFactor", ...
        "SF must be an integer in the range 1 to 20.");
end

m = 2^sf;
if ~isnumeric(symbol) || ~isscalar(symbol) || ...
        ~isfinite(double(symbol)) || double(symbol) ~= floor(double(symbol)) || ...
        double(symbol) < 0 || double(symbol) >= m
    error("lora:InvalidSymbol", ...
        "Symbol must be an integer in the range [0, 2^SF-1].");
end

if ~isnumeric(bandwidthHz) || ~isscalar(bandwidthHz) || ...
        ~isfinite(bandwidthHz) || bandwidthHz <= 0
    error("lora:InvalidBandwidth", ...
        "Bandwidth must be a positive finite scalar in hertz.");
end

sampleIndex = (0:m-1).';
frequencyHz = bandwidthHz*( ...
    mod(sampleIndex + double(symbol), m)/m - 0.5);
end
