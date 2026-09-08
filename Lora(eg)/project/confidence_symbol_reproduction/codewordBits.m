function bits = codewordBits(codeValue, cr)
%CODEWORDBITS Extract the first 4 + CR bits from the 8-bit code table.

arguments
    codeValue (1,1) double {mustBeInteger, mustBeNonnegative}
    cr (1,1) double {mustBeInteger, mustBeMember(cr, [1 2 3 4])}
end

codeLength = 4 + cr;
bitString = dec2bin(codeValue, 8);
bits = bitString(1:codeLength) == '1';

end

