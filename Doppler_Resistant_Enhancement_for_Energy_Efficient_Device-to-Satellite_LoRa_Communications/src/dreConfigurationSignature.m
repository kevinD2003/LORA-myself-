function signature = dreConfigurationSignature(config)
%DRECONFIGURATIONSIGNATURE Stable SHA-256 of JSON-encoded configuration.

text = jsonencode(config);
digest = java.security.MessageDigest.getInstance('SHA-256');
digest.update(uint8(text));
bytes = typecast(digest.digest(),'uint8');
signature = lower(reshape(dec2hex(bytes,2).',1,[]));
end

