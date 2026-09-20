function artifact=aggregateV4BNativeValidationV30()
root=v4SetupPaths();folder=fullfile(root,'results','validation','track_b','native_awgn','Stage55-B-v30','passes');
errors=zeros(3,4,3);den=zeros(3,4,3);vp=zeros(3,1);falseVp=zeros(3,1);sent=zeros(3,1);available=zeros(3,1);geometry=zeros(3,1);goodput=zeros(3,20);sig=cell(20,1);led=cell(20,1);wall=zeros(20,1);
for i=1:20,x=load(fullfile(folder,sprintf('pass_%02d.mat',i)),'result');r=x.result;errors=errors+r.rawErrors;den=den+r.denominators;vp=vp+r.vpAccepted;falseVp=falseVp+r.vpFalseAccepted;sent=sent+r.sentFrames;available=available+r.availableFrames;geometry=geometry+r.geometryErasures;goodput(:,i)=r.goodputBps;sig{i}=r.runSignature;led{i}=r.ledgerAggregateHash;wall(i)=r.wallTimeSec;end
metrics=errors./den;fa=falseVp./vp;coverage=vp./squeeze(den(2,1,:));quality=all(fa(1:2)<=.02&coverage(1:2)>=.01&vp(1:2)>=200);delta=[metrics(2,1,3)-metrics(3,1,3),metrics(2,2,3)-metrics(3,2,3),metrics(2,3,3)-metrics(3,3,3)];performance=all(delta<0);uniqueOk=numel(unique(sig))==20&&numel(unique(led))==20;systemPer=(geometry+squeeze(errors(:,4,3)))./sent;passed=quality&&performance&&uniqueOk;
artifact=struct('status',ternary(passed,'PASS','FAIL'),'passes',20,'algorithmVersion','Stage55-B-startup-observability-v30','validationDomain','b_native_validation_v30', ...
 'rawErrors',errors,'denominators',den,'metrics',metrics,'vpAccepted',vp,'vpFalseAccepted',falseVp,'vpFalseAcceptance',fa,'vpCoverage',coverage, ...
 'qualityGatePassed',quality,'stageMinusPaper',delta,'performanceTargetMet',performance,'sentFrames',sent,'availableFrames',available, ...
 'geometryErasures',geometry,'systemPerMl',systemPer,'meanGoodputBps',mean(goodput,2),'uniqueSignaturesAndLedgers',uniqueOk, ...
 'meanPassWallTimeSec',mean(wall),'p95PassWallTimeSec',prctile(wall,95),'conditionsFrozen',true,'rawSamplesClaimedPairedAcrossMethods',false);
out=fileparts(folder);save(fullfile(out,'validation.mat'),'artifact','-v7.3');write(fullfile(out,'validation.json'),jsonencode(artifact,'PrettyPrint',true));if ~passed,error('V4:NativeV30','native v30 gate failed.');end
end
function x=ternary(ok,a,b),if ok,x=a;else,x=b;end,end
function write(path,text),f=fopen(path,'w','n','UTF-8');cl=onCleanup(@()fclose(f));fprintf(f,'%s\n',text);clear cl,end
