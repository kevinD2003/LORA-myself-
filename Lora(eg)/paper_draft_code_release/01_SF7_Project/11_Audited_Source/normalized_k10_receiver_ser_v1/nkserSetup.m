function roots=nkserSetup()
%NKSERSETUP Activate the independent SER-only normalized-K10 experiment.
root=fileparts(mfilename('fullpath'));
parent=fileparts(root);
channelRoot=fullfile(parent,'normalized_k10_pdp_v1');
frozenRoot=fullfile(parent,'all_curves_symbolvp_k10');
generation=fullfile(frozenRoot,'src','generation_vendor');
methods=fullfile(frozenRoot,'src','methods');
vendor=fullfile(methods,'vendor');
addpath(generation,methods,vendor,channelRoot,fullfile(channelRoot,'src'),root,'-begin');

generationManifest=jsondecode(fileread(fullfile(generation,'SOURCE_MANIFEST.json')));
for k=1:numel(generationManifest.files)
    item=generationManifest.files(k);file=fullfile(generation,item.file);
    assert(strcmp(nkserHash(file),item.sha256), ...
        'NkSer:FrozenGenerator','Frozen waveform source changed: %s',file);
end
receiverIdentity=acMethodSources();
assert(strcmp(receiverIdentity.receiverVersion,'SenLoRa-V8-symbol-vp-experiment-v1')&& ...
    receiverIdentity.sourceCount==54,'NkSer:ReceiverIdentity','Unexpected receiver snapshot.');
profilePath=fullfile(channelRoot,'CHANNEL_PROFILE.json');
assert(strcmp(nkserHash(profilePath), ...
    '1f596a8252e946cb64307d55fcc546e2b69dbc0f0106fb6737d137f5f639d350'), ...
    'NkSer:ProfileChanged','Registered normalized-K10 profile changed.');
roots=struct('root',root,'parent',parent,'channelRoot',channelRoot, ...
    'frozenRoot',frozenRoot,'generation',generation,'methods',methods, ...
    'receiverIdentity',receiverIdentity,'profilePath',profilePath);
end
