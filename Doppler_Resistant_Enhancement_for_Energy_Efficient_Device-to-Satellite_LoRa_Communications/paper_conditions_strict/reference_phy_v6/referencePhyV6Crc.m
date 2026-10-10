function crc = referencePhyV6Crc(bytes)
%REFERENCEPHYV6CRC Reference LoRa CRC: CRC(N-2) XOR final two payload bytes.
arguments
    bytes (:,:) uint8
end
if size(bytes,1)<2 || isempty(bytes)
    error('ReferencePhyV6:CrcLength','CRC requires at least two payload bytes.');
end
crc=zeros(1,size(bytes,2),'uint16');
for row=1:size(bytes,1)-2
    next=bytes(row,:);
    for bit=1:8
        feedback=xor(bitget(crc,16)~=0,bitget(next,8)~=0);
        crc=bitshift(crc,1);
        crc(feedback)=bitxor(crc(feedback),uint16(hex2dec('1021')));
        next=bitshift(next,1);
    end
end
crc=bitxor(crc,bitor(bitshift(uint16(bytes(end-1,:)),8),uint16(bytes(end,:))));
end
