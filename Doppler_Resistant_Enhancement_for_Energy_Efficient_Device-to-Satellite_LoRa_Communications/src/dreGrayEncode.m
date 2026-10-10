function gray = dreGrayEncode(binary)
%DREGRAYENCODE Binary integer to Gray-code integer.

binary = uint32(binary);
gray = bitxor(binary,bitshift(binary,-1));
end

