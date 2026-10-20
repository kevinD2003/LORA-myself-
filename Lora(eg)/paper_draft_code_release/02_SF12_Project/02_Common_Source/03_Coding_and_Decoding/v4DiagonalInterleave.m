function grayLabels = v4DiagonalInterleave(codedBits,config)
%V4DIAGONALINTERLEAVE SF11 ordering generalized to twelve no-LDRO rows.

[rowCount,columnCount] = size(codedBits);
if rowCount ~= config.effectiveDataSf || columnCount ~= config.hammingCodewordLength
    error('V4:InterleaveShape','Expected a 12-by-7 CR3 code block.');
end
if any(codedBits(:) ~= 0 & codedBits(:) ~= 1)
    error('V4:InvalidBits','Interleaver input must be binary.');
end
diagonal = zeros(rowCount,columnCount);
for column = 1:columnCount
    for bit = 1:rowCount
        diagonal(bit,column) = codedBits(mod(bit+column-2,rowCount)+1,column);
    end
end
grayLabels = diagonal.'*(2.^(0:rowCount-1)).';
end
