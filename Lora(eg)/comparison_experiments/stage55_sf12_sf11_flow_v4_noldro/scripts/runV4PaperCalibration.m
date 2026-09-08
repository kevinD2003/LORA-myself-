function artifact = runV4PaperCalibration()
%RUNV4PAPERCALIBRATION Finite Track A mechanism-only candidate selection.
root = v4SetupPaths(); config = sf12NoLdroSf11FlowConfig();
base = v4TrackADefaultParameters();
decision = [3 4 5 6]; entropy = [0.10 0.30]; residual = [1.01 1.10];
innovation = [0.10 0.25]; maxRate = 12;
candidates = repmat(base,32,1); row = 0;
for a=1:4, for b=1:2, for c=1:2, for d=1:2
    row=row+1; candidates(row)=base;
    candidates(row).decisionPeakRatioThreshold=decision(a);
    candidates(row).maximumNormalizedEntropy=entropy(b);
    candidates(row).residualPeakRatioThreshold=residual(c);
    candidates(row).innovationLimitBins=innovation(d);
    candidates(row).maximumRateBinsPerSec=maxRate;
end, end, end, end
records = repmat(struct('candidateIndex',0,'accepted',0,'falseAccepted',0, ...
    'possible',0,'falseAcceptance',NaN,'coverage',0,'cfoRmseBins',Inf),32,1);
for index = 1:32
    accepted=0; falseAccepted=0; possible=0; sse=0; count=0;
    for caseTime = [-366 0]
        for packetId = 1:4
            packet = v4GenerateTrackAPacket(config,caseTime,-21,packetId,422000000+10000*index);
            receiver = v4TrackAStage55Decode(packet,config,candidates(index));
            metrics = v4EvaluateTrackAPacket(receiver,packet.truth,config);
            accepted = accepted+metrics.vpAccepted;
            falseAccepted = falseAccepted+metrics.vpFalseAccepted;
            possible = possible+23; sse=sse+metrics.cfoSquaredErrorBins; count=count+23;
        end
    end
    records(index)=struct('candidateIndex',index,'accepted',accepted, ...
        'falseAccepted',falseAccepted,'possible',possible, ...
        'falseAcceptance',falseAccepted/max(accepted,1),'coverage',accepted/possible, ...
        'cfoRmseBins',sqrt(sse/count));
end
valid = find([records.accepted]>0 & [records.falseAcceptance]<=0.02 & [records.coverage]>=0.01);
folder=fullfile(root,'results','calibration','track_a','A-param-v03');
if ~isfolder(folder), mkdir(folder); end
if isempty(valid)
    artifact=struct('status','FAIL','parameterVersion','A-param-v03', ...
        'round',3,'records',records,'selectionUsesSerOrBer',false, ...
        'failure','No candidate met false-acceptance and coverage gates.');
    save(fullfile(folder,'track_a_calibration.mat'),'artifact','-v7.3');
    localWrite(fullfile(folder,'track_a_calibration.json'),jsonencode(artifact,'PrettyPrint',true));
    error('V4:TrackACalibration','No Track A candidate met the mechanism quality gate.');
end
score = [[records(valid).coverage].' -[records(valid).cfoRmseBins].' -valid(:)];
[~,order] = sortrows(score,[-1 -2 -3]); selectedIndex = valid(order(1));
parameters = candidates(selectedIndex); parameters.parameterVersion='A-param-v03';
identity = struct('trackId','A','parameterVersion',parameters.parameterVersion, ...
    'calibrationSeedDomain','a_calibration_round_3','candidateCount',32,'round',3);
runManifest = v4BuildRunManifest(root,identity);
artifact = struct('status','calibrated-not-validated','selectedCandidateIndex',selectedIndex, ...
    'parameters',parameters,'records',records,'runManifest',runManifest, ...
    'selectionUsesSerOrBer',false);
save(fullfile(folder,'track_a_calibration.mat'),'artifact','-v7.3');
localWrite(fullfile(folder,'track_a_calibration.json'),jsonencode(artifact,'PrettyPrint',true));
manifest=struct('status','calibrated-not-validated','parameterVersion','A-param-v03', ...
    'parameters',parameters,'algorithmSignature',runManifest.algorithmSignature, ...
    'calibrationArtifactHash',v4Sha256(fullfile(folder,'track_a_calibration.json')));
localWrite(fullfile(root,'config','paperReceiverParameterManifest.json'), ...
    jsonencode(manifest,'PrettyPrint',true));
end
function localWrite(path,text)
f=fopen(path,'w','n','UTF-8'); if f<0,error('V4:Write','Cannot write %s.',path);end
c=onCleanup(@()fclose(f)); fprintf(f,'%s\n',text); clear c
end
