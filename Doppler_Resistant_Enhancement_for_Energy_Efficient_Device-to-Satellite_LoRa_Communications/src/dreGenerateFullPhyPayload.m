function payload = dreGenerateFullPhyPayload(replicates,cr,config,stream)
%DREGENERATEFULLPHYPAYLOAD Whitening, Hamming, interleaving, and Gray mapping.

arguments
    replicates (1,1) double {mustBeInteger,mustBePositive}
    cr (1,1) double
    config (1,1) struct
    stream (1,1) RandStream
end
sf = config.sf;
blocks = config.hammingBlockCount;
lengthCode = 4+cr;
payloadBits = randi(stream,[0 1],config.payloadBitCount,replicates)~=0;
crcBits = dreCrc16Ccitt(payloadBits);
plain = [payloadBits;crcBits;false(config.paddingBitCount,replicates)];
if size(plain,1) ~= sf*4*blocks
    error('DRE:FullPhyPacking','Payload/CRC/padding does not fill six blocks.');
end
whitening = dreWhiteningSequence(size(plain,1));
whitened = xor(plain,whitening);
data = reshape(whitened,sf,4,blocks,replicates);
coded = false(sf,lengthCode,blocks,replicates);
logicalBins = zeros(lengthCode*blocks,replicates);
for block = 1:blocks
    d = reshape(data(:,:,block,:),sf,4,replicates);
    parity = false(sf,3,replicates);
    parity(:,1,:) = xor(xor(d(:,1,:),d(:,2,:)),d(:,4,:));
    parity(:,2,:) = xor(xor(d(:,1,:),d(:,3,:)),d(:,4,:));
    parity(:,3,:) = xor(xor(d(:,2,:),d(:,3,:)),d(:,4,:));
    if cr==1
        code = cat(2,d,mod(sum(d,2),2)~=0);
    elseif cr==4
        firstSeven = cat(2,d,parity);
        overall = mod(sum(firstSeven,2),2)~=0;
        code = cat(2,firstSeven,overall);
    else
        error('DRE:FullPhyCr','Only CR=1 and CR=4 are supported.');
    end
    coded(:,:,block,:) = reshape(code,sf,lengthCode,1,replicates);
    diagonal = false(sf,lengthCode,replicates);
    for column = 1:lengthCode
        for bit = 1:sf
            source = mod(bit+column-2,sf)+1;
            diagonal(bit,column,:) = code(source,column,:);
        end
    end
    weights = reshape(2.^(0:sf-1),sf,1,1);
    grayLabels = reshape(sum(double(diagonal).*weights,1),lengthCode,replicates);
    rows = (block-1)*lengthCode+(1:lengthCode);
    logicalBins(rows,:) = double(dreGrayDecode(uint32(grayLabels)));
end
payload = struct('payloadBits',payloadBits,'crcBits',crcBits, ...
    'plainBits',plain,'whitenedDataBits',data,'codedBits',coded, ...
    'logicalBins',logicalBins,'cr',cr);
end
