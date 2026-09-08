function [payloadBins, dataNibbles] = ...
        senloraGenerateCodedPayloadBins(config, randomStream)
%SENLORAGENERATECODEDPAYLOADBINS Build blocks consistent with SenLoRa LLRs.
%
% SenLoRa confidence operates on SF Hamming codewords spread across
% 4+CR LoRa symbols.  Generating independent arbitrary bins would violate
% that receiver assumption and make the soft-Hamming confidence score
% meaningless.  This function uses the same transpose interleaver as the
% confidence detector; it does not expose source data to the receiver.

blockSize = 4+config.cr;
if mod(config.payloadSymbolCount,blockSize) ~= 0
    error("SenLoRa:InvalidCodedPayloadLength", ...
        "payloadSymbolCount must be a multiple of 4+CR.");
end

blockCount = config.payloadSymbolCount/blockSize;
payloadBins = zeros(config.payloadSymbolCount,1);
dataNibbles = zeros(config.sf,blockCount);
grayBits = localGrayBits(config.sf);
codeTable = localHammingCodeTable(config.cr);

for blockIdx = 1:blockCount
    nibbles = randi(randomStream,[0 15],config.sf,1);
    dataNibbles(:,blockIdx) = nibbles;
    codewordBits = false(config.sf,blockSize);
    for rowIdx = 1:config.sf
        codewordBits(rowIdx,:) = localCodewordBits( ...
            codeTable(nibbles(rowIdx)+1),config.cr);
    end
    symbolBits = codewordBits.';
    blockBins = zeros(blockSize,1);
    for symbolIdx = 1:blockSize
        [isPresent,binIndex] = ismember( ...
            symbolBits(symbolIdx,:),grayBits,"rows");
        if ~isPresent
            error("SenLoRa:CodedPayloadMappingFailed", ...
                "Could not map coded Gray bits to a LoRa bin.");
        end
        blockBins(symbolIdx) = binIndex-1;
    end
    rows = (blockIdx-1)*blockSize+(1:blockSize);
    payloadBins(rows) = blockBins;
end
end

function codeTable = localHammingCodeTable(cr)
if cr == 1
    codeTable = [0,24,40,48,72,80,96,120,136,144,160,184,192,216,232,240];
else
    codeTable = [0,23,45,58,78,89,99,116,139,156,166,177,197,210,232,255];
end
end

function bits = localCodewordBits(codeValue,cr)
bitString = dec2bin(codeValue,8);
bits = bitString(1:(4+cr)) == '1';
end

function grayBits = localGrayBits(sf)
numBins = 2^sf;
grayBits = false(numBins,sf);
for bin = 0:numBins-1
    shifted = mod(bin-1,numBins);
    grayValue = bitxor(shifted,floor(shifted/2));
    grayBits(bin+1,:) = dec2bin(grayValue,sf) == '1';
end
end
