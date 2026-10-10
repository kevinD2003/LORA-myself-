function tx = referencePhyV6Encode(payload,cr,c)
%REFERENCEPHYV6ENCODE Payload whitening -> header/CRC -> Hamming -> padding/DI.
arguments
    payload (:,:) uint8
    cr (1,1) double
    c (1,1) struct
end
if size(payload,1)~=c.payloadBytes || isempty(payload),error('ReferencePhyV6:Payload','Payload shape mismatch.');end
layout=referencePhyV6Layout(cr,c);replicates=size(payload,2);
white=bitxor(payload,referencePhyV6Whitening(c.payloadBytes));
nibbles=zeros(2*c.payloadBytes,replicates,'uint8');
nibbles(1:2:end,:)=bitand(white,15);nibbles(2:2:end,:)=bitshift(white,-4);
if c.explicitHeader,nibbles=[repmat(referencePhyV6Header(c.payloadBytes,cr,c.hasCrc),1,replicates);nibbles];end
if c.hasCrc
    crc=referencePhyV6Crc(payload);crcNibbles=zeros(4,replicates,'uint8');
    for i=1:4,crcNibbles(i,:)=uint8(bitand(bitshift(crc,-4*(i-1)),15));end
    nibbles=[nibbles;crcNibbles];
end
words=zeros(layout.wordCount,replicates,'uint8');symbols=zeros(layout.symbolCount,replicates);
for block=1:numel(layout.rows)
    sfApp=layout.rows(block);width=layout.widths(block);count=layout.actualCounts(block);
    wi=layout.wordStarts(block)+(0:sfApp-1);si=layout.symbolStarts(block)+(0:width-1);
    encoded=referencePhyV6Hamming(nibbles(wi(1:count),:),layout.rates(block),'encode');
    words(wi(1:count),:)=encoded; % Remaining rows are zero CODEWORDS, not whitened data.
    inter=zeros(width,replicates,'uint32');
    for column=0:width-1
        parity=zeros(1,replicates);
        for row=0:sfApp-1
            source=mod(column-row-1,sfApp)+1;
            bit=bitget(words(wi(source),:),width-column);
            inter(column+1,:)=bitor(inter(column+1,:),bitshift(uint32(bit),c.sf-row-1));
            parity=parity+double(bit);
        end
        if layout.reduced(block)
            inter(column+1,:)=bitor(inter(column+1,:),bitshift(uint32(mod(parity,2)),1));
        end
    end
    symbols(si,:)=mod(double(dreGrayDecode(inter))+1,2^c.sf);
end
syncValues=8*[bitshift(uint16(c.syncWord),-4);bitand(uint16(c.syncWord),15)];
observedSymbols=[zeros(c.preambleSymbolCount,replicates);repmat(double(syncValues),1,replicates);symbols];
tx=struct('payloadBytes',payload,'nibbles',nibbles,'codedWords',words, ...
    'logicalBins',symbols,'observedSymbols',observedSymbols,'layout',layout);
end
