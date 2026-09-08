function [decodedBits, decodedNibbles, scores] = softHammingDecodeBlock(llrCodewords, cr)
%SOFTHAMMINGDECODEBLOCK Decode all SF soft Hamming codewords.

arguments
    llrCodewords (:,:) double
    cr (1,1) double {mustBeInteger, mustBeMember(cr, [1 2 3 4])}
end

sf = size(llrCodewords, 1);
codeLength = 4 + cr;

if size(llrCodewords, 2) ~= codeLength
    error("SenLoRa:InvalidCodewordLength", ...
        "llrCodewords must have 4 + CR columns.");
end

decodedBits = false(sf, codeLength);
decodedNibbles = zeros(sf, 1);
scores = zeros(sf, 1);

for idx = 1:sf
    [decodedBits(idx, :), decodedNibbles(idx), scores(idx)] = ...
        softHammingDecodeOne(llrCodewords(idx, :), cr);
end

end

