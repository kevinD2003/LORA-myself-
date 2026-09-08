function artifact=runV4Stage3SValidation(roundNumber)
root=v4SetupPaths();config=sf12NoLdroSf11FlowConfig();manifestPath=fullfile(root,'config',sprintf('paperReceiverParameterManifest_stage3s_v%02d.json',roundNumber));m=jsondecode(fileread(manifestPath));
if ~strcmp(m.status,'calibrated-not-validated'),error('V4:Stage3SValidationState','Expected calibrated manifest.');end
[~,meta]=v4Stage3SCandidateTable(root,roundNumber);expected=v4Stage3SSignature(root,m.parameters,meta.hash);if ~strcmp(expected,m.algorithmSignature),error('V4:Stage3SSignature','Parameter signature mismatch.');end
seed=jsondecode(fileread(fullfile(root,'config','seed_protocol_r5_stage3s.json')));domain=sprintf('a_3s_validation_v%d',roundNumber);rootSeed=seed.domains.(domain);
folder=fullfile(root,'results','stage3s','Stage55-A-point-anchored-provisional-lock-v2',m.parameterVersion,'validation');if ~isfolder(folder),mkdir(folder);end
signature=v4Sha256([m.algorithmSignature '|' domain '|packets=2000|snr=-21']);checkpoint=fullfile(folder,'validation_checkpoint.mat');
if isfile(checkpoint),state=v4LoadCheckpoint(checkpoint,signature);else,state=struct('completed',zeros(2,1),'accepted',zeros(2000,2),'falseAccepted',zeros(2000,2),'cfoSse',zeros(2000,2),'finite',true(2000,2),'lost',false(2000,2));end
cases=[-366 0];
for ci=1:2
    for packetId=state.completed(ci)+1:2000
        packet=v4GenerateTrackAPacket(config,cases(ci),-21,packetId,rootSeed+100000*ci);receiver=v4TrackAStage55PointAnchoredDecode(packet,config,m.parameters);metric=v4EvaluateTrackAPacket(receiver,packet.truth,config);
        state.accepted(packetId,ci)=metric.vpAccepted;state.falseAccepted(packetId,ci)=metric.vpFalseAccepted;state.cfoSse(packetId,ci)=metric.cfoSquaredErrorBins;
        state.finite(packetId,ci)=all(isfinite(receiver.estimatedCfoBins));state.lost(packetId,ci)=strcmp(receiver.finalLockState,'LOST');state.completed(ci)=packetId;
        if mod(packetId,100)==0||packetId==2000,v4WriteCheckpointAtomic(checkpoint,state,signature);fprintf('Stage3S validation v%d Case %g: %d/2000\n',roundNumber,cases(ci),packetId);end
    end
end
gate=repmat(struct('caseStartTimeSec',0,'packets',2000,'possible',46000,'accepted',0,'falseAccepted',0,'falseAcceptance',NaN,'coverage',0,'acceptedMinimumPassed',false,'clusterCi95',[NaN NaN],'lostPackets',0,'passed',false),2,1);
for ci=1:2
    accepted=sum(state.accepted(:,ci));falseAccepted=sum(state.falseAccepted(:,ci));if accepted>0,fa=falseAccepted/accepted;else,fa=NaN;end;coverage=accepted/46000;
    stream=RandStream('mt19937ar','Seed',rootSeed+900000+ci);draw=zeros(2000,1);
    for b=1:2000,index=randi(stream,2000,2000,1);den=sum(state.accepted(index,ci));if den>0,draw(b)=sum(state.falseAccepted(index,ci))/den;else,draw(b)=NaN;end,end
    ci95=prctile(draw(isfinite(draw)),[2.5 97.5]);passed=isfinite(fa)&&fa<=0.02&&coverage>=0.01&&accepted>=200&&all(state.finite(:,ci));
    gate(ci)=struct('caseStartTimeSec',cases(ci),'packets',2000,'possible',46000,'accepted',accepted,'falseAccepted',falseAccepted,'falseAcceptance',fa,'coverage',coverage,'acceptedMinimumPassed',accepted>=200,'clusterCi95',ci95,'lostPackets',sum(state.lost(:,ci)),'passed',passed);
end
passed=all([gate.passed]);artifact=struct('status',ternary(passed,'PASS','FAIL'),'round',roundNumber,'parameterVersion',m.parameterVersion,'algorithmSignature',m.algorithmSignature,'seedDomain',domain,'gateRecords',gate,'packetRecords',state,'usesPerformanceRanking',false);
save(fullfile(folder,'stage3s_validation.mat'),'artifact','-v7.3');jsonPath=fullfile(folder,'stage3s_validation.json');summary=rmfield(artifact,'packetRecords');write(jsonPath,jsonencode(summary,'PrettyPrint',true));
if passed,m.status='validated';m.validationDomain=domain;m.validationArtifactHash=v4Sha256(jsonPath);write(manifestPath,jsonencode(m,'PrettyPrint',true));else,error('V4:Stage3SValidationGate','Stage3S validation failed.');end
end
function x=ternary(ok,a,b),if ok,x=a;else,x=b;end,end
function write(path,text),f=fopen(path,'w','n','UTF-8');c=onCleanup(@()fclose(f));fprintf(f,'%s\n',text);clear c,end
