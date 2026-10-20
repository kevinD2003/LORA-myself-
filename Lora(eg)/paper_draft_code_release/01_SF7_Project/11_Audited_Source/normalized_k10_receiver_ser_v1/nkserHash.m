function value=nkserHash(input,asFile)
%NKSERHASH SHA-256 for a file or exact UTF-8 identity text.
if nargin<2,asFile=true;end
if asFile
    fid=fopen(input,'rb');assert(fid>=0,'NkSer:HashRead','Missing %s',input);
    cleanup=onCleanup(@()fclose(fid));bytes=fread(fid,Inf,'*uint8');
else
    bytes=uint8(unicode2native(char(input),'UTF-8'));
end
digest=java.security.MessageDigest.getInstance('SHA-256');
if ~isempty(bytes),digest.update(typecast(bytes(:),'int8'));end
value=lower(reshape(dec2hex(typecast(digest.digest(),'uint8'),2).',1,[]));
end
