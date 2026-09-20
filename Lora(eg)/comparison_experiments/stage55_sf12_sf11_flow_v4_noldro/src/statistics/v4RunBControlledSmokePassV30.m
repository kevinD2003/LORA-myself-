function result=v4RunBControlledSmokePassV30(root,c,lowP,highP,channelModel,outFolder,runOptions)
if nargin<7,runOptions=struct();end
snrDb=localOption(runOptions,'snrDb',-24);seedRoot=localOption(runOptions,'seedRoot',540000000);
phase=localOption(runOptions,'keyPhase',['smoke-v30-controlled-' lower(channelModel)]);
passIndex=localOption(runOptions,'passIndex',1);domain=localOption(runOptions,'domain',['b_smoke_controlled_' lower(channelModel)]);
identity=struct('planVersion','V4-noLDRO-plan-R3-project-aligned','phase',phase,'track','B','channel',channelModel, ...
 'comparisonMode','controlled-time','snrDb',snrDb,'replicateId',passIndex,'algorithmVersion','Stage55-B-startup-observability-v30', ...
 'algorithmHash',v4Sha256(fullfile(root,'src','stage55','v4Stage55DualBootstrapDecodeV30.m')),'seedRoot',seedRoot);
signature=v4Sha256(v4CanonicalJson(identity));matPath=fullfile(outFolder,sprintf('pass_%02d.mat',passIndex));jsonPath=fullfile(outFolder,sprintf('pass_%02d.json',passIndex));
if isfile(matPath)&&isfile(jsonPath),x=load(matPath,'result');if ~strcmp(x.result.runSignature,signature),error('V4:CheckpointSignature','controlled smoke mismatch.');end;result=x.result;result.resumedWithoutRecount=true;return
elseif isfile(matPath)||isfile(jsonPath),error('V4:PartialCheckpoint','Partial controlled smoke checkpoint.');end
timer=tic;started=datetime('now','TimeZone','local');s=v4ContinuousPassSchedule(c);state=struct('time',s.passStartTimeSec,'phase',0,'stageCross',struct(),'commonCross',struct());
errors=zeros(3,4);eligible=0;vp=0;falseVp=0;runtime=zeros(3,1);deadline=false(3,1);ledgers=cell(s.frameCount,1);
for fi=1:s.frameCount
 key=struct('planVersion','V4-noLDRO-plan-R3-project-aligned','phase',phase,'track','B','channel',channelModel, ...
  'comparisonMode','controlled-time','snrDb',snrDb,'replicateId',passIndex,'packetId',fi,'eventType','complete-frame','eventIndex',fi,'sampleIndex',0);
 l=v4EventRandomLedger(seedRoot,key);ledgers{fi}=l.ledgerHash;frame=v4GenerateContinuousFrame(c,state.time,snrDb,l,state.phase,channelModel);state.time=frame.nextFrameStartTimeSec;state.phase=frame.nextFrameStartPhaseRad;
 if ~s.metricEligible(fi),state.stageCross=struct();state.commonCross=struct();continue,end;eligible=eligible+1;
 pilots=frame.observation.rxPhysical(1:8,:);common=v4CommonBootstrap(pilots,c,SearchStepBins=lowP.searchStepBins);robust=v4BIndividualPreambleRate(pilots,c,lowP.searchStepBins);measurement=s.frameStartTimeSec(fi)+4*c.symbolDurationSec;
 [commonRate,state.commonCross]=v4CrossFrameRateUpdate(state.commonCross,measurement,mean(common.cfoBins),robust.rateBinsPerSec,c,highP);[crossBootstrap,state.stageCross,d]=v4Stage55CrossFrameBootstrapUpdate(state.stageCross,pilots,common,measurement,c,lowP);
 t=tic;rx1=v4HuangStaticDecode(frame.observation,common,c);runtime(1)=runtime(1)+toc(t);t=tic;rx2=v4Stage55DualBootstrapDecodeV30(frame.observation,common,crossBootstrap,c,lowP,highP,CommonRateBinsPerSec=commonRate,CommonHistoryCount=state.commonCross.historyCount,CrossRateBinsPerSec=d.rateBinsPerSec,CrossHistoryCount=d.historyCount);runtime(2)=runtime(2)+toc(t);t=tic;rx3=v4PaperMidambleDecode(frame.observation,common,c,lowP);runtime(3)=runtime(3)+toc(t);
 rx={rx1,rx2,rx3};for method=1:3,m=v4EvaluateFrame(rx{method},frame.truth,c);errors(method,:)=errors(method,:)+[m.symbolErrors m.hardBitErrors m.softBitErrors m.packetError];end
 mask=rx2.virtualPilotAccepted;vp=vp+sum(mask);falseVp=falseVp+sum(mask&rx2.tracker.hardPhysicalBins~=frame.truth.payloadPhysicalBins);
end
den=[eligible*112 eligible*768 eligible*768 eligible];metrics=errors./den;deadline=runtime>eligible*s.frameDurationSec;
sent=repmat(s.frameCount,3,1);available=repmat(eligible,3,1);geometry=sent-available;systemPerMl=(geometry+errors(:,4))./sent;
goodput=(available-errors(:,4))*c.informationBitCount/(s.passEndTimeSec-s.passStartTimeSec);
mem=memory;result=struct('status','PASS','passIndex',passIndex,'runSignature',signature,'identity',identity,'algorithmVersion','Stage55-B-startup-observability-v30', ...
 'channel',channelModel,'mode','controlled-time','snrDb',snrDb,'rawErrors',errors,'denominators',den,'metrics',metrics, ...
 'eligibleFrames',eligible,'sentFrames',sent,'availableFrames',available,'geometryErasures',geometry, ...
 'systemPerMl',systemPerMl,'goodputBps',goodput,'vpAccepted',vp,'vpFalseAccepted',falseVp,'runtimeSec',runtime,'deadlineMiss',deadline, ...
 'wallTimeSec',toc(timer),'matlabMemoryBytes',mem.MemUsedMATLAB,'ledgerAggregateHash',v4Sha256(strjoin(ledgers,'')), ...
 'allFinite',all(isfinite(metrics),'all'),'conditionsFrozen',true,'selectionUsesTruth',false,'startedAt',char(started),'endedAt',char(datetime('now','TimeZone','local')),'resumedWithoutRecount',false);
if ~isfolder(outFolder),mkdir(outFolder),end;save(matPath,'result','-v7.3');write(jsonPath,jsonencode(result,'PrettyPrint',true));
end
function value=localOption(options,name,defaultValue)
if isfield(options,name),value=options.(name);else,value=defaultValue;end
end
function write(path,text),f=fopen(path,'w','n','UTF-8');cl=onCleanup(@()fclose(f));fprintf(f,'%s\n',text);clear cl,end
