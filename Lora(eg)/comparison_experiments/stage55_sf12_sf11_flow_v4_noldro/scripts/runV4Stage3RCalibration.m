function artifact=runV4Stage3RCalibration(roundNumber)
%RUNV4STAGE3RCALIBRATION Fixed 500-packet/Case/candidate R4 calibration.
arguments,roundNumber (1,1) double {mustBeInteger,mustBeMember(roundNumber,[1 2])},end
root=v4SetupPaths();config=sf12NoLdroSf11FlowConfig();
[candidates,metadata]=v4Stage3RCandidateTable(root,roundNumber);
seed=jsondecode(fileread(fullfile(root,'config','seed_protocol_r4_stage3r.json')));
domain=sprintf('a_3r_calibration_v%d',roundNumber);rootSeed=seed.domains.(domain);
signature=v4Stage3RSignature(root,candidates,metadata.hash);
folder=fullfile(root,'results','stage3r','Stage55-A-causal-pending-lock-v1', ...
    metadata.parameterVersion,'calibration');if ~isfolder(folder),mkdir(folder);end
checkpoint=fullfile(folder,'calibration_checkpoint.mat');
if isfile(checkpoint)
    state=v4LoadCheckpoint(checkpoint,signature);
else
    state=struct('completedPackets',zeros(2,1),'accepted',zeros(32,2), ...
        'falseAccepted',zeros(32,2),'cfoSse',zeros(32,2),'cfoCount',zeros(32,2));
end
cases=[-366 0];packetCount=metadata.calibrationPacketsPerCandidateCase;
for caseIndex=1:2
    for packetId=state.completedPackets(caseIndex)+1:packetCount
        packet=v4GenerateTrackAPacket(config,cases(caseIndex),-21,packetId, ...
            rootSeed+100000*caseIndex);
        for candidateIndex=1:32
            receiver=v4TrackAStage55PendingLockDecode(packet,config,candidates(candidateIndex));
            metrics=v4EvaluateTrackAPacket(receiver,packet.truth,config);
            state.accepted(candidateIndex,caseIndex)=state.accepted(candidateIndex,caseIndex)+metrics.vpAccepted;
            state.falseAccepted(candidateIndex,caseIndex)=state.falseAccepted(candidateIndex,caseIndex)+metrics.vpFalseAccepted;
            state.cfoSse(candidateIndex,caseIndex)=state.cfoSse(candidateIndex,caseIndex)+metrics.cfoSquaredErrorBins;
            state.cfoCount(candidateIndex,caseIndex)=state.cfoCount(candidateIndex,caseIndex)+23;
        end
        state.completedPackets(caseIndex)=packetId;
        if mod(packetId,25)==0 || packetId==packetCount
            v4WriteCheckpointAtomic(checkpoint,state,signature);
            fprintf('Stage3R calibration v%d Case %g: %d/%d packets\n', ...
                roundNumber,cases(caseIndex),packetId,packetCount);
        end
    end
end
records=repmat(struct('candidateIndex',0,'caseMinus366',struct(), ...
    'case0',struct(),'passesBothCases',false,'minimumCoverage',0,'meanCfoRmseBins',Inf),32,1);
valid=false(32,1);
for candidateIndex=1:32
    caseMetrics=repmat(struct('packets',packetCount,'possible',packetCount*23, ...
        'accepted',0,'falseAccepted',0,'falseAcceptance',NaN,'coverage',0, ...
        'cfoRmseBins',Inf,'passed',false),2,1);
    for caseIndex=1:2
        accepted=state.accepted(candidateIndex,caseIndex);
        if accepted>0,fa=state.falseAccepted(candidateIndex,caseIndex)/accepted;else,fa=NaN;end
        coverage=accepted/(packetCount*23);
        passed=accepted>=ceil(0.01*packetCount*23) && isfinite(fa) && fa<=0.02;
        caseMetrics(caseIndex)=struct('packets',packetCount,'possible',packetCount*23, ...
            'accepted',accepted,'falseAccepted',state.falseAccepted(candidateIndex,caseIndex), ...
            'falseAcceptance',fa,'coverage',coverage, ...
            'cfoRmseBins',sqrt(state.cfoSse(candidateIndex,caseIndex)/state.cfoCount(candidateIndex,caseIndex)), ...
            'passed',passed);
    end
    valid(candidateIndex)=all([caseMetrics.passed]);
    records(candidateIndex)=struct('candidateIndex',candidateIndex, ...
        'caseMinus366',caseMetrics(1),'case0',caseMetrics(2), ...
        'passesBothCases',valid(candidateIndex), ...
        'minimumCoverage',min([caseMetrics.coverage]), ...
        'meanCfoRmseBins',mean([caseMetrics.cfoRmseBins]));
end
eligible=find(valid);selectedIndex=NaN;
if ~isempty(eligible)
    score=[-[records(eligible).minimumCoverage].' [records(eligible).meanCfoRmseBins].' eligible];
    [~,order]=sortrows(score,[1 2 3]);selectedIndex=eligible(order(1));
end
status=ternary(isfinite(selectedIndex),'PASS','FAIL');
artifact=struct('status',status,'round',roundNumber,'parameterVersion',metadata.parameterVersion, ...
    'algorithmVersion','Stage55-A-causal-pending-lock-v1','seedDomain',domain, ...
    'candidateTableHash',metadata.hash,'algorithmSignature',signature, ...
    'calibrationPacketsPerCandidateCase',packetCount,'records',records, ...
    'selectedCandidateIndex',selectedIndex,'selectionUsesSerOrBer',false);
save(fullfile(folder,'stage3r_calibration.mat'),'artifact','-v7.3');
jsonPath=fullfile(folder,'stage3r_calibration.json');localWrite(jsonPath,jsonencode(artifact,'PrettyPrint',true));
parameterManifest=struct('status',ternary(isfinite(selectedIndex),'calibrated-not-validated','calibration-failed'), ...
    'parameterVersion',metadata.parameterVersion,'round',roundNumber, ...
    'algorithmVersion','Stage55-A-causal-pending-lock-v1','candidateTableHash',metadata.hash, ...
    'algorithmSignature',signature,'seedDomain',domain,'selectedCandidateIndex',selectedIndex, ...
    'parameters',ternaryStruct(isfinite(selectedIndex),candidates,selectedIndex), ...
    'calibrationArtifactHash',v4Sha256(jsonPath));
localWrite(fullfile(root,'config',sprintf('paperReceiverParameterManifest_stage3r_v%02d.json',roundNumber)), ...
    jsonencode(parameterManifest,'PrettyPrint',true));
if ~isfinite(selectedIndex),error('V4:Stage3RCalibrationGate','Stage 3R calibration round %d failed.',roundNumber);end
end
function value=ternary(ok,a,b),if ok,value=a;else,value=b;end,end
function value=ternaryStruct(ok,candidates,index),if ok,value=candidates(index);else,value=struct();end,end
function localWrite(path,text),f=fopen(path,'w','n','UTF-8');c=onCleanup(@()fclose(f));fprintf(f,'%s\n',text);clear c,end
