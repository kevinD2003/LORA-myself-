function hash = fileSha256(filePath)
%FILESHA256 Return the lowercase SHA-256 digest of one file.

arguments
    filePath (1,1) string {mustBeFile}
end

messageDigest = java.security.MessageDigest.getInstance('SHA-256');
fileStream = java.io.FileInputStream(char(filePath));
digestStream = java.security.DigestInputStream( ...
    fileStream, messageDigest);
closeStream = onCleanup(@() digestStream.close());
while digestStream.read() ~= -1
end
digestBytes = typecast(int8(messageDigest.digest()), 'uint8');
hash = lower(string(reshape(dec2hex(digestBytes, 2).', 1, [])));
end
