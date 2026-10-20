function table = v4Hamming74Table()
%V4HAMMING74TABLE SF11-compatible systematic Hamming(7,4) code table.

table = false(16,7);
for value = 0:15
    data = bitget(uint32(value),4:-1:1) ~= 0;
    parity = mod([double(data(1))+double(data(2))+double(data(4)), ...
        double(data(1))+double(data(3))+double(data(4)), ...
        double(data(2))+double(data(3))+double(data(4))],2) ~= 0;
    table(value+1,:) = [data,parity];
end
end

