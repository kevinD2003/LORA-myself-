function result=runV4R6ValidationA()
root=v4SetupPaths();c=sf12NoLdroSf11FlowConfig();pm=jsondecode(fileread(fullfile(root,'config','paperReceiverParameterManifest_stage3s_v01.json')));p=pm.parameters;p.bootstrapStepBins=0.05;cases=[-366 0];records=repmat(struct('caseStartTimeSec',0,'packets',2000,'paperErrors',0,'stageErrors',0,'symbols',46000,'paperSer',0,'stageSer',0,'deltaSer',0,'lower95',0,'upper95',0,'stageVpAccepted',0,'stageVpFalse',0),2,1);
for ci=1:2
    paperError=zeros(2000,1);stageError=zeros(2000,1);vp=zeros(2000,1);falseVp=zeros(2000,1);
    for id=1:2000
        q=v4GenerateTrackAPacket(c,cases(ci),-21,id,820000000+ci*100000);paper=v4PaperNativeMidambleDecode(q,c,false);stage=v4TrackAStage55TwoDownRateDecode(q,c,p);paperError(id)=sum(paper.detectedPhysicalBins~=q.truth.labels);stageError(id)=sum(stage.detectedPhysicalBins~=q.truth.labels);vp(id)=sum(stage.virtualPilotAccepted);falseVp(id)=sum(stage.virtualPilotAccepted&stage.vpUsedLabel~=q.truth.labels);if mod(id,200)==0,fprintf('R6 validation A Case %g: %d/2000\n',cases(ci),id);end
    end
    d=(stageError-paperError)/23;stream=RandStream('mt19937ar','Seed',820900000+ci);draw=zeros(5000,1);for b=1:5000,index=randi(stream,2000,2000,1);draw(b)=mean(d(index));end;bounds=prctile(draw,[2.5 97.5]);records(ci)=struct('caseStartTimeSec',cases(ci),'packets',2000,'paperErrors',sum(paperError),'stageErrors',sum(stageError),'symbols',46000,'paperSer',sum(paperError)/46000,'stageSer',sum(stageError)/46000,'deltaSer',mean(d),'lower95',bounds(1),'upper95',bounds(2),'stageVpAccepted',sum(vp),'stageVpFalse',sum(falseVp));
end
targetMet=all([records.stageSer]<[records.paperSer]);result=struct('status','PASS','planVersion','V4-noLDRO-plan-R6-stage55-algorithm-only-improvement','algorithmVersion','Stage55-A-two-downchirp-subbin-rate-v3','experimentConditionsFrozen',true,'seedDomain','r6_validation_820000000','records',records,'performanceTargetMetBothCases',targetMet,'performanceOrderingIsAuditGate',false);
folder=fullfile(root,'results','r6','validation','track_a');if ~isfolder(folder),mkdir(folder);end;save(fullfile(folder,'r6_validation_a.mat'),'result','-v7.3');write(fullfile(folder,'r6_validation_a.json'),jsonencode(result,'PrettyPrint',true));
end
function write(path,text),f=fopen(path,'w','n','UTF-8');cl=onCleanup(@()fclose(f));fprintf(f,'%s\n',text);clear cl,end
