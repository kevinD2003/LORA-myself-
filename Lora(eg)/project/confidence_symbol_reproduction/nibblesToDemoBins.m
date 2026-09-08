function bins = nibblesToDemoBins(dataNibbles, cfg)
%NIBBLESTODEMOBINS Build demo FFT-bin indices consistent with the LLR path.

arguments
    dataNibbles (:,1) double {mustBeInteger, mustBeNonnegative}
    cfg struct
end

sf = cfg.sf;
cr = cfg.cr;
codeLength = 4 + cr;
if numel(dataNibbles) ~= sf
    error("SenLoRa:InvalidNibbleCount", ...
        "dataNibbles must contain SF entries.");
end

llrCodeBits = false(sf, codeLength);
table = hammingCodeTable(cr);
for idx = 1:sf
    llrCodeBits(idx, :) = codewordBits(table(dataNibbles(idx) + 1), cr);
end

symbolBits = interleaveBlockBack(double(llrCodeBits)) > 0;
grayBits = loraGrayBits(sf);
bins = zeros(codeLength, 1);

for symbolIdx = 1:codeLength
    [isPresent, binIdx] = ismember(symbolBits(symbolIdx, :), grayBits, "rows");
    if ~isPresent
        error("SenLoRa:DemoMappingFailed", ...
            "Could not map symbol bits to an FFT bin.");
    end
    bins(symbolIdx) = binIdx - 1;
end

end

