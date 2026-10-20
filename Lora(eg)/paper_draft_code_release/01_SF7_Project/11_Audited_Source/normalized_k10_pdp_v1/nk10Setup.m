function roots=nk10Setup()
%NK10SETUP Activate the independent normalized-K10 experiment and frozen PHY.
root=fileparts(mfilename('fullpath'));parent=fileparts(root);
frozen=fullfile(parent,'all_curves_symbolvp_k10');
generation=fullfile(frozen,'src','generation_vendor');
methods=fullfile(frozen,'src','methods');vendor=fullfile(methods,'vendor');
local=fullfile(root,'src');tests=fullfile(root,'tests');
addpath(generation,methods,vendor,root,local,tests,'-begin');

manifest=jsondecode(fileread(fullfile(generation,'SOURCE_MANIFEST.json')));
for k=1:numel(manifest.files)
    item=manifest.files(k);file=fullfile(generation,item.file);
    assert(strcmp(nk10Hash(file),item.sha256), ...
        'Nk10:FrozenGenerator','Frozen waveform helper changed: %s',file);
end
receiverIdentity=acMethodSources();
assert(strcmp(receiverIdentity.receiverVersion,'SenLoRa-V8-symbol-vp-experiment-v1'), ...
    'Nk10:ReceiverIdentity','Unexpected receiver snapshot.');
roots=struct('root',root,'frozen',frozen,'generation',generation, ...
    'methods',methods,'receiverIdentity',receiverIdentity);
end

