function dataBits = dreDecodeProjectHardBits(detectedPhysicalBins,config)
%DREDECODEPROJECTHARDBITS Project CR3 hard Hamming decoding from LR decisions.

detectedPhysicalBins = double(detectedPhysicalBins(:));
if numel(detectedPhysicalBins) ~= config.payloadSymbolCount
    error('DRE:ProjectPayloadShape','Expected the complete V4 payload.');
end
dataBits = false(config.effectiveDataSf,4,config.hammingBlockCount);
table = v4Hamming74Table();
for block = 1:config.hammingBlockCount
    rows = (block-1)*config.hammingCodewordLength+(1:config.hammingCodewordLength);
    gray = double(v4GrayEncode(uint32(detectedPhysicalBins(rows))));
    code = v4DiagonalDeinterleave(gray,config);
    for bitRow = 1:config.effectiveDataSf
        distances = sum(table ~= code(bitRow,:),2);
        [~,best] = min(distances);
        dataBits(bitRow,:,block) = table(best,1:4);
    end
end
end

