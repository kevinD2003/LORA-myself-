function crcBits = dreCrc16Ccitt(payloadBits)
%DRECRC16CCITT Vectorized CRC-16/CCITT, polynomial 0x1021, init 0.

payloadBits = logical(payloadBits);
replicates = size(payloadBits,2);
state = zeros(1,replicates,'uint16');
polynomial = uint16(hex2dec('1021'));
for row = 1:size(payloadBits,1)
    feedback = xor(bitget(state,16)~=0,payloadBits(row,:));
    state = bitshift(state,1);
    state(feedback) = bitxor(state(feedback),polynomial);
end
crcBits = false(16,replicates);
for bit = 1:16
    crcBits(bit,:) = bitget(state,17-bit)~=0;
end
end

