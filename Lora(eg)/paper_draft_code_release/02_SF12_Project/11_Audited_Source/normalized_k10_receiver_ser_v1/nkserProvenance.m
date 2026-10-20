function manifest=nkserProvenance(root)
%NKSERPROVENANCE Exact numerical sources for the new Rician packet cohort.
roots=nkserSetup();
active={'nkserHash.m','nkserProjectConditions.m','nkserProvenance.m', ...
    'nkserRunPoint.m','nkserRunShard.m','nkserSetup.m'};
localPaths=cellfun(@(name)fullfile(root,name),active,'UniformOutput',false);
channelNames={'CHANNEL_PROFILE.json','nk10Config.m','nk10Hash.m','nk10Setup.m', ...
    fullfile('src','nk10ApplyChannel.m'),fullfile('src','nk10DrawTaps.m'), ...
    fullfile('src','nk10GeneratePair.m'),fullfile('src','nk10Profile.m')};
channelPaths=cellfun(@(name)fullfile(roots.channelRoot,name),channelNames,'UniformOutput',false);
generation=dir(fullfile(roots.generation,'*'));
generationPaths=arrayfun(@(item)fullfile(item.folder,item.name), ...
    generation(~[generation.isdir]),'UniformOutput',false);
methodFiles=[dir(fullfile(roots.methods,'*.m'));dir(fullfile(roots.methods,'*.json')); ...
    dir(fullfile(roots.methods,'vendor','*.m'));dir(fullfile(roots.methods,'vendor','*.json'))];
methodPaths=arrayfun(@(item)fullfile(item.folder,item.name),methodFiles,'UniformOutput',false);
paths=sort(unique([localPaths(:);channelPaths(:);generationPaths(:);methodPaths(:)]));
manifest=repmat(struct('path','','sha256',''),numel(paths),1);
for k=1:numel(paths)
    assert(isfile(paths{k}),'NkSer:MissingSource','Missing source %s',paths{k});
    manifest(k)=struct('path',strrep(paths{k},'\','/'),'sha256',nkserHash(paths{k}));
end
end
