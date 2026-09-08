function artifact=runV4Stage3SCalibration(roundNumber)
arguments,roundNumber (1,1) double {mustBeInteger,mustBeMember(roundNumber,[1 2])},end
root=v4SetupPaths();config=sf12NoLdroSf11FlowConfig();[candidates,meta]=v4Stage3SCandidateTable(root,roundNumber);
seed=jsondecode(fileread(fullfile(root,'config','seed_protocol_r5_stage3s.json')));domain=sprintf('a_3s_calibration_v%d',roundNumber);rootSeed=seed.domains.(domain);
signature=v4Stage3SSignature(root,candidates,meta.hash);folder=fullfile(root,'results','stage3s','Stage55-A-point-anchored-provisional-lock-v2',meta.parameterVersion,'calibration');if ~isfolder(folder),mkdir(folder);end
checkpoint=fullfile(folder,'calibration_checkpoint.mat');
if isfile(checkpoint),state=v4LoadCheckpoint(checkpoint,signature);else,state=struct('completedPackets',zeros(2,1),'accepted',zeros(32,2),'falseAccepted',zeros(32,2),'cfoSse',zeros(32,2),'cfoCount',zeros(32,2));end
cases=[-366 0];n=meta.packetsPerCandidateCase;
for ci=1:2
    for packetId=state.completedPackets(ci)+1:n
        packet=v4GenerateTrackAPacket(config,cases(ci),-21,packetId,rootSeed+100000*ci);
        for k=1:32
            receiver=v4TrackAStage55PointAnchoredDecode(packet,config,candidates(k));m=v4EvaluateTrackAPacket(receiver,packet.truth,config);
            state.accepted(k,ci)=state.accepted(k,ci)+m.vpAccepted;state.falseAccepted(k,ci)=state.falseAccepted(k,ci)+m.vpFalseAccepted;
            state.cfoSse(k,ci)=state.cfoSse(k,ci)+m.cfoSquaredErrorBins;state.cfoCount(k,ci)=state.cfoCount(k,ci)+23;
        end
        state.completedPackets(ci)=packetId;if mod(packetId,25)==0||packetId==n,v4WriteCheckpointAtomic(checkpoint,state,signature);fprintf('Stage3S calibration v%d Case %g: %d/%d packets\n',roundNumber,cases(ci),packetId,n);end
    end
end
records=repmat(struct('candidateIndex',0,'caseMinus366',struct(),'case0',struct(),'passesBothCases',false,'minimumCoverage',0,'meanCfoRmseBins',Inf),32,1);valid=false(32,1);
for k=1:32
    cm=repmat(struct('packets',n,'possible',n*23,'accepted',0,'falseAccepted',0,'falseAcceptance',NaN,'coverage',0,'cfoRmseBins',Inf,'passed',false),2,1);
    for ci=1:2
        accepted=state.accepted(k,ci);if accepted>0,fa=state.falseAccepted(k,ci)/accepted;else,fa=NaN;end;coverage=accepted/(n*23);
        cm(ci)=struct('packets',n,'possible',n*23,'accepted',accepted,'falseAccepted',state.falseAccepted(k,ci),'falseAcceptance',fa,'coverage',coverage,'cfoRmseBins',sqrt(state.cfoSse(k,ci)/state.cfoCount(k,ci)),'passed',accepted>=ceil(0.01*n*23)&&isfinite(fa)&&fa<=0.02);
    end
    valid(k)=all([cm.passed]);records(k)=struct('candidateIndex',k,'caseMinus366',cm(1),'case0',cm(2),'passesBothCases',valid(k),'minimumCoverage',min([cm.coverage]),'meanCfoRmseBins',mean([cm.cfoRmseBins]));
end
eligible=find(valid);selected=NaN;if ~isempty(eligible),score=[-[records(eligible).minimumCoverage].' [records(eligible).meanCfoRmseBins].' eligible];[~,order]=sortrows(score,[1 2 3]);selected=eligible(order(1));end
artifact=struct('status',ternary(isfinite(selected),'PASS','FAIL'),'round',roundNumber,'parameterVersion',meta.parameterVersion,'algorithmVersion','Stage55-A-point-anchored-provisional-lock-v2','seedDomain',domain,'candidateTableHash',meta.hash,'algorithmSignature',signature,'calibrationPacketsPerCandidateCase',n,'records',records,'selectedCandidateIndex',selected,'selectionUsesSerOrBer',false);
save(fullfile(folder,'stage3s_calibration.mat'),'artifact','-v7.3');jsonPath=fullfile(folder,'stage3s_calibration.json');write(jsonPath,jsonencode(artifact,'PrettyPrint',true));
selectedParameters=pick(candidates,selected);if isfinite(selected),selectedSignature=v4Stage3SSignature(root,selectedParameters,meta.hash);else,selectedSignature='';end
pm=struct('status',ternary(isfinite(selected),'calibrated-not-validated','calibration-failed'),'parameterVersion',meta.parameterVersion,'round',roundNumber,'algorithmVersion',artifact.algorithmVersion,'candidateTableHash',meta.hash,'calibrationSignature',signature,'algorithmSignature',selectedSignature,'seedDomain',domain,'selectedCandidateIndex',selected,'parameters',selectedParameters,'calibrationArtifactHash',v4Sha256(jsonPath));
write(fullfile(root,'config',sprintf('paperReceiverParameterManifest_stage3s_v%02d.json',roundNumber)),jsonencode(pm,'PrettyPrint',true));
if ~isfinite(selected),error('V4:Stage3SCalibrationGate','Stage3S calibration round %d failed.',roundNumber);end
end
function x=ternary(ok,a,b),if ok,x=a;else,x=b;end,end
function x=pick(candidates,index),if isfinite(index),x=candidates(index);else,x=struct();end,end
function write(path,text),f=fopen(path,'w','n','UTF-8');c=onCleanup(@()fclose(f));fprintf(f,'%s\n',text);clear c,end
