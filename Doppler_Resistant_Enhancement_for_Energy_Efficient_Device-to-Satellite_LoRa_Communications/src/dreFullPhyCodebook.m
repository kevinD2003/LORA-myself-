function codebook = dreFullPhyCodebook(cr)
%DREFULLPHYCODEBOOK CR1 Hamming(5,4) or CR4 extended Hamming(8,4).

if ~ismember(cr,[1 4])
    error('DRE:FullPhyCr','Only CR=1 and CR=4 are required by the paper.');
end
lengthCode = 4+cr;
data = false(16,4);
code = false(16,lengthCode);
for value = 0:15
    bits = bitget(uint8(value),1:4)~=0;
    parity = logical(mod([bits(1)+bits(2)+bits(4), ...
        bits(1)+bits(3)+bits(4),bits(2)+bits(3)+bits(4)],2));
    if cr==1
        row = [bits mod(sum(bits),2)~=0];
    else
        firstSeven = [bits parity];
        row = [firstSeven mod(sum(firstSeven),2)~=0];
    end
    data(value+1,:) = bits;
    code(value+1,:) = row;
end
decodeData = false(2^lengthCode,4);
decodeCode = false(2^lengthCode,lengthCode);
minimumDistance = zeros(2^lengthCode,1);
for receivedValue = 0:2^lengthCode-1
    received = bitget(uint16(receivedValue),1:lengthCode)~=0;
    distances = sum(code~=received,2);
    [minimumDistance(receivedValue+1),best] = min(distances);
    decodeData(receivedValue+1,:) = data(best,:);
    decodeCode(receivedValue+1,:) = code(best,:);
end
codebook = struct('cr',cr,'length',lengthCode,'data',data,'code',code, ...
    'decodeData',decodeData,'decodeCode',decodeCode, ...
    'minimumDistance',minimumDistance);
end
