function llrSymbols = interleaveBlockBack(llrCodewords)
%INTERLEAVEBLOCKBACK Inverse of deinterleaveBlock for the demo model.

arguments
    llrCodewords (:,:) double
end

llrSymbols = llrCodewords.';

end

