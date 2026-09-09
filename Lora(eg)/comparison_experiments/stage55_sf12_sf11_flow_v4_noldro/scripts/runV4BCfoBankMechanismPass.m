function result=runV4BCfoBankMechanismPass()
root=v4SetupPaths();c=sf12NoLdroSf11FlowConfig();p=v4DefaultBParameters();schedule=v4ContinuousPassSchedule(c);state=struct('time',schedule.passStartTimeSec,'phase',0,'cross',struct());errors=zeros(3,4);eligible=0;
for fi=1:schedule.frameCount
    ledger=v4RandomLedger(c,'validation',6,1,fi);frame=v4GenerateContinuousFrame(c,state.time,-21,ledger,state.phase,'AWGN');state.time=frame.nextFrameStartTimeSec;state.phase=frame.nextFrameStartPhaseRad;
    if ~schedule.metricEligible(fi),state.cross=struct();continue,end
    eligible=eligible+1;b=v4CommonBootstrap(frame.observation.rxPhysical(1:8,:),c,SearchStepBins=p.searchStepBins);measurement=schedule.frameStartTimeSec(fi)+4*c.symbolDurationSec;[rate,state.cross]=v4CrossFrameRateUpdate(state.cross,measurement,mean(b.cfoBins),b.rateBinsPerSec,c,p);
    rx={v4HuangStaticDecode(frame.observation,b,c),v4Stage55CfoBankDecode(frame.observation,b,c,p,CrossFrameRateBinsPerSec=rate,CrossFrameHistoryCount=state.cross.historyCount),v4PaperMidambleDecode(frame.observation,b,c,p)};
    for method=1:3,m=v4EvaluateFrame(rx{method},frame.truth,c);errors(method,:)=errors(method,:)+[m.symbolErrors m.hardBitErrors m.softBitErrors m.packetError];end
    if mod(eligible,10)==0,fprintf('B cumulative bank v4 frames %d\n',eligible);end
end
den=[eligible*112 eligible*768 eligible*768 eligible];result=struct('status','PASS','algorithmVersion','Stage55-B-cumulative-block-CFO-bank-v4','rawErrors',errors,'denominators',den,'metrics',errors./den,'eligibleFrames',eligible,'conditionsFrozen',true);folder=fullfile(root,'results','b_exploratory','cfo_bank_v4');if ~isfolder(folder),mkdir(folder);end;save(fullfile(folder,'mechanism_pass.mat'),'result','-v7.3');write(fullfile(folder,'mechanism_pass.json'),jsonencode(result,'PrettyPrint',true));
end
function write(path,text),f=fopen(path,'w','n','UTF-8');cl=onCleanup(@()fclose(f));fprintf(f,'%s\n',text);clear cl,end
