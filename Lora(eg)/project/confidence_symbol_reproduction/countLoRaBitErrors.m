function errorCount = countLoRaBitErrors(trueBins, detectedBins, sf)
%COUNTLORABITERRORS Count Gray-mapped bit errors between LoRa symbols.

arguments
    trueBins (:,1) double {mustBeInteger, mustBeNonnegative}
    detectedBins (:,1) double {mustBeInteger, mustBeNonnegative}
    sf (1,1) double {mustBeInteger, mustBePositive}
end

if numel(trueBins) ~= numel(detectedBins)
    error("SenLoRa:SymbolLengthMismatch", ...
        "trueBins and detectedBins must have equal lengths.");
end

grayBits = loraGrayBits(sf);
trueBits = grayBits(trueBins + 1, :);
detectedBits = grayBits(detectedBins + 1, :);
errorCount = sum(xor(trueBits, detectedBits), "all");

end
