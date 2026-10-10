function hash = exp1Sha256(value)
%EXP1SHA256 SHA-256 of a file or UTF-8 text.

if isstring(value)
    value = char(value);
end
if isfile(value)
    file = fopen(value,'rb');
    if file < 0
        error('EXP1:HashRead','Cannot read %s.',value);
    end
    cleanup = onCleanup(@()fclose(file));
    bytes = fread(file,Inf,'*uint8');
    clear cleanup
else
    bytes = unicode2native(value,'UTF-8');
end
digest = java.security.MessageDigest.getInstance('SHA-256');
if ~isempty(bytes)
    digest.update(typecast(uint8(bytes(:)),'int8'));
end
hashBytes = typecast(digest.digest(),'uint8');
hash = lower(reshape(dec2hex(hashBytes,2).',1,[]));
end

