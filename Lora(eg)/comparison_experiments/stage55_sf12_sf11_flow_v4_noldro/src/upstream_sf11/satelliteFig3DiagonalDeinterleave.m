function codedBits = satelliteFig3DiagonalDeinterleave(symbolBins, sf)
%SATELLITEFIG3DIAGONALDEINTERLEAVE Inverse LoRa cyclic diagonal interleaver.

symbolBins = double(symbolBins(:));
if any(symbolBins < 0 | symbolBins >= 2^sf | symbolBins ~= floor(symbolBins))
    error('SatelliteFig3:InvalidSymbol', 'Symbol labels must be valid integers.');
end
columnCount = numel(symbolBins);
diagonal = zeros(sf,columnCount);
for bit = 1:sf
    diagonal(bit,:) = bitget(uint32(symbolBins),bit).';
end
codedBits = zeros(sf,columnCount);
for column = 1:columnCount
    for bit = 1:sf
        codedBits(mod(bit+column-2,sf)+1,column) = diagonal(bit,column);
    end
end
end
