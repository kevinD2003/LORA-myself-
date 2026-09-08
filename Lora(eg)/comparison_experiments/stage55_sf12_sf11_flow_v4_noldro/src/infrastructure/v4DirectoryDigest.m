function result = v4DirectoryDigest(folder)
%V4DIRECTORYDIGEST Hash sorted relative paths and individual file hashes.
files = dir(fullfile(folder,'**','*'));
files = files(~[files.isdir]);
full = string(fullfile({files.folder},{files.name}));
[full,order] = sort(full);
files = files(order);
buffer = uint8([]);
for index = 1:numel(files)
    relative = extractAfter(full(index),strlength(string(folder))+1);
    relative = replace(relative,'\','/');
    line = [unicode2native(char(relative),'UTF-8') uint8(0) ...
        unicode2native(v4Sha256(char(full(index))),'UTF-8') uint8(10)];
    buffer = [buffer line]; %#ok<AGROW>
end
digest = java.security.MessageDigest.getInstance('SHA-256');
digest.update(typecast(buffer,'int8'));
hashBytes = typecast(digest.digest(),'uint8');
result = struct('path',folder,'fileCount',numel(files), ...
    'sha256',lower(reshape(dec2hex(hashBytes,2).',1,[])));
end
