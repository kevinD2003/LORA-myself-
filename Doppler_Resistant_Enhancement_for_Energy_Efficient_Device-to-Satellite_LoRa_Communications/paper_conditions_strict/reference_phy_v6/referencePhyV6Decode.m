function rx = referencePhyV6Decode(symbols,cr,c)
%REFERENCEPHYV6DECODE Reference hard inverse PHY; no transmitted-data argument.
layout=referencePhyV6Layout(cr,c);replicates=size(symbols,2);
if size(symbols,1)~=layout.symbolCount || isempty(symbols) || ...
        any(~isfinite(symbols(:)) | symbols(:)<0 | symbols(:)>=2^c.sf | symbols(:)~=fix(symbols(:)))
    error('ReferencePhyV6:Decisions','Invalid physical symbol decisions.');
end
words=zeros(layout.wordCount,replicates,'uint8');data=zeros(size(words),'uint8');
for block=1:numel(layout.rows)
    width=layout.widths(block);sfApp=layout.rows(block);
    wi=layout.wordStarts(block)+(0:sfApp-1);si=layout.symbolStarts(block)+(0:width-1);
    shifted=mod(symbols(si,:)-1,2^c.sf);
    if layout.reduced(block),shifted=floor(shifted/4);end
    labels=dreGrayEncode(uint32(shifted));
    for column=0:width-1
        for row=0:sfApp-1
            target=mod(column-row-1,sfApp)+1;
            value=bitget(labels(column+1,:),sfApp-row);
            words(wi(target),:)=bitor(words(wi(target),:),bitshift(uint8(value),width-column-1));
        end
    end
    data(wi,:)=referencePhyV6Hamming(words(wi,:),layout.rates(block),'decode');
end
headerValid=true(1,replicates);lengths=repmat(c.payloadBytes,1,replicates);
offset=5*double(c.explicitHeader);
if c.explicitHeader
    for packet=1:replicates
        h=data(1:5,packet);lengths(packet)=double(h(1))*16+double(h(2));
        receivedCr=floor(double(h(3))/2);receivedCrc=logical(bitand(h(3),1));
        if lengths(packet)<2 || receivedCr~=cr || receivedCrc~=c.hasCrc
            headerValid(packet)=false;continue
        end
        expected=referencePhyV6Header(lengths(packet),receivedCr,receivedCrc);
        headerValid(packet)=isequal(h,expected);
    end
end
payload=zeros(c.payloadBytes,replicates,'uint8');crcPass=false(1,replicates);
for packet=1:replicates
    count=lengths(packet);
    if ~headerValid(packet) || offset+2*count+4*double(c.hasCrc)>layout.totalNibbles
        continue
    end
    ni=offset+(1:2*count);
    bytes=bitor(data(ni(1:2:end),packet),bitshift(data(ni(2:2:end),packet),4));
    bytes=bitxor(bytes,referencePhyV6Whitening(count));
    payload(1:min(count,c.payloadBytes),packet)=bytes(1:min(count,c.payloadBytes));
    if c.hasCrc
        ci=offset+2*count+(1:4);received=uint16(0);
        for i=1:4,received=bitor(received,bitshift(uint16(data(ci(i),packet)),4*(i-1)));end
        crcPass(packet)=received==referencePhyV6Crc(bytes);
    else
        crcPass(packet)=true;
    end
end
rx=struct('payloadBytes',payload,'receivedCodedWords',words,'headerValid',headerValid, ...
    'decodedPayloadLengths',lengths,'crcPass',crcPass,'usesPayloadTruth',false);
end
