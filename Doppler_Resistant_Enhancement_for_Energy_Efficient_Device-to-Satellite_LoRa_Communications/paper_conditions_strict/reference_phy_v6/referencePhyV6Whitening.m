function bytes = referencePhyV6Whitening(count)
%REFERENCEPHYV6WHITENING Byte sequence from gr-lora_sdr tables.h (255-period).
arguments
    count (1,1) double {mustBeInteger,mustBeNonnegative,mustBeLessThanOrEqual(count,255)}
end
state=uint16(255);bytes=zeros(count,1,'uint8');
for i=1:count
    bytes(i)=uint8(state);
    feedback=mod(sum(bitget(state,[8 6 5 4])),2);
    state=bitor(bitand(bitshift(state,1),uint16(255)),uint16(feedback));
end
end
