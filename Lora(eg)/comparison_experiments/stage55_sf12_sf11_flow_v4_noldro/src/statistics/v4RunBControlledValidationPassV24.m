function result=v4RunBControlledValidationPassV24(root,c,lowP,highP,passIndex,outFolder,receiverVersion)
if nargin<7,receiverVersion='v24';end
if strcmp(receiverVersion,'v30')
 algorithmVersion='Stage55-B-startup-observability-v30';domain='b_controlled_validation_v30';keyPhase='controlled-validation-v30';topSource='v4Stage55DualBootstrapDecodeV30.m';
elseif strcmp(receiverVersion,'v28')
 algorithmVersion='Stage55-B-unquantized-theory-gate-v28';domain='b_algorithm_validation_v28';keyPhase='algorithm-validation-v28';topSource='v4Stage55DualBootstrapDecodeV28.m';
else
 algorithmVersion='Stage55-B-observable-dual-bootstrap-v24';domain='b_algorithm_validation_v24';keyPhase='algorithm-validation-v24';topSource='v4Stage55DualBootstrapDecodeV24.m';
end
seedRoot=532000000;
sourceNames={topSource,'v4Stage55CrossAnchoredDualBlockDecodeV21.m', ...
 'v4Stage55CausalBlockBankDecodeV17.m','v4Stage55CausalBlockBankDecodeV16.m','v4Stage55CrossFrameBootstrapUpdate.m'};
sourceHashes=cell(size(sourceNames));for i=1:numel(sourceNames),sourceHashes{i}=v4Sha256(fullfile(root,'src','stage55',sourceNames{i}));end
identity=struct('planVersion','V4-noLDRO-plan-R3-project-aligned','phase',keyPhase, ...
 'track','B','channel','AWGN','comparisonMode','controlled-time','snrDb',-21,'replicateId',passIndex, ...
 'algorithmVersion',algorithmVersion,'algorithmSourceHashes',{sourceHashes}, ...
 'lowParameterHash',v4Sha256(v4CanonicalJson(lowP)),'highParameterHash',v4Sha256(v4CanonicalJson(highP)), ...
 'validationDomain',domain,'seedRoot',seedRoot);
signature=v4Sha256(v4CanonicalJson(identity));matPath=fullfile(outFolder,sprintf('pass_%02d.mat',passIndex));jsonPath=fullfile(outFolder,sprintf('pass_%02d.json',passIndex));
if isfile(matPath)&&isfile(jsonPath),x=load(matPath,'result');if ~strcmp(x.result.runSignature,signature),error('V4:CheckpointSignature','v24 mismatch.');end;result=x.result;fprintf('B v24 pass %d already complete; not recounted.\n',passIndex);return
elseif isfile(matPath)||isfile(jsonPath),error('V4:PartialCheckpoint','Partial v24 checkpoint.');end
started=datetime('now','TimeZone','local');timer=tic;schedule=v4ContinuousPassSchedule(c);
state=struct('time',schedule.passStartTimeSec,'phase',0,'stageCross',struct(),'commonCross',struct());
errors=zeros(3,4,3);counts=zeros(4,3);vp=zeros(3,1);falseVp=zeros(3,1);frames=zeros(3,1);regimes=zeros(2,1);ledgerHashes=cell(schedule.frameCount,1);
for fi=1:schedule.frameCount
 key=struct('planVersion','V4-noLDRO-plan-R3-project-aligned','phase',keyPhase, ...
  'track','B','channel','AWGN','comparisonMode','controlled-time','snrDb',-21,'replicateId',passIndex, ...
  'packetId',fi,'eventType','complete-frame','eventIndex',fi,'sampleIndex',0);
 ledger=v4EventRandomLedger(seedRoot,key);ledgerHashes{fi}=ledger.ledgerHash;
 frame=v4GenerateContinuousFrame(c,state.time,-21,ledger,state.phase,'AWGN');state.time=frame.nextFrameStartTimeSec;state.phase=frame.nextFrameStartPhaseRad;
 if ~schedule.metricEligible(fi),state.stageCross=struct();state.commonCross=struct();continue,end
 trajectory=v4Trajectory(schedule.frameCenterTimeSec(fi),c);region=1+(rad2deg(trajectory.elevationRad)>=30);regions=[region 3];
 pilots=frame.observation.rxPhysical(1:8,:);common=v4CommonBootstrap(pilots,c,SearchStepBins=lowP.searchStepBins);
 robust=v4BIndividualPreambleRate(pilots,c,lowP.searchStepBins);measurement=schedule.frameStartTimeSec(fi)+4*c.symbolDurationSec;
 [commonRate,state.commonCross]=v4CrossFrameRateUpdate(state.commonCross,measurement,mean(common.cfoBins),robust.rateBinsPerSec,c,highP);
 [crossBootstrap,state.stageCross,d]=v4Stage55CrossFrameBootstrapUpdate(state.stageCross,pilots,common,measurement,c,lowP);
 if strcmp(receiverVersion,'v30')
  stage=v4Stage55DualBootstrapDecodeV30(frame.observation,common,crossBootstrap,c,lowP,highP, ...
   CommonRateBinsPerSec=commonRate,CommonHistoryCount=state.commonCross.historyCount, ...
   CrossRateBinsPerSec=d.rateBinsPerSec,CrossHistoryCount=d.historyCount);
 elseif strcmp(receiverVersion,'v28')
  stage=v4Stage55DualBootstrapDecodeV28(frame.observation,common,crossBootstrap,c,lowP,highP, ...
   CommonRateBinsPerSec=commonRate,CommonHistoryCount=state.commonCross.historyCount, ...
   CrossRateBinsPerSec=d.rateBinsPerSec,CrossHistoryCount=d.historyCount);
 else
  stage=v4Stage55DualBootstrapDecodeV24(frame.observation,common,crossBootstrap,c,lowP,highP, ...
   CommonRateBinsPerSec=commonRate,CommonHistoryCount=state.commonCross.historyCount, ...
   CrossRateBinsPerSec=d.rateBinsPerSec,CrossHistoryCount=d.historyCount);
 end
 regimes(1)=regimes(1)+strcmp(stage.observableRegime,'cross-bootstrap-dual-block');regimes(2)=regimes(2)+strcmp(stage.observableRegime,'common-bootstrap-wide-bank');
 rx={v4HuangStaticDecode(frame.observation,common,c),stage,v4PaperMidambleDecode(frame.observation,common,c,lowP)};
 for r=regions
  counts(:,r)=counts(:,r)+[112;768;768;1];frames(r)=frames(r)+1;
  for method=1:3,m=v4EvaluateFrame(rx{method},frame.truth,c);errors(method,:,r)=errors(method,:,r)+[m.symbolErrors m.hardBitErrors m.softBitErrors m.packetError];end
  mask=stage.virtualPilotAccepted;vp(r)=vp(r)+sum(mask);falseVp(r)=falseVp(r)+sum(mask&stage.tracker.hardPhysicalBins~=frame.truth.payloadPhysicalBins);
 end
end
metrics=zeros(size(errors));for r=1:3,for method=1:3,metrics(method,:,r)=reshape(errors(method,:,r),1,4)./counts(:,r).';end,end
result=struct('status','PASS','passIndex',passIndex,'runSignature',signature,'identity',identity, ...
 'algorithmVersion',algorithmVersion,'validationDomain',domain,'seedRoot',seedRoot, ...
 'ledgerAggregateHash',v4Sha256(strjoin(ledgerHashes,'')),'rawErrors',errors,'denominators',counts, ...
 'metrics',metrics,'vpAccepted',vp,'vpFalseAccepted',falseVp,'frames',frames, ...
 'lowRegimeFrames',regimes(1),'highRegimeFrames',regimes(2),'startedAt',char(started), ...
 'endedAt',char(datetime('now','TimeZone','local')),'wallTimeSec',toc(timer), ...
 'conditionsFrozen',true,'selectionUsesTruth',false);
if ~isfolder(outFolder),mkdir(outFolder),end;save(matPath,'result','-v7.3');write(jsonPath,jsonencode(result,'PrettyPrint',true));
end
function write(path,text),f=fopen(path,'w','n','UTF-8');cl=onCleanup(@()fclose(f));fprintf(f,'%s\n',text);clear cl,end
