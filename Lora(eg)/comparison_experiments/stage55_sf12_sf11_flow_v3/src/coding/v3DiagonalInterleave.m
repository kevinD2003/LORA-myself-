function grayLabels = v3DiagonalInterleave(codedBits,config)
%V3DIAGONALINTERLEAVE SF11 ordering on ten LDRO data rows.

[rowCount,columnCount] = size(codedBits);
if rowCount ~= config.effectiveDataSf || columnCount ~= config.hammingCodewordLength
    error('V3:InterleaveShape','Expected a 10-by-7 CR3 code block.');
end
if any(codedBits(:) ~= 0 & codedBits(:) ~= 1)
    error('V3:InvalidBits','Interleaver input must be binary.');
end
diagonal = zeros(rowCount,columnCount);
for column = 1:columnCount
    for bit = 1:rowCount
        diagonal(bit,column) = codedBits(mod(bit+column-2,rowCount)+1,column);
    end
end
grayLabels = diagonal.'*(2.^(0:rowCount-1)).';
end

