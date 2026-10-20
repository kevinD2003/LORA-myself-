function roots=acSetup()
%ACSETUP Activate only this independent experiment and frozen dependencies.
root=fileparts(mfilename('fullpath'));
addpath(root,fullfile(root,'src','channel'),fullfile(root,'src','channel','vendor'), ...
    fullfile(root,'src','generation_vendor'),fullfile(root,'src','methods'),'-begin');
identity=acMethodSources();
generation=fullfile(root,'src','generation_vendor');
manifest=jsondecode(fileread(fullfile(generation,'SOURCE_MANIFEST.json')));
for k=1:numel(manifest.files)
    item=manifest.files(k);file=fullfile(generation,item.file);
    assert(strcmp(acHash(file),item.sha256),'Ac:GeneratorChanged','Frozen generator changed.');
    [~,name]=fileparts(item.file);
    assert(strcmpi(which(name),file),'Ac:GeneratorPath','Wrong generator %s',name);
end
roots=struct('root',root,'receiverIdentity',identity);
end
