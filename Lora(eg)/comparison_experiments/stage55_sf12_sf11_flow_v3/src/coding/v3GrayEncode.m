function gray = v3GrayEncode(binary)
%V3GRAYENCODE Binary integer to Gray-code integer.

binary = uint32(binary);
gray = bitxor(binary,bitshift(binary,-1));
end

