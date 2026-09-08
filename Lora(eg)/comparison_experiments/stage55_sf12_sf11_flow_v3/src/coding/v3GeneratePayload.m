function payload = v3GeneratePayload(config,seed)
%V3GENERATEPAYLOAD Generate 16 complete SF12-LDRO CR3 blocks.

arguments
    config (1,1) struct
    seed (1,1) double {mustBeInteger,mustBeNonnegative}
end

stream = RandStream('mt19937ar','Seed',seed);
dataBits = randi(stream,[0 1],config.effectiveDataSf,4,config.hammingBlockCount);
codedBits = false(config.effectiveDataSf,config.hammingCodewordLength, ...
    config.hammingBlockCount);
logicalBins = zeros(config.payloadSymbolCount,1);
grayLabels = zeros(config.payloadSymbolCount,1);
for block = 1:config.hammingBlockCount
    data = dataBits(:,:,block);
    parity = mod([data(:,1)+data(:,2)+data(:,4), ...
        data(:,1)+data(:,3)+data(:,4), ...
        data(:,2)+data(:,3)+data(:,4)],2);
    code = [data,parity];
    codedBits(:,:,block) = code;
    rows = (block-1)*config.hammingCodewordLength+(1:config.hammingCodewordLength);
    gray = v3DiagonalInterleave(code,config);
    grayLabels(rows) = gray;
    logicalBins(rows) = double(v3GrayDecode(uint32(gray)));
end
physicalBins = logicalBins*config.dataBinSpacing;
payload = struct('dataBits',dataBits,'codedBits',codedBits, ...
    'grayLabels',grayLabels,'logicalBins',logicalBins, ...
    'physicalBins',physicalBins,'seed',seed);
end

