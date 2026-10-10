function decoded = dreDecodeFullPhyPayload(detectedBins,transmitted,cr,config)
%DREDECODEFULLPHYPAYLOAD Inverse PHY and CRC/coded-BER accounting.

sf = config.sf;
blocks = config.hammingBlockCount;
lengthCode = 4+cr;
replicates = size(detectedBins,2);
if size(detectedBins,1) ~= lengthCode*blocks
    error('DRE:FullPhyDetectedShape','Detected symbol count is invalid.');
end
codebook = dreFullPhyCodebook(cr);
receivedCode = false(sf,lengthCode,blocks,replicates);
decodedData = false(sf,4,blocks,replicates);
for block = 1:blocks
    rows = (block-1)*lengthCode+(1:lengthCode);
    grayLabels = double(dreGrayEncode(uint32(detectedBins(rows,:))));
    diagonal = false(sf,lengthCode,replicates);
    for bit = 1:sf
        diagonal(bit,:,:) = bitget(uint32(grayLabels),bit)~=0;
    end
    code = false(sf,lengthCode,replicates);
    for column = 1:lengthCode
        for bit = 1:sf
            target = mod(bit+column-2,sf)+1;
            code(target,column,:) = diagonal(bit,column,:);
        end
    end
    receivedCode(:,:,block,:) = reshape(code,sf,lengthCode,1,replicates);
    weights = reshape(uint16(2.^(0:lengthCode-1)),1,lengthCode,1);
    values = reshape(sum(uint16(code).*weights,2),sf,replicates);
    for bit = 1:sf
        decodedData(bit,:,block,:) = reshape( ...
            codebook.decodeData(double(values(bit,:))+1,:).',1,4,1,replicates);
    end
end
flatWhitened = reshape(decodedData,sf*4*blocks,replicates);
plain = xor(flatWhitened,dreWhiteningSequence(size(flatWhitened,1)));
payloadBits = plain(1:config.payloadBitCount,:);
receivedCrc = plain(config.payloadBitCount+(1:config.crcBitCount),:);
expectedCrc = dreCrc16Ccitt(payloadBits);
crcPass = all(receivedCrc==expectedCrc,1);
codedErrors = squeeze(sum(sum(sum(xor(receivedCode, ...
    transmitted.codedBits),1),2),3));
codedErrors = reshape(codedErrors,1,replicates);
decoded = struct('crcPass',crcPass,'payloadBits',payloadBits, ...
    'receivedCodedBits',receivedCode,'codedErrorCount',codedErrors, ...
    'totalCodedErrors',sum(codedErrors), ...
    'totalCodedBitCount',replicates*sf*lengthCode*blocks, ...
    'acceptedCodedErrors',sum(codedErrors(crcPass)), ...
    'acceptedCodedBitCount',sum(crcPass)*sf*lengthCode*blocks, ...
    'packetLossCount',sum(~crcPass));
end
