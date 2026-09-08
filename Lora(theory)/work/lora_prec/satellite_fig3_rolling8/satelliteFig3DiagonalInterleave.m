function symbolBins = satelliteFig3DiagonalInterleave(codedBits)
%SATELLITEFIG3DIAGONALINTERLEAVE LoRa cyclic diagonal interleaver.
%   CODEDBITS is SF-by-(4+CR).  Output has one LoRa bin label per column.

[sf, columnCount] = size(codedBits);
if any(codedBits(:) ~= 0 & codedBits(:) ~= 1)
    error('SatelliteFig3:InvalidBits', 'Interleaver input must be binary.');
end
diagonal = zeros(sf,columnCount);
for column = 1:columnCount
    for bit = 1:sf
        diagonal(bit,column) = codedBits(mod(bit+column-2,sf)+1,column);
    end
end
symbolBins = diagonal.'*(2.^(0:sf-1)).';
end
