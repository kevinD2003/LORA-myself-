function identity = referencePhyV6Identity(c)
%REFERENCEPHYV6IDENTITY Bind new sources AND frozen v5 dependencies; no migration.
folder=setupReferencePhyV6();strictFolder=fileparts(folder);
shared=strictPaperIdentity(strictPaperConfig(),'run_strict_full_phy.m');
sources=dir(fullfile(folder,'*.m'));
paths=cellfun(@(name)fullfile(folder,name),{sources.name},'UniformOutput',false);
paths=[paths {fullfile(folder,'tests','reference_oracle.py'), ...
    fullfile(folder,'tests','reference_vectors.json'),fullfile(folder,'reference_manifest.json')}];
hashes=shared.sourceHashes;
for i=1:numel(paths)
    file=fopen(paths{i},'rb');if file<0,error('ReferencePhyV6:Source','Missing %s',paths{i});end
    cleanup=onCleanup(@()fclose(file));bytes=fread(file,Inf,'*uint8');
    digest=java.security.MessageDigest.getInstance('SHA-256');digest.update(bytes);
    sha=lower(reshape(dec2hex(typecast(digest.digest(),'uint8'),2).',1,[]));
    hashes(end+1,:)=[string(paths{i}),string(sha)]; %#ok<AGROW>
    clear cleanup
end
identity=struct('config',c,'sourceHashes',hashes,'schema','reference-phy-v6-exact');
% The already complete v5 record must remain valid, independently of v6.
baseline=load(fullfile(strictFolder,'results','full_phy_v5_O3000_Pall_S0_-5_-10_-15_-20','full_phy.mat'),'result');
old=strictPaperIdentity(baseline.result.config,'run_strict_full_phy.m');
assert(strcmp(baseline.result.signature,dreConfigurationSignature(old)), ...
    'ReferencePhyV6:V5Changed','Frozen v5 source/configuration changed.');
end
