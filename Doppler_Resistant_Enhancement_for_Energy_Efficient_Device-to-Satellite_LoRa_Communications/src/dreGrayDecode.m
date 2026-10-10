function binary = dreGrayDecode(gray)
%DREGRAYDECODE Gray-code integer to binary integer.

gray = uint32(gray);
binary = gray;
shifted = bitshift(gray,-1);
while any(shifted(:)~=0)
    binary = bitxor(binary,shifted);
    shifted = bitshift(shifted,-1);
end
end

