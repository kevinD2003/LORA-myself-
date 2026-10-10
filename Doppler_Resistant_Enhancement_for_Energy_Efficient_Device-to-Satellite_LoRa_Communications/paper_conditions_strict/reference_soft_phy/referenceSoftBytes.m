function rx = referenceSoftBytes(data,words,cr,c)
%REFERENCESOFTBYTES Same header, dewhitening and CRC rules as frozen v6.
% Receives decoded nibbles only; no transmitted payload or Gold information.
layout=referencePhyV6Layout(cr,c);replicates=size(data,2);
if ~isa(data,'uint8') || ~isa(words,'uint8') || ...
        size(data,1)~=layout.wordCount || size(words,1)~=layout.wordCount || ...
        size(words,2)~=replicates || replicates==0 || any(data(:)>15)
    error('ReferenceSoft:Nibbles','Invalid decoded word shape.');
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
    if ~headerValid(packet) || offset+2*count+4*double(c.hasCrc)>layout.totalNibbles,continue;end
    ni=offset+(1:2*count);
    bytes=bitor(data(ni(1:2:end),packet),bitshift(data(ni(2:2:end),packet),4));
    bytes=bitxor(bytes,referencePhyV6Whitening(count));
    payload(1:min(count,c.payloadBytes),packet)=bytes(1:min(count,c.payloadBytes));
    if c.hasCrc
        ci=offset+2*count+(1:4);received=uint16(0);
        for bit=1:4,received=bitor(received,bitshift(uint16(data(ci(bit),packet)),4*(bit-1)));end
        crcPass(packet)=received==referencePhyV6Crc(bytes);
    else
        crcPass(packet)=true;
    end
end
rx=struct('payloadBytes',payload,'receivedCodedWords',words,'headerValid',headerValid, ...
    'decodedPayloadLengths',lengths,'crcPass',crcPass,'usesPayloadTruth',false);
end
