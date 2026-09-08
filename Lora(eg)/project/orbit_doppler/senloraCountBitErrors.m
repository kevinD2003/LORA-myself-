function count = senloraCountBitErrors(trueBins, detectedBins, sf)
%SENLORACOUNTBITERRORS Count Gray-mapped LoRa bit errors.
if numel(trueBins) ~= numel(detectedBins)
    error("SenLoRa:BitCountLengthMismatch", ...
        "Symbol vectors must have equal length.");
end
grayBits = false(2^sf,sf);
for bin = 0:(2^sf-1)
    shifted = mod(bin-1,2^sf);
    grayValue = bitxor(shifted,floor(shifted/2));
    grayBits(bin+1,:) = dec2bin(grayValue,sf) == '1';
end
count = sum(xor(grayBits(trueBins+1,:),grayBits(detectedBins+1,:)),"all");
end

