function artifact=runV4Stage3SSafety(roundNumber)
root=v4SetupPaths();c=sf12NoLdroSf11FlowConfig();path=fullfile(root,'config',sprintf('paperReceiverParameterManifest_stage3s_v%02d.json',roundNumber));m=jsondecode(fileread(path));if ~strcmp(m.status,'validated'),error('V4:Stage3SSafetyState','Expected validated parameters.');end
seed=jsondecode(fileread(fullfile(root,'config','seed_protocol_r5_stage3s.json')));domain=sprintf('a_3s_safety_v%d',roundNumber);base=seed.domains.(domain);cases=[-366 0];snrs=[-30 -25];records=repmat(struct('caseStartTimeSec',0,'snrDb',0,'packets',500,'finite',true,'timingValid',true,'stateBounded',true,'accepted',0,'falseAccepted',0,'lostPackets',0),4,1);row=0;
for ci=1:2,for si=1:2,row=row+1;for packetId=1:500
    q=v4GenerateTrackAPacket(c,cases(ci),snrs(si),packetId,base+100000*row);r=v4TrackAStage55PointAnchoredDecode(q,c,m.parameters);metric=v4EvaluateTrackAPacket(r,q.truth,c);
    records(row).accepted=records(row).accepted+metric.vpAccepted;records(row).falseAccepted=records(row).falseAccepted+metric.vpFalseAccepted;records(row).lostPackets=records(row).lostPackets+strcmp(r.finalLockState,'LOST');
    records(row).finite=records(row).finite&&all(isfinite(r.estimatedCfoBins));committed=find(r.virtualPilotAccepted);records(row).timingValid=records(row).timingValid&&all(r.firstEffectiveTimeSec(committed)>=r.releaseAtSec(committed)-1e-12);records(row).stateBounded=records(row).stateBounded&&numel(r.checkpointState.committedHistory)<=8&&all(r.vpUsedLabel(committed)>=0&r.vpUsedLabel(committed)<=4095);
    if mod(packetId,100)==0,fprintf('Stage3S safety Case %g SNR %g: %d/500\n',cases(ci),snrs(si),packetId);end
end;records(row).caseStartTimeSec=cases(ci);records(row).snrDb=snrs(si);end,end
passed=all([records.finite])&&all([records.timingValid])&&all([records.stateBounded]);artifact=struct('status',ternary(passed,'PASS','FAIL'),'parameterVersion',m.parameterVersion,'algorithmSignature',m.algorithmSignature,'seedDomain',domain,'records',records);
folder=fullfile(root,'results','stage3s','Stage55-A-point-anchored-provisional-lock-v2',m.parameterVersion,'safety');if ~isfolder(folder),mkdir(folder);end;save(fullfile(folder,'stage3s_safety.mat'),'artifact','-v7.3');json=fullfile(folder,'stage3s_safety.json');write(json,jsonencode(artifact,'PrettyPrint',true));if passed,m.status='safety-passed';m.safetyArtifactHash=v4Sha256(json);write(path,jsonencode(m,'PrettyPrint',true));else,error('V4:Stage3SSafety','Safety gate failed.');end
end
function x=ternary(ok,a,b),if ok,x=a;else,x=b;end,end
function write(path,text),f=fopen(path,'w','n','UTF-8');c=onCleanup(@()fclose(f));fprintf(f,'%s\n',text);clear c,end
