function value=nk10Hash(file)
%NK10HASH SHA256 of one frozen source file.
fid=fopen(file,'rb');assert(fid>=0,'Nk10:HashRead','Missing %s',file);
cleanup=onCleanup(@()fclose(fid));bytes=fread(fid,Inf,'*uint8');
digest=java.security.MessageDigest.getInstance('SHA-256');
if ~isempty(bytes),digest.update(typecast(bytes(:),'int8'));end
value=lower(reshape(dec2hex(typecast(digest.digest(),'uint8'),2).',1,[]));
end

