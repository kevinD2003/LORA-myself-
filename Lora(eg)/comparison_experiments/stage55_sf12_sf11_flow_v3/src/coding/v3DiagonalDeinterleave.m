function codedBits = v3DiagonalDeinterleave(grayLabels,config)
%V3DIAGONALDEINTERLEAVE Inverse of the ten-row V3 interleaver.

grayLabels = double(grayLabels(:));
rowCount = config.effectiveDataSf;
if any(grayLabels < 0 | grayLabels >= config.dataAlphabetSize | ...
        grayLabels ~= floor(grayLabels))
    error('V3:InvalidGrayLabel','Gray labels must be ten-bit integers.');
end
columnCount = numel(grayLabels);
diagonal = false(rowCount,columnCount);
for bit = 1:rowCount
    diagonal(bit,:) = bitget(uint32(grayLabels),bit).';
end
codedBits = false(rowCount,columnCount);
for column = 1:columnCount
    for bit = 1:rowCount
        codedBits(mod(bit+column-2,rowCount)+1,column) = diagonal(bit,column);
    end
end
end

