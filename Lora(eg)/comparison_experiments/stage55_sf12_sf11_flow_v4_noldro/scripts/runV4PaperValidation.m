function artifact = runV4PaperValidation()
%RUNV4PAPERVALIDATION Independent fixed Track A validation domain.
root=v4SetupPaths(); config=sf12NoLdroSf11FlowConfig();
manifestPath=fullfile(root,'config','paperReceiverParameterManifest.json');
manifest=jsondecode(fileread(manifestPath));
if ~strcmp(manifest.status,'calibrated-not-validated'), error('V4:TrackAValidationState','Expected calibrated manifest.'); end
parameters=manifest.parameters; cases=[-366 0];
versionNumber=sscanf(manifest.parameterVersion,'A-param-v%d');
if versionNumber<1 || versionNumber>3,error('V4:TrackAValidationVersion','Invalid parameter version.');end
validationRoot=429000000+versionNumber*1000000;
validationDomain=sprintf('a_validation_v%d',versionNumber);
gateRecords=repmat(struct('caseStartTimeSec',0,'packetCount',2000,'accepted',0, ...
    'falseAccepted',0,'possible',0,'falseAcceptance',NaN,'coverage',0,'passed',false),2,1);
for caseIndex=1:2
    accepted=0; falseAccepted=0;
    for packetId=1:2000
        packet=v4GenerateTrackAPacket(config,cases(caseIndex),-21,packetId,validationRoot+100000*caseIndex);
        receiver=v4TrackAStage55Decode(packet,config,parameters);
        metrics=v4EvaluateTrackAPacket(receiver,packet.truth,config);
        accepted=accepted+metrics.vpAccepted; falseAccepted=falseAccepted+metrics.vpFalseAccepted;
    end
    possible=2000*23; fa=falseAccepted/max(accepted,1); coverage=accepted/possible;
    passed=accepted>=200 && fa<=0.02 && coverage>=0.01;
    gateRecords(caseIndex)=struct('caseStartTimeSec',cases(caseIndex), ...
        'packetCount',2000,'accepted',accepted,'falseAccepted',falseAccepted, ...
        'possible',possible,'falseAcceptance',fa,'coverage',coverage,'passed',passed);
end
safety=repmat(struct('caseStartTimeSec',0,'snrDb',0,'packetCount',500, ...
    'finite',true,'accepted',0,'falseAccepted',0),4,1); row=0;
for caseIndex=1:2
    for snrDb=[-30 -25]
        row=row+1; accepted=0; falseAccepted=0; finite=true;
        for packetId=1:500
            packet=v4GenerateTrackAPacket(config,cases(caseIndex),snrDb,packetId,validationRoot+500000+100000*row);
            receiver=v4TrackAStage55Decode(packet,config,parameters);
            metrics=v4EvaluateTrackAPacket(receiver,packet.truth,config);
            accepted=accepted+metrics.vpAccepted; falseAccepted=falseAccepted+metrics.vpFalseAccepted;
            finite=finite && all(isfinite(receiver.estimatedCfoBins));
        end
        safety(row)=struct('caseStartTimeSec',cases(caseIndex),'snrDb',snrDb, ...
            'packetCount',500,'finite',finite,'accepted',accepted,'falseAccepted',falseAccepted);
    end
end
passed=all([gateRecords.passed]) && all([safety.finite]);
artifact=struct('status',ternary(passed,'PASS','FAIL'),'parameterVersion', ...
    manifest.parameterVersion,'seedDomain',validationDomain,'gateRecords',gateRecords, ...
    'lowSnrSafety',safety,'usesPerformanceRanking',false);
folder=fullfile(root,'results','validation','track_a',manifest.parameterVersion);
if ~isfolder(folder),mkdir(folder);end
save(fullfile(folder,'track_a_validation.mat'),'artifact','-v7.3');
localWrite(fullfile(folder,'track_a_validation.json'),jsonencode(artifact,'PrettyPrint',true));
if ~passed, error('V4:TrackAValidationGate','Track A validation gate failed.'); end
manifest.status='frozen'; manifest.validationDomain=validationDomain;
manifest.validationArtifactHash=v4Sha256(fullfile(folder,'track_a_validation.json'));
localWrite(manifestPath,jsonencode(manifest,'PrettyPrint',true));
end
function value=ternary(c,a,b),if c,value=a;else,value=b;end,end
function localWrite(path,text),f=fopen(path,'w','n','UTF-8');c=onCleanup(@()fclose(f));fprintf(f,'%s\n',text);clear c,end
