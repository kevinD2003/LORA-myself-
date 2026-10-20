function gray = v4GrayEncode(binary)
%V4GRAYENCODE Binary integer to Gray-code integer.

binary = uint32(binary);
gray = bitxor(binary,bitshift(binary,-1));
end

