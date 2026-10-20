function manifest=acProvenance(root)
%ACPROVENANCE Active MATLAB code and frozen configuration bytes.
% Presentation code is recorded by reporting; it cannot change packet data.
active={'acExportPlan.m','acHardBits.m','acHash.m','acProjectConditions.m', ...
    'acProvenance.m','acSetup.m','runAcPoint.m','runAcShard.m'};
files=[dir(fullfile(root,'src','**','*.m'));dir(fullfile(root,'src','**','*.json'))];
paths=sort(unique(arrayfun(@(f)fullfile(f.folder,f.name),files,'UniformOutput',false)));
paths=sort([paths(:);cellfun(@(f)fullfile(root,f),active(:),'UniformOutput',false)]);
manifest=repmat(struct('path','','sha256',''),numel(paths),1);
for k=1:numel(paths)
    manifest(k)=struct('path',strrep(paths{k},'\','/'),'sha256',acHash(paths{k}));
end
end
