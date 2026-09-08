function summary=v4RunTrackAFormalCellR5(root,config,parameters,algorithmSignature,caseIndex,snrIndex)
%V4RUNTRACKAFORMALCELLR5 Fixed 20000 paired packets for one Case/SNR.
cases=[-366 0];snrs=-30:-21;caseTime=cases(caseIndex);snrDb=snrs(snrIndex);n=20000;
formalCodeHash=v4Sha256([v4Sha256(mfilename('fullpath')) v4Sha256(fullfile(root,'src','paper_anchor','v4RunTrackAStage3SPairedPacket.m')) v4Sha256(fullfile(root,'src','paper_anchor','v4EvaluateTrackAPacket.m'))]);
cellSignature=v4Sha256(sprintf('%s|%s|R5-formal-A|case=%d|snr=%d|N=%d|seed=760000000',algorithmSignature,formalCodeHash,caseIndex,snrDb,n));
folder=fullfile(root,'results','formal','track_a','R5-point-anchored','A-3S-param-v01',sprintf('case_%d',caseIndex),sprintf('snr_%+03d',snrDb));if ~isfolder(folder),mkdir(folder);end
checkpoint=fullfile(folder,'checkpoint.mat');finalPath=fullfile(folder,'formal_cell.mat');
if isfile(finalPath),saved=load(finalPath,'formalCell');if strcmp(saved.formalCell.signature,cellSignature),summary=rmfield(saved.formalCell,'state');return,end;error('V4:FormalCellSignature','Existing final cell signature mismatch.');end
if isfile(checkpoint),state=v4LoadCheckpoint(checkpoint,cellSignature);else,state=localState(n);end
rootSeed=760000000+(caseIndex-1)*1000000+(snrIndex-1)*100000;
for packetId=state.completed+1:n
    x=v4RunTrackAStage3SPairedPacket(config,caseTime,snrDb,packetId,rootSeed,parameters);
    state.symbolErrors(packetId,:)=uint8(cellfun(@(m)m.symbolErrors,x.metrics));
    state.cfoSseBins(packetId,:)=cellfun(@(m)m.cfoSquaredErrorBins,x.metrics);
    state.runtimeSec(packetId,:)=single(x.runtimeSec);
    for method=1:4
        state.detectedLabels(packetId,method,:)=uint16(x.receivers{method}.detectedPhysicalBins);
        state.estimatedCfoBins(packetId,method,:)=single(x.receivers{method}.estimatedCfoBins);
    end
    state.truthLabels(packetId,:)=uint16(x.truth.labels);state.truthCfoBins(packetId,:)=single(x.truth.dataCfoHz/config.fftBinSpacingHz);
    stage=x.receivers{4};state.stageAccepted(packetId,:)=stage.virtualPilotAccepted;
    labels=stage.vpUsedLabel;labels(~isfinite(labels))=0;state.stageUsedLabel(packetId,:)=uint16(labels);
    state.stageReleaseSec(packetId,:)=single(stage.releaseAtSec);state.stageEffectiveSec(packetId,:)=single(stage.firstEffectiveTimeSec);
    state.stageState(packetId)=uint8(find(strcmp(stage.finalLockState,{'POINT_ANCHORED_PENDING','PROVISIONAL','LOCKED','LOST'}),1));
    state.stageFalseAccepted(packetId)=uint8(x.metrics{4}.vpFalseAccepted);state.initialPointBins(packetId)=int16(stage.pointAnchor.cfoBins);
    state.completed=packetId;
    if mod(packetId,250)==0||packetId==n,v4WriteCheckpointAtomic(checkpoint,state,cellSignature);fprintf('R5 formal A Case %d SNR %d: %d/%d\n',caseIndex,snrDb,packetId,n);end
end
formalCell=struct('caseIndex',caseIndex,'caseStartTimeSec',caseTime,'snrDb',snrDb,'fixedPackets',n,'completedPackets',state.completed,'signature',cellSignature,'algorithmSignature',algorithmSignature,'formalCodeHash',formalCodeHash,'seedRoot',rootSeed,'state',state);
save(finalPath,'formalCell','-v7.3');summary=rmfield(formalCell,'state');write(fullfile(folder,'formal_cell.json'),jsonencode(summary,'PrettyPrint',true));
end
function s=localState(n)
s=struct('completed',0,'symbolErrors',zeros(n,4,'uint8'),'cfoSseBins',zeros(n,4),'runtimeSec',zeros(n,4,'single'),'detectedLabels',zeros(n,4,23,'uint16'),'estimatedCfoBins',zeros(n,4,23,'single'),'truthLabels',zeros(n,23,'uint16'),'truthCfoBins',zeros(n,23,'single'),'stageAccepted',false(n,23),'stageUsedLabel',zeros(n,23,'uint16'),'stageReleaseSec',nan(n,23,'single'),'stageEffectiveSec',nan(n,23,'single'),'stageState',zeros(n,1,'uint8'),'stageFalseAccepted',zeros(n,1,'uint8'),'initialPointBins',zeros(n,1,'int16'));
end
function write(path,text),f=fopen(path,'w','n','UTF-8');c=onCleanup(@()fclose(f));fprintf(f,'%s\n',text);clear c,end
