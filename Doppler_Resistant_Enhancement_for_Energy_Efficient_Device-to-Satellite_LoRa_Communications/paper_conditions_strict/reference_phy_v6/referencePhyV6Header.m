function header = referencePhyV6Header(payloadLength,cr,hasCrc)
%REFERENCEPHYV6HEADER Five unwhitened nibbles, including five checksum bits.
arguments
    payloadLength (1,1) double {mustBeInteger,mustBeGreaterThanOrEqual(payloadLength,2),mustBeLessThanOrEqual(payloadLength,255)}
    cr (1,1) double {mustBeMember(cr,[1 4])}
    hasCrc (1,1) logical
end
h=uint8([floor(payloadLength/16);mod(payloadLength,16);2*cr+hasCrc]);
b=@(row,bit)bitget(h(row),bit)~=0;
checks=[mod(b(1,4)+b(1,3)+b(1,2)+b(1,1),2); ...
    mod(b(1,4)+b(2,4)+b(2,3)+b(2,2)+b(3,1),2); ...
    mod(b(1,3)+b(2,4)+b(2,1)+b(3,4)+b(3,2),2); ...
    mod(b(1,2)+b(2,3)+b(2,1)+b(3,3)+b(3,2)+b(3,1),2); ...
    mod(b(1,1)+b(2,2)+b(3,4)+b(3,3)+b(3,2)+b(3,1),2)];
header=[h;uint8(checks(1));uint8(checks(2:5).'*[8;4;2;1])];
end
