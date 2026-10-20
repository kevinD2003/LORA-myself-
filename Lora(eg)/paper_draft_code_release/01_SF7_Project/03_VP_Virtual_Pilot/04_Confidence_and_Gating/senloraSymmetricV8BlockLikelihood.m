function decoded = senloraSymmetricV8BlockLikelihood(rxBlock,c,noisePower)
%SENLORASYMMETRICV8BLOCKLIKELIHOOD Soft Hamming ML for one 7-symbol block.

arguments
    rxBlock (:,:) double
    c (1,1) struct
    noisePower (1,1) double = NaN
end
if size(rxBlock,1)~=c.hammingCodewordLength || ...
        size(rxBlock,2)~=c.samplesPerSymbol
    error('EXP5V8:BlockShape','Expected one complete Hamming block.');
end

n = c.hammingCodewordLength;
symbolLogProbability = zeros(n,c.dataAlphabetSize);
hardLogicalBins = zeros(n,1);
hardPhysicalBins = zeros(n,1);
decisionPeakRatio = zeros(n,1);
for symbol = 1:n
    likelihood = v4SymbolLikelihood(rxBlock(symbol,:),c,noisePower);
    symbolLogProbability(symbol,:) = likelihood.logProbability;
    hardLogicalBins(symbol) = likelihood.logicalBin;
    hardPhysicalBins(symbol) = likelihood.physicalBin;
    decisionPeakRatio(symbol) = likelihood.peakRatio;
end

grayBitTable = localGrayBitTable(c);
bitLlr = zeros(n,c.effectiveDataSf);
for symbol = 1:n
    logp = symbolLogProbability(symbol,:);
    for bit = 1:c.effectiveDataSf
        one = grayBitTable(:,bit).';
        bitLlr(symbol,bit) = localLogSumExp(logp(one))- ...
            localLogSumExp(logp(~one));
    end
end
codeLlr = localDeinterleaveLlr(bitLlr,c);
hamming = v4Hamming74Table();
signedHamming = 2*double(hamming)-1;
hardGray = double(v4GrayEncode(uint32(hardLogicalBins)));
hardCode = v4DiagonalDeinterleave(hardGray,c);
hardDataBits = false(c.effectiveDataSf,4);
softDataBits = false(c.effectiveDataSf,4);
bestCodewordScore = zeros(c.effectiveDataSf,1);
codewordMargin = zeros(c.effectiveDataSf,1);
for dataRow = 1:c.effectiveDataSf
    distances = sum(hamming~=hardCode(dataRow,:),2);
    [~,hardBest] = min(distances);
    hardDataBits(dataRow,:) = hamming(hardBest,1:4);
    scores = signedHamming*codeLlr(dataRow,:).';
    [ordered,order] = sort(scores,'descend');
    softDataBits(dataRow,:) = hamming(order(1),1:4);
    bestCodewordScore(dataRow) = ordered(1);
    codewordMargin(dataRow) = ordered(1)-ordered(2);
end

softData = double(softDataBits);
softParity = mod([softData(:,1)+softData(:,2)+softData(:,4), ...
    softData(:,1)+softData(:,3)+softData(:,4), ...
    softData(:,2)+softData(:,3)+softData(:,4)],2);
softGray = v4DiagonalInterleave([softData softParity],c);
softReencodedPhysicalBins = double(v4GrayDecode(uint32(softGray)));

decoded = struct( ...
    'hardPhysicalBins',hardPhysicalBins, ...
    'softReencodedPhysicalBins',softReencodedPhysicalBins, ...
    'hardDataBits',hardDataBits,'softDataBits',softDataBits, ...
    'hardSoftAgreement',isequal(hardDataBits,softDataBits), ...
    'decisionPeakRatio',decisionPeakRatio, ...
    'bestCodewordScore',bestCodewordScore, ...
    'codewordMargin',codewordMargin, ...
    'objective',sum(bestCodewordScore));
end

function grayBits = localGrayBitTable(c)
persistent cachedAlphabet cachedBits cachedTable
if isempty(cachedAlphabet) || cachedAlphabet~=c.dataAlphabetSize || ...
        cachedBits~=c.effectiveDataSf
    cachedTable = false(c.dataAlphabetSize,c.effectiveDataSf);
    for raw = 0:c.dataAlphabetSize-1
        gray = v4GrayEncode(uint32(raw));
        for bit = 1:c.effectiveDataSf
            cachedTable(raw+1,bit) = bitget(gray,bit)~=0;
        end
    end
    cachedAlphabet = c.dataAlphabetSize;
    cachedBits = c.effectiveDataSf;
end
grayBits = cachedTable;
end

function codeLlr = localDeinterleaveLlr(symbolLlr,c)
codeLlr = zeros(c.effectiveDataSf,c.hammingCodewordLength);
for column = 1:c.hammingCodewordLength
    for bit = 1:c.effectiveDataSf
        codeLlr(mod(bit+column-2,c.effectiveDataSf)+1,column) = ...
            symbolLlr(column,bit);
    end
end
end

function value = localLogSumExp(x)
maximum = max(x);
value = maximum+log(sum(exp(x-maximum)));
end
