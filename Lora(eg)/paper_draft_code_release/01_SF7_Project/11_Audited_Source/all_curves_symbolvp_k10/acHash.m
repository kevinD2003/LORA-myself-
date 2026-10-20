function value=acHash(input,asFile)
%ACHASH SHA256 for files or exact UTF8 identity text.
if nargin<2,asFile=true;end
if asFile
    fid=fopen(input,'rb');assert(fid>=0,'Ac:HashRead','Missing %s',input);
    cleanup=onCleanup(@()fclose(fid));bytes=fread(fid,Inf,'*uint8');
else
    bytes=uint8(unicode2native(char(input),'UTF-8'));
end
digest=java.security.MessageDigest.getInstance('SHA-256');
if ~isempty(bytes),digest.update(typecast(bytes(:),'int8'));end
value=lower(reshape(dec2hex(typecast(digest.digest(),'uint8'),2).',1,[]));
end
