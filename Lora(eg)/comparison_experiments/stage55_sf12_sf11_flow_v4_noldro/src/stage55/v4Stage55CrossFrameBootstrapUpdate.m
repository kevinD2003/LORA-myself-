function [stageBootstrap,state,diagnostic]=v4Stage55CrossFrameBootstrapUpdate( ...
        state,rxPilots,commonBootstrap,measurementTimeSec,c,p)
%V4STAGE55CROSSFRAMEBOOTSTRAPUPDATE Receiver-only CFO/rate anchored bootstrap.

rawCfo=mean(commonBootstrap.cfoBins);
rawRate=commonBootstrap.rateBinsPerSec;
if ~isfinite(rawRate),rawRate=0;end
reset=false;
rejected=false;
priorCfo=NaN;
if isempty(fieldnames(state))
    time=measurementTimeSec;
    cfo=rawCfo;
    rate=max(-p.maximumRateBinsPerSec,min(p.maximumRateBinsPerSec,rawRate));
elseif numel(state.timeSec)==1
    dt=measurementTimeSec-state.timeSec(end);
    priorCfo=state.cfoBins(end)+state.rateBinsPerSec*dt;
    limit=max(2,p.rateDeviationLimitBinsPerSec*dt);
    if abs(rawCfo-priorCfo)>limit
        time=measurementTimeSec;
        cfo=rawCfo;
        rate=max(-p.maximumRateBinsPerSec,min(p.maximumRateBinsPerSec,rawRate));
        reset=true;
    else
        time=[state.timeSec(:);measurementTimeSec];
        cfo=[state.cfoBins(:);rawCfo];
        rate=(cfo(end)-cfo(end-1))/(time(end)-time(end-1));
    end
else
    priorCfo=localPredict(state.timeSec,state.cfoBins,measurementTimeSec,p);
    dt=measurementTimeSec-state.timeSec(end);
    limit=max(2,p.rateDeviationLimitBinsPerSec*dt);
    if abs(rawCfo-priorCfo)>limit
        usedCfo=priorCfo;
        rejected=true;
    else
        usedCfo=rawCfo;
    end
    time=[state.timeSec(:);measurementTimeSec];
    cfo=[state.cfoBins(:);usedCfo];
    if numel(time)>c.virtualPilotHistoryLength
        time=time(end-c.virtualPilotHistoryLength+1:end);
        cfo=cfo(end-c.virtualPilotHistoryLength+1:end);
    end
    [anchor,rate]=localFit(time,cfo,measurementTimeSec,p);
    cfo(end)=anchor;
end
rate=max(-p.maximumRateBinsPerSec,min(p.maximumRateBinsPerSec,rate));
if numel(time)>=2
    [anchorCfo,rate]=localFit(time,cfo,measurementTimeSec,p);
else
    anchorCfo=cfo(end);
end
stageBootstrap=localRateAnchoredBootstrap(rxPilots,commonBootstrap,anchorCfo,rate,c);
state=struct('timeSec',time(:),'cfoBins',cfo(:),'rateBinsPerSec',rate, ...
    'historyCount',numel(time),'historyLength',c.virtualPilotHistoryLength, ...
    'usesPayloadTruth',false,'usesOrbitTruth',false);
diagnostic=struct('rawCfoBins',rawCfo,'priorCfoBins',priorCfo, ...
    'anchorCfoBins',anchorCfo,'rateBinsPerSec',rate, ...
    'rawMeasurementRejected',rejected,'historyReset',reset, ...
    'historyCount',numel(time),'usesPayloadTruth',false,'usesOrbitTruth',false);
end

function prediction=localPredict(time,cfo,target,p)
[prediction,~]=localFit(time,cfo,target,p);
end

function [center,rate]=localFit(time,cfo,target,p)
x=time(:)-target;
if numel(time)==2
    design=[ones(size(x)) x];
else
    design=[ones(size(x)) x 0.5*x.^2];
end
age=(numel(time)-1:-1:0).';
base=p.historyDecay.^age;
weight=base;
beta=(design.*sqrt(weight))\(cfo(:).*sqrt(weight));
for k=1:2
    residual=cfo(:)-design*beta;
    weight=base.*min(1,p.huberThresholdBins./max(abs(residual),eps));
    beta=(design.*sqrt(weight))\(cfo(:).*sqrt(weight));
end
center=beta(1);
rate=beta(2);
end

function b=localRateAnchoredBootstrap(rxPilots,common,anchorCfo,rate,c)
m=c.samplesPerSymbol;
pilotCount=c.bootstrapPilotCount;
down=conj(v4ModulateSymbol(0,c));
coherent=complex(zeros(pilotCount,1));
for k=1:pilotCount
    globalSample=(k-1)*m+(0:m-1);
    coherent(k)=mean(rxPilots(k,:).*down.* ...
        exp(-1i*2*pi*anchorCfo*globalSample/m));
end
x=(0:pilotCount-1).'+0.5;
ratePerSymbol=rate*c.symbolDurationSec;
y=unwrap(angle(coherent))/(2*pi)-0.5*ratePerSymbol*x.^2;
design=[ones(pilotCount,1) x];
weight=max(abs(coherent).^2,eps);
beta2=(design.*sqrt(weight))\(y.*sqrt(weight));
beta=[beta2(1);beta2(2);ratePerSymbol];
centerCfo=anchorCfo+beta(2)+ratePerSymbol*x;
symbolStart=(0:pilotCount-1).';
phaseStart=angle(exp(1i*2*pi*(beta(1)+beta(2)*symbolStart+ ...
    0.5*ratePerSymbol*symbolStart.^2)));
joint=common.joint;
joint.coarseCfoBins=anchorCfo;
joint.centerCfoBins=centerCfo;
joint.rateBinsPerSec=rate;
joint.startPhaseRad=phaseStart;
joint.coherentPilotPhasor=coherent;
joint.unwrappedPhaseRad=unwrap(angle(coherent));
joint.betaCycles=beta;
b=common;
b.coarseCfoBins=anchorCfo;
b.epsilonHatBins=anchorCfo;
b.cfoBins=centerCfo;
b.phaseRad=phaseStart;
b.rateBinsPerSec=rate;
b.jointRateBinsPerSec=rate;
b.joint=joint;
b.source='Stage55 receiver-only cross-frame CFO/rate anchored bootstrap';
b.usesPayloadTruth=false;
b.usesOrbitTruth=false;
end
