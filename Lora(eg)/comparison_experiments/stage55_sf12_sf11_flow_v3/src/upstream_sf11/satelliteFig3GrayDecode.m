function binary = satelliteFig3GrayDecode(gray)
%SATELLITEFIG3GRAYDECODE Gray-code integer to binary integer.

gray = uint32(gray);
binary = gray;
shifted = gray;
while any(shifted ~= 0,'all')
    shifted = bitshift(shifted,-1);
    binary = bitxor(binary,shifted);
end
end
