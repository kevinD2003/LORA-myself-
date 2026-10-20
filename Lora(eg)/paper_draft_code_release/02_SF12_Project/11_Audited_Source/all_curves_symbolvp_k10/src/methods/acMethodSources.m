function identity=acMethodSources()
%ACMETHODSOURCES Activate and verify this experiment's frozen receiver copy.
% The numerical receiver files are byte-preserved snapshots, not forks.
root=fileparts(mfilename('fullpath'));
vendor=fullfile(root,'vendor');
manifestPath=fullfile(root,'SOURCE_MANIFEST.json');
persistent verifiedPath identityCache entries
if isempty(verifiedPath) || ~strcmp(verifiedPath,manifestPath)
    manifest=jsondecode(fileread(manifestPath));
    for k=1:numel(manifest.files)
        entry=manifest.files(k);
        file=fullfile(vendor,entry.file);
        assert(isfile(file),'AllCurves:MissingReceiverSource','Missing %s.',file);
        assert(strcmp(localHash(file),entry.sha256), ...
            'AllCurves:ReceiverSourceChanged','Frozen receiver source changed: %s.',file);
    end
    identityCache=struct('receiverVersion',manifest.receiverVersion, ...
        'manifestSha256',localHash(manifestPath),'sourceCount',numel(manifest.files), ...
        'vendorDirectory',vendor,'manifestPath',manifestPath, ...
        'symbolVpEntrySha256',localHash(fullfile(vendor,'senloraSymmetricV8SymbolVpDecode.m')));
    verifiedPath=manifestPath;
    entries=cell(0,1);
    for k=1:numel(manifest.files)
        [~,name,extension]=fileparts(manifest.files(k).file);
        if strcmp(extension,'.m'), entries{end+1,1}=name; end %#ok<AGROW>
    end
end
% Reassert precedence in case another experiment changed the shared path.
if ~strcmp(fileparts(which('senloraSymmetricV8SymbolVpDecode')),vendor)
    addpath(vendor,'-begin');
end
for k=1:numel(entries)
    actual=which(entries{k});
    assert(strcmpi(actual,fullfile(vendor,[entries{k} '.m'])), ...
        'AllCurves:ReceiverPath','Unexpected receiver implementation for %s: %s.',entries{k},actual);
end
identity=identityCache;
end

function hash=localHash(file)
fid=fopen(file,'rb');
assert(fid>=0,'AllCurves:HashRead','Cannot read %s.',file);
cleanup=onCleanup(@()fclose(fid));
bytes=fread(fid,Inf,'*uint8');
digest=java.security.MessageDigest.getInstance('SHA-256');
if ~isempty(bytes), digest.update(typecast(bytes(:),'int8')); end
hashBytes=typecast(digest.digest(),'uint8');
hash=lower(reshape(dec2hex(hashBytes,2).',1,[]));
end
