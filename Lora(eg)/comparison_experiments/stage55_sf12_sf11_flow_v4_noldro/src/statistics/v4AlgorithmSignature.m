function signature = v4AlgorithmSignature(root,parameters)
%V4ALGORITHMSIGNATURE SHA-256 over V4 MATLAB code, source manifest, and parameters.

files = [dir(fullfile(root,'config','*.m')); ...
    dir(fullfile(root,'src','coding','*.m')); ...
    dir(fullfile(root,'src','phy','*.m')); ...
    dir(fullfile(root,'src','stage55','*.m')); ...
    dir(fullfile(root,'src','paper','*.m'))];
paths = strings(numel(files),1);
for index = 1:numel(files)
    paths(index) = string(fullfile(files(index).folder,files(index).name));
end
paths = sort(paths);
digest = java.security.MessageDigest.getInstance('SHA-256');
for index = 1:numel(paths)
    relative = erase(paths(index),string(root)+filesep);
    digest.update(unicode2native(char(relative),'UTF-8'));
    digest.update(uint8(0));
    digest.update(unicode2native(fileread(paths(index)),'UTF-8'));
    digest.update(uint8(0));
end
sourceManifest = fileread(fullfile(root,'config','source_manifest.json'));
digest.update(unicode2native(sourceManifest,'UTF-8'));
digest.update(uint8(0));
digest.update(unicode2native(jsonencode(parameters),'UTF-8'));
bytes = typecast(digest.digest(),'uint8');
signature = lower(reshape(dec2hex(bytes,2).',1,[]));
end
