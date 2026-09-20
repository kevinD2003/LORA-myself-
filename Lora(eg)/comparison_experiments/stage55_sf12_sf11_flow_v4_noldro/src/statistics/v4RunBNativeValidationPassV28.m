function result=v4RunBNativeValidationPassV28(root,c,lowP,highP,passIndex,outFolder,receiverVersion,runOptions)
if nargin<7,receiverVersion='v28';end
if nargin<8,runOptions=struct();end
if strcmp(receiverVersion,'v30')
 algorithm='Stage55-B-startup-observability-v30';domain='b_native_validation_v30';keyPhase='native-validation-v30';topSource='v4Stage55DualBootstrapDecodeV30.m';
else
 algorithm='Stage55-B-unquantized-theory-gate-v28';domain='b_native_algorithm_validation_v28';keyPhase='native-algorithm-validation-v28';topSource='v4Stage55DualBootstrapDecodeV28.m';
end
seedRoot=localOption(runOptions,'seedRoot',532000000);
snrDb=localOption(runOptions,'snrDb',-21);
channelModel=localOption(runOptions,'channelModel','AWGN');
keyPhase=localOption(runOptions,'keyPhase',keyPhase);
domain=localOption(runOptions,'domain',domain);
identity=struct('planVersion','V4-noLDRO-plan-R3-project-aligned','phase',keyPhase, ...
 'track','B','channel',channelModel,'comparisonMode','native-overhead','snrDb',snrDb,'replicateId',passIndex, ...
 'algorithmVersion',algorithm,'algorithmHash',v4Sha256(fullfile(root,'src','stage55',topSource)), ...
 'lowParameterHash',v4Sha256(v4CanonicalJson(lowP)),'highParameterHash',v4Sha256(v4CanonicalJson(highP)), ...
 'timingHash',v4Sha256(fullfile(root,'config','frame_timing_manifest.json')),'seedRoot',seedRoot);
signature=v4Sha256(v4CanonicalJson(identity));matPath=fullfile(outFolder,sprintf('pass_%02d.mat',passIndex));jsonPath=fullfile(outFolder,sprintf('pass_%02d.json',passIndex));
if isfile(matPath)&&isfile(jsonPath),x=load(matPath,'result');if ~strcmp(x.result.runSignature,signature),error('V4:CheckpointSignature','native v28 mismatch.');end;result=x.result;return
elseif isfile(matPath)||isfile(jsonPath),error('V4:PartialCheckpoint','Partial native checkpoint.');end
started=datetime('now','TimeZone','local');timer=tic;short=v4NativeOverheadSchedule(c,'short');paperSchedule=v4NativeOverheadSchedule(c,'paper');
errors=zeros(3,4,3);den=zeros(3,4,3);vp=zeros(3,1);falseVp=zeros(3,1);available=zeros(3,1);runtime=zeros(3,1);deadline=zeros(3,1);
ledgerHashes=cell(2,1);shortLedgers=cell(short.frameCount,1);paperLedgers=cell(paperSchedule.frameCount,1);
state=struct('time',short.passStartTimeSec,'phase',0,'stageCross',struct(),'commonCross',struct());
for fi=1:short.frameCount
 key=localKey(passIndex,fi,'native-short-frame',keyPhase,channelModel,snrDb);ledger=v4EventRandomLedger(seedRoot,key);shortLedgers{fi}=ledger.ledgerHash;
 frame=v4GenerateNativeFrame(c,state.time,snrDb,ledger,state.phase,channelModel,false);state.time=frame.nextFrameStartTimeSec;state.phase=frame.nextFrameStartPhaseRad;
 if ~short.metricEligible(fi),state.stageCross=struct();state.commonCross=struct();continue,end
 elevation=rad2deg(v4Trajectory(short.frameCenterTimeSec(fi),c).elevationRad);regions=[1+(elevation>=30) 3];
 pilots=frame.observation.rxPhysical(1:8,:);common=v4CommonBootstrap(pilots,c,SearchStepBins=lowP.searchStepBins);robust=v4BIndividualPreambleRate(pilots,c,lowP.searchStepBins);measurement=short.frameStartTimeSec(fi)+4*c.symbolDurationSec;
 [commonRate,state.commonCross]=v4CrossFrameRateUpdate(state.commonCross,measurement,mean(common.cfoBins),robust.rateBinsPerSec,c,highP);
 [crossBootstrap,state.stageCross,d]=v4Stage55CrossFrameBootstrapUpdate(state.stageCross,pilots,common,measurement,c,lowP);
 t=tic;huang=v4HuangStaticDecode(frame.observation,common,c);runtime(1)=runtime(1)+toc(t);
 t=tic;
 if strcmp(receiverVersion,'v30')
  stage=v4Stage55DualBootstrapDecodeV30(frame.observation,common,crossBootstrap,c,lowP,highP, ...
   CommonRateBinsPerSec=commonRate,CommonHistoryCount=state.commonCross.historyCount,CrossRateBinsPerSec=d.rateBinsPerSec,CrossHistoryCount=d.historyCount);
 else
  stage=v4Stage55DualBootstrapDecodeV28(frame.observation,common,crossBootstrap,c,lowP,highP, ...
   CommonRateBinsPerSec=commonRate,CommonHistoryCount=state.commonCross.historyCount,CrossRateBinsPerSec=d.rateBinsPerSec,CrossHistoryCount=d.historyCount);
 end
 runtime(2)=runtime(2)+toc(t);
 rx={huang,stage};available(1:2)=available(1:2)+1;
 for r=regions
  for method=1:2,m=v4EvaluateFrame(rx{method},frame.truth,c);errors(method,:,r)=errors(method,:,r)+[m.symbolErrors m.hardBitErrors m.softBitErrors m.packetError];den(method,:,r)=den(method,:,r)+[112 768 768 1];end
  mask=stage.virtualPilotAccepted;vp(r)=vp(r)+sum(mask);falseVp(r)=falseVp(r)+sum(mask&stage.tracker.hardPhysicalBins~=frame.truth.payloadPhysicalBins);
 end
end
state=struct('time',paperSchedule.passStartTimeSec,'phase',0);
for fi=1:paperSchedule.frameCount
 key=localKey(passIndex,fi,'native-paper-frame',keyPhase,channelModel,snrDb);ledger=v4EventRandomLedger(seedRoot,key);paperLedgers{fi}=ledger.ledgerHash;
 frame=v4GenerateNativeFrame(c,state.time,snrDb,ledger,state.phase,channelModel,true);state.time=frame.nextFrameStartTimeSec;state.phase=frame.nextFrameStartPhaseRad;
 if ~paperSchedule.metricEligible(fi),continue,end
 elevation=rad2deg(v4Trajectory(paperSchedule.frameCenterTimeSec(fi),c).elevationRad);regions=[1+(elevation>=30) 3];
 common=v4CommonBootstrap(frame.observation.rxPhysical(1:8,:),c,SearchStepBins=lowP.searchStepBins);t=tic;paper=v4PaperMidambleDecode(frame.observation,common,c,lowP);runtime(3)=runtime(3)+toc(t);available(3)=available(3)+1;
 for r=regions,m=v4EvaluateFrame(paper,frame.truth,c);errors(3,:,r)=errors(3,:,r)+[m.symbolErrors m.hardBitErrors m.softBitErrors m.packetError];den(3,:,r)=den(3,:,r)+[112 768 768 1];end
end
ledgerHashes{1}=v4Sha256(strjoin(shortLedgers,''));ledgerHashes{2}=v4Sha256(strjoin(paperLedgers,''));metrics=errors./den;
sent=[short.frameCount;short.frameCount;paperSchedule.frameCount];geometry=sent-available;systemPerMl=(geometry+squeeze(errors(:,4,3)))./sent;
goodput=(available-squeeze(errors(:,4,3)))*c.informationBitCount/short.passDurationSec;
deadline(1)=runtime(1)>available(1)*short.frameDurationSec;deadline(2)=runtime(2)>available(2)*short.frameDurationSec;deadline(3)=runtime(3)>available(3)*paperSchedule.frameDurationSec;
result=struct('status','PASS','passIndex',passIndex,'runSignature',signature,'identity',identity,'algorithmVersion',algorithm, ...
 'validationDomain',domain,'seedRoot',seedRoot,'ledgerAggregateHash',v4Sha256(strjoin(ledgerHashes,'')), ...
 'rawErrors',errors,'denominators',den,'metrics',metrics,'vpAccepted',vp,'vpFalseAccepted',falseVp, ...
 'sentFrames',sent,'availableFrames',available,'geometryErasures',geometry,'systemPerMl',systemPerMl, ...
 'goodputBps',goodput,'frameDurationSec',[short.frameDurationSec;short.frameDurationSec;paperSchedule.frameDurationSec], ...
 'runtimeSec',runtime,'deadlineMiss',logical(deadline),'startedAt',char(started),'endedAt',char(datetime('now','TimeZone','local')), ...
 'wallTimeSec',toc(timer),'conditionsFrozen',true,'selectionUsesTruth',false,'rawSamplesClaimedPairedAcrossMethods',false);
if ~isfolder(outFolder),mkdir(outFolder),end;save(matPath,'result','-v7.3');write(jsonPath,jsonencode(result,'PrettyPrint',true));
end
function key=localKey(passIndex,frameIndex,eventType,keyPhase,channelModel,snrDb)
key=struct('planVersion','V4-noLDRO-plan-R3-project-aligned','phase',keyPhase, ...
 'track','B','channel',channelModel,'comparisonMode','native-overhead','snrDb',snrDb,'replicateId',passIndex, ...
 'packetId',frameIndex,'eventType',eventType,'eventIndex',frameIndex,'sampleIndex',0);
end
function value=localOption(options,name,defaultValue)
if isfield(options,name),value=options.(name);else,value=defaultValue;end
end
function write(path,text),f=fopen(path,'w','n','UTF-8');cl=onCleanup(@()fclose(f));fprintf(f,'%s\n',text);clear cl,end
