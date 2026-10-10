function decoded = strictPaperDecodePayload(detectedBins,cr,config)
%STRICTPAPERDECODEPAYLOAD Inverse PHY with no transmitted-data argument.
sf=config.sf;blocks=config.hammingBlockCount;lengthCode=4+cr;
replicates=size(detectedBins,2);
if size(detectedBins,1)~=lengthCode*blocks || ...
        any(detectedBins(:)<0 | detectedBins(:)>=2^sf | ...
        detectedBins(:)~=floor(detectedBins(:)))
    error('StrictPaper:DecodedShape','Invalid physical symbol decisions.');
end
persistent books
if isempty(books)
    books=cell(1,4);books{1}=dreFullPhyCodebook(1);books{4}=dreFullPhyCodebook(4);
end
if ~ismember(cr,[1 4])
    error('StrictPaper:CodeRate','Only CR1 and CR4 are supported.');
end
book=books{cr};
labels=reshape(dreGrayEncode(uint32(detectedBins)),lengthCode,blocks,replicates);
receivedCode=false(sf,lengthCode,blocks,replicates);
for column=1:lengthCode
    for bit=1:sf
        target=mod(bit+column-2,sf)+1;
        receivedCode(target,column,:,:)=reshape( ...
            bitget(labels(column,:,:),bit)~=0,1,1,blocks,replicates);
    end
end
weights=reshape(2.^(0:lengthCode-1),1,lengthCode,1,1);
values=reshape(sum(double(receivedCode).*weights,2),sf,blocks,replicates);
data=book.decodeData(values(:)+1,:);
decodedData=permute(reshape(data,sf,blocks,replicates,4),[1 4 2 3]);
whitened=reshape(decodedData,sf*4*blocks,replicates);
plain=xor(whitened,dreWhiteningSequence(size(whitened,1)));
payloadBits=plain(1:config.payloadBitCount,:);
receivedCrc=plain(config.payloadBitCount+(1:config.crcBitCount),:);
crcPass=all(receivedCrc==dreCrc16Ccitt(payloadBits),1);
decoded=struct('payloadBits',payloadBits,'crcPass',crcPass, ...
    'receivedCodedBits',receivedCode);
end
