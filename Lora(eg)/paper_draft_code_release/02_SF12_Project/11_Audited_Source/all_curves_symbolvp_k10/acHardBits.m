function bits=acHardBits(bins,c)
%ACHARDBITS Offline hard FEC decoding; never the source of SER symbols.
bins=bins(:);assert(numel(bins)==112 && all(bins>=0 & bins<2^c.physicalSf & bins==fix(bins)));
bits=false(c.effectiveDataSf,4,c.hammingBlockCount);table=v4Hamming74Table();
for block=1:c.hammingBlockCount
    rows=(block-1)*7+(1:7);
    code=v4DiagonalDeinterleave(double(v4GrayEncode(uint32(bins(rows)))),c);
    for bit=1:c.effectiveDataSf
        [~,best]=min(sum(table~=code(bit,:),2));
        bits(bit,:,block)=table(best,1:4);
    end
end
end
