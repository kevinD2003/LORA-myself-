function identity = referenceSoftIdentity(inputPath,selected,maximumPositions,softWindow)
%REFERENCESOFTIDENTITY Bind frozen input/model and every new calculation source.
folder=setupReferenceSoftPhy;
if ~isfile(inputPath),error('ReferenceSoft:Input','Completed reference_phy.mat required.');end
inputPath=char(java.io.File(inputPath).getCanonicalPath());
loaded=load(inputPath,'result');parent=loaded.result;
current=referencePhyV6Identity(parent.config);
assert(strcmp(parent.signature,dreConfigurationSignature(current)), ...
    'ReferenceSoft:Source','Frozen parent sources/configuration do not match.');
sources=dir(fullfile(folder,'*.m'));
paths=cellfun(@(name)fullfile(folder,name),{sources.name},'UniformOutput',false);
paths=[paths {fullfile(folder,'reference_manifest.json'), ...
    fullfile(folder,'tests','reference_soft_oracle.py'), ...
    fullfile(folder,'tests','reference_soft_vectors.json')}];
hashes=strings(numel(paths),2);
for i=1:numel(paths),hashes(i,:)=[string(paths{i}),localHash(paths{i})];end
targetPath=fullfile(fileparts(folder),'results','full_phy_v5_O3000_Pall_S0_-5_-10_-15_-20','full_phy.mat');
identity=struct('parentSignature',parent.signature,'parentIdentity',current, ...
    'inputPath',inputPath,'inputSha256',localHash(inputPath),'sourceHashes',hashes, ...
    'targetPath',targetPath,'targetSha256',localHash(targetPath), ...
    'conditionIndices',selected,'maximumPositions',maximumPositions, ...
    'softWindow',softWindow, ...
    'profile','standard-maxlog-soft-phy-v1-author-unconfirmed', ...
    'schema','paired-standard-soft-exact-v1');
end
function sha = localHash(path)
file=fopen(path,'rb');if file<0,error('ReferenceSoft:Source','Missing source file.');end
cleanup=onCleanup(@()fclose(file));bytes=fread(file,Inf,'*uint8');
digest=java.security.MessageDigest.getInstance('SHA-256');digest.update(bytes);
sha=string(lower(reshape(dec2hex(typecast(digest.digest(),'uint8'),2).',1,[])));
end
