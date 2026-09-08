function codeTable = hammingCodeTable(cr)
%HAMMINGCODETABLE Table 3 from the SenLoRa paper.

arguments
    cr (1,1) double {mustBeInteger, mustBeMember(cr, [1 2 3 4])}
end

if cr == 1
    codeTable = [ ...
        0, 24, 40, 48, 72, 80, 96, 120, ...
        136, 144, 160, 184, 192, 216, 232, 240];
else
    codeTable = [ ...
        0, 23, 45, 58, 78, 89, 99, 116, ...
        139, 156, 166, 177, 197, 210, 232, 255];
end

end

