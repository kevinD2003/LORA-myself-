function decoded = v4DecodePayload(rxPayload,config,noisePower)
%V4DECODEPAYLOAD Hard and matched-ML soft CR3 decoding for SF12 no-LDRO.

arguments
    rxPayload (:,:) double
    config (1,1) struct
    noisePower (1,1) double = NaN
end

if size(rxPayload,1) ~= config.payloadSymbolCount || ...
        size(rxPayload,2) ~= config.samplesPerSymbol
    error('V4:PayloadShape','Expected 112 complete SF12 payload symbols.');
end
symbolLogProbability = zeros(config.payloadSymbolCount,config.dataAlphabetSize);
hardLogicalBins = zeros(config.payloadSymbolCount,1);
hardPhysicalBins = zeros(config.payloadSymbolCount,1);
softMapLogicalBins = zeros(config.payloadSymbolCount,1);
for row = 1:config.payloadSymbolCount
    likelihood = v4SymbolLikelihood(rxPayload(row,:),config,noisePower);
    symbolLogProbability(row,:) = likelihood.logProbability;
    hardLogicalBins(row) = likelihood.logicalBin;
    hardPhysicalBins(row) = likelihood.physicalBin;
    [~,mapIndex] = max(likelihood.logProbability);
    softMapLogicalBins(row) = mapIndex-1;
end

hardDataBits = false(config.effectiveDataSf,4,config.hammingBlockCount);
softDataBits = false(config.effectiveDataSf,4,config.hammingBlockCount);
softReencodedPhysicalBins = zeros(config.payloadSymbolCount,1);
confidenceDataBits = false(config.effectiveDataSf,4,config.hammingBlockCount);
confidenceReencodedPhysicalBins = zeros(config.payloadSymbolCount,1);
codewordMargin = zeros(config.effectiveDataSf,config.hammingBlockCount);
symbolCodewordMargin = zeros(config.payloadSymbolCount,1);
bitLlr = zeros(config.payloadSymbolCount,config.effectiveDataSf);
rawCodeLlr = zeros(config.effectiveDataSf,config.hammingCodewordLength,config.hammingBlockCount);
grayBitTable = localGrayBitTable(config);
hamming = v4Hamming74Table();
signedHamming = 2*double(hamming)-1;
for block = 1:config.hammingBlockCount
    rows = (block-1)*config.hammingCodewordLength+(1:config.hammingCodewordLength);
    hardGray = double(v4GrayEncode(uint32(hardLogicalBins(rows))));
    hardCode = v4DiagonalDeinterleave(hardGray,config);
    for symbol = 1:config.hammingCodewordLength
        logp = symbolLogProbability(rows(symbol),:);
        for bit = 1:config.effectiveDataSf
            one = grayBitTable(:,bit).';
            bitLlr(rows(symbol),bit) = localLogSumExp(logp(one))- ...
                localLogSumExp(logp(~one));
        end
    end
    codeLlr = localDeinterleaveLlr(bitLlr(rows,:),config);
    rawCodeLlr(:,:,block) = codeLlr;
    for dataRow = 1:config.effectiveDataSf
        distances = sum(hamming ~= hardCode(dataRow,:),2);
        [~,hardBest] = min(distances);
        hardDataBits(dataRow,:,block) = hamming(hardBest,1:4);
        scores = signedHamming*codeLlr(dataRow,:).';
        [orderedScores,order] = sort(scores,'descend');
        softBest = order(1);
        softDataBits(dataRow,:,block) = hamming(softBest,1:4);
        codewordMargin(dataRow,block) = orderedScores(1)-orderedScores(2);
        confidenceMetric = sign(codeLlr(dataRow,:)).*abs(codeLlr(dataRow,:)).^2;
        confidenceScores = signedHamming*confidenceMetric.';
        [orderedConfidence,confidenceOrder] = sort(confidenceScores,'descend');
        confidenceDataBits(dataRow,:,block) = hamming(confidenceOrder(1),1:4);
        codewordMargin(dataRow,block) = orderedConfidence(1)-orderedConfidence(2);
    end
    for column = 1:config.hammingCodewordLength
        participatingRows = zeros(config.effectiveDataSf,1);
        for bit = 1:config.effectiveDataSf
            participatingRows(bit) = mod(bit+column-2,config.effectiveDataSf)+1;
        end
        symbolCodewordMargin(rows(column)) = ...
            min(codewordMargin(participatingRows,block));
    end
    softData = double(softDataBits(:,:,block));
    softParity = mod([softData(:,1)+softData(:,2)+softData(:,4), ...
        softData(:,1)+softData(:,3)+softData(:,4), ...
        softData(:,2)+softData(:,3)+softData(:,4)],2);
    softGray = v4DiagonalInterleave([softData softParity],config);
    softLogical = double(v4GrayDecode(uint32(softGray)));
    softReencodedPhysicalBins(rows) = softLogical;
    confidenceData = double(confidenceDataBits(:,:,block));
    confidenceParity = mod([confidenceData(:,1)+confidenceData(:,2)+confidenceData(:,4), ...
        confidenceData(:,1)+confidenceData(:,3)+confidenceData(:,4), ...
        confidenceData(:,2)+confidenceData(:,3)+confidenceData(:,4)],2);
    confidenceGray = v4DiagonalInterleave([confidenceData confidenceParity],config);
    confidenceReencodedPhysicalBins(rows) = double(v4GrayDecode(uint32(confidenceGray)));
end

decoded = struct('hardLogicalBins',hardLogicalBins, ...
    'hardPhysicalBins',hardPhysicalBins, ...
    'softMapLogicalBins',softMapLogicalBins, ...
    'symbolLogProbability',symbolLogProbability,'bitLlr',bitLlr, ...
    'rawCodeLlr',rawCodeLlr, ...
    'codewordMargin',codewordMargin, ...
    'symbolCodewordMargin',symbolCodewordMargin, ...
    'softReencodedPhysicalBins',softReencodedPhysicalBins, ...
    'confidenceReencodedPhysicalBins',confidenceReencodedPhysicalBins, ...
    'confidenceDataBits',confidenceDataBits, ...
    'hardDataBits',hardDataBits,'softDataBits',softDataBits);
end

function grayBits = localGrayBitTable(config)
persistent cachedAlphabet cachedBits cachedTable
if isempty(cachedAlphabet) || cachedAlphabet ~= config.dataAlphabetSize || ...
        cachedBits ~= config.effectiveDataSf
    cachedTable = false(config.dataAlphabetSize,config.effectiveDataSf);
    for raw = 0:config.dataAlphabetSize-1
        gray = v4GrayEncode(uint32(raw));
        for bit = 1:config.effectiveDataSf
            cachedTable(raw+1,bit) = bitget(gray,bit) ~= 0;
        end
    end
    cachedAlphabet = config.dataAlphabetSize;
    cachedBits = config.effectiveDataSf;
end
grayBits = cachedTable;
end

function codeLlr = localDeinterleaveLlr(symbolLlr,config)
rowCount = config.effectiveDataSf;
columnCount = size(symbolLlr,1);
codeLlr = zeros(rowCount,columnCount);
for column = 1:columnCount
    for bit = 1:rowCount
        codeLlr(mod(bit+column-2,rowCount)+1,column) = symbolLlr(column,bit);
    end
end
end

function value = localLogSumExp(x)
maximum = max(x);
value = maximum+log(sum(exp(x-maximum)));
end
