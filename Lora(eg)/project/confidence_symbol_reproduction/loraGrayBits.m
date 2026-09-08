function grayBits = loraGrayBits(sf)
%LORAGRAYBITS Return LoRa Gray-code bits for FFT bin grouping.
%
% The mapping follows Fig. 6 in the SenLoRa paper. For SF=3, bins 0..7 map
% to 100, 000, 001, 011, 010, 110, 111, 101.

arguments
    sf (1,1) double {mustBeInteger, mustBePositive}
end

numBins = 2 ^ sf;
grayBits = false(numBins, sf);

for bin = 0:(numBins - 1)
    shifted = mod(bin - 1, numBins);
    grayValue = bitxor(shifted, floor(shifted / 2));
    bitString = dec2bin(grayValue, sf);
    grayBits(bin + 1, :) = bitString == '1';
end

end

