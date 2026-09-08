function result=v4TrackAStage55PointAnchoredDecode(packet,config,parameters,options)
%V4TRACKASTAGE55POINTANCHOREDDECODE R5 D1-only provisional lock receiver.
arguments
    packet (1,1) struct
    config (1,1) struct
    parameters (1,1) struct
    options.ProcessingDelaySec (1,1) double {mustBeNonnegative}=0
    options.StopAfterPhysicalRow (1,1) double=Inf
    options.ResumeState (1,1) struct=struct()
end
s=packet.schedule;
if isempty(fieldnames(options.ResumeState))
    state=localInitial(v4TrackAPointAnchor(packet,config),s);
else
    state=options.ResumeState;
end
lastRow=min(numel(s.kind),options.StopAfterPhysicalRow);
for row=state.nextPhysicalRow:lastRow
    if state.pendingDynamicUpdate.active&&state.pendingDynamicUpdate.physicalRow==row
        state.cfoAtStartBins=state.pendingDynamicUpdate.cfoAtEffectiveBins;
        state.rateBinsPerSec=state.pendingDynamicUpdate.rateBinsPerSec;
        state.pendingDynamicUpdate=localEmptyUpdate();
    end
    samples=localSamples(packet.rx,s,row).';duration=numel(samples)/config.sampleRateHz;
    centerCfo=state.cfoAtStartBins+state.rateBinsPerSec*duration/2;
    compensated=localCompensate(samples,state.ncoPhaseRad,centerCfo,state.rateBinsPerSec,config);
    oldCfo=state.cfoAtStartBins;oldRate=state.rateBinsPerSec;
    if s.kind(row)=="data"
        data=s.dataIndex(row);centerTime=s.centerTimeOffsetSec(row);
        available=(s.startSample(row)+s.sampleCount(row))/config.sampleRateHz;
        likelihood=v4SymbolLikelihood(compensated,config,packet.noiseVariance);
        state.detectedPhysicalBins(data)=likelihood.physicalBin;state.estimatedCfoBins(data)=centerCfo;
        if strcmp(state.lockState,'LOST')
            candidate=localEmptyCandidate();candidate.candidateId=data;candidate.dataIndex=data;
            candidate.hardLabel=likelihood.physicalBin;candidate.status='NOT_EVALUATED';
            candidate.rejectionReason='receiver-lost';state.candidateRecords{data}=candidate;
        else
            residual=v4PhaseRotationEstimate(compensated,likelihood.physicalBin,config, ...
                (-1:parameters.residualStepBins:1).');
            candidate=v4TrackACandidate(data,row,centerTime,available,centerCfo,likelihood,residual,parameters);
            state.candidateRecords{data}=candidate;
            if data==1&&strcmp(state.lockState,'POINT_ANCHORED_PENDING')
                state=localD1(state,candidate,row,available,s,parameters,options.ProcessingDelaySec);
            elseif data==2&&strcmp(state.lockState,'PROVISIONAL')
                state=localD2(state,candidate,row,available,s,parameters,options.ProcessingDelaySec);
            elseif strcmp(state.lockState,'LOCKED')
                state=localLocked(state,candidate,row,available,s,parameters,options.ProcessingDelaySec);
            else
                candidate.status='REJECTED';candidate.rejectionReason='startup-window-closed';
                state.candidateRecords{data}=candidate;state=localLose(state,'startup-window-closed',available);
            end
        end
        state.lockStateByData{data}=state.lockState;
    end
    phaseCycles=oldCfo*duration/config.symbolDurationSec+0.5*oldRate*duration^2/config.symbolDurationSec;
    state.ncoPhaseRad=mod(state.ncoPhaseRad+2*pi*phaseCycles,2*pi);
    state.cfoAtStartBins=oldCfo+oldRate*duration;state.nextPhysicalRow=row+1;
end
result=localResult(state,lastRow>=numel(s.kind));
end

function state=localD1(state,c,row,available,s,p,delay)
provisional=v4TrackAProvisionalRate(state.pointAnchor,c,p);
if c.qualityPassed&&provisional.finite&&provisional.withinBound
    state.provisionalRateBinsPerSec=provisional.rateBinsPerSec;
    state.provisionalCandidate=c;state.transactionCount=state.transactionCount+1;
    [state,effectiveRow,effectiveTime]=localCommit(state,c,available+delay,row,s);
    cfoAtAvailable=c.cfoCandidateBins+provisional.rateBinsPerSec* ...
        (available-c.measurementTimeSec);
    state.pendingDynamicUpdate=localUpdate(effectiveRow,effectiveTime,cfoAtAvailable, ...
        available,provisional.rateBinsPerSec);
    state.lockState='PROVISIONAL';
else
    c.status='REJECTED';c.rejectionReason='d1-startup-gate';state.candidateRecords{1}=c;
    state=localLose(state,'d1-startup-gate',available);
end
end

function state=localD2(state,c,row,available,s,p,delay)
d1=state.provisionalCandidate;
expected=d1.cfoCandidateBins+state.provisionalRateBinsPerSec* ...
    (c.measurementTimeSec-d1.measurementTimeSec);
confirmation=abs(c.cfoCandidateBins-expected);
rate=(c.cfoCandidateBins-d1.cfoCandidateBins)/(c.measurementTimeSec-d1.measurementTimeSec);
if c.qualityPassed&&confirmation<=p.confirmationResidualLimitBins&& ...
        isfinite(rate)&&abs(rate)<=p.maximumRateBinsPerSec
    state.transactionCount=state.transactionCount+1;[state,effectiveRow,effectiveTime]= ...
        localCommit(state,c,available+delay,row,s);
    state.committedHistory=[d1;c];state.lockState='LOCKED';
    state.consecutiveRejectedDataSymbols=0;
    cfoAtAvailable=c.cfoCandidateBins+rate*(available-c.measurementTimeSec);
    state.pendingDynamicUpdate=localUpdate(effectiveRow,effectiveTime,cfoAtAvailable,available,rate);
else
    c.status='REJECTED';c.rejectionReason='d2-confirmation-gate';state.candidateRecords{2}=c;
    state=localLose(state,'d2-confirmation-gate',available);
end
end

function state=localLocked(state,c,row,available,s,p,delay)
accepted=false;
if c.qualityPassed
    proposed=[state.committedHistory;c];if numel(proposed)>p.historyLength,proposed=proposed(end-p.historyLength+1:end);end
    fit=v4TrackACommittedHistoryFit(proposed,available,p);
    if fit.withinRateBound&&fit.withinResidualBound
        state.transactionCount=state.transactionCount+1;[state,effectiveRow,effectiveTime]= ...
            localCommit(state,c,available+delay,row,s);
        state.committedHistory=proposed;state.consecutiveRejectedDataSymbols=0;
        state.pendingDynamicUpdate=localUpdate(effectiveRow,effectiveTime,fit.cfoBins,available,fit.rateBinsPerSec);
        accepted=true;
    end
end
if accepted,return,end
c=state.candidateRecords{c.dataIndex};c.status='REJECTED';c.rejectionReason='locked-gate';
state.candidateRecords{c.dataIndex}=c;state.rejectedVpCount=state.rejectedVpCount+1;
state.consecutiveRejectedDataSymbols=state.consecutiveRejectedDataSymbols+1;
if ~isfinite(c.cfoCandidateBins)||abs(c.cfoCandidateBins-c.predictedCfoBins)>=0.5
    state=localLose(state,'integer-branch-conflict',available);
elseif state.consecutiveRejectedDataSymbols>=p.lostAfterRejectedData
    state=localLose(state,'three-consecutive-rejections',available);
end
end

function [state,row,time]=localCommit(state,c,release,currentRow,s)
[row,time]=localFirstEffective(currentRow,release,s);id=c.dataIndex;c.status='COMMITTED';c.rejectionReason='';
state.candidateRecords{id}=c;state.virtualPilotAccepted(id)=true;state.vpUsedLabel(id)=c.hardLabel;
state.releaseAtSec(id)=release;state.firstEffectiveTimeSec(id)=time;state.firstEffectivePhysicalRow(id)=row;
r=localEmptyCommit();r.candidateId=id;r.committedHardLabel=c.hardLabel;r.measurementTimeSec=c.measurementTimeSec;
r.releaseAtSec=release;r.firstEffectiveTimeSec=time;r.firstEffectivePhysicalRow=row;r.transactionId=state.transactionCount;
state.commitRecords(end+1,1)=r;
end
function state=localLose(state,reason,time)
state.lockState='LOST';state.lossReason=reason;state.lossTimeSec=time;state.pendingDynamicUpdate=localEmptyUpdate();
end
function state=localInitial(anchor,s)
state=struct('algorithmVersion','Stage55-A-point-anchored-provisional-lock-v2', ...
    'pointAnchor',anchor,'lockState','POINT_ANCHORED_PENDING','lockStateByData',{cell(23,1)}, ...
    'provisionalRateBinsPerSec',NaN,'provisionalCandidate',localEmptyCandidate(), ...
    'committedHistory',repmat(localEmptyCandidate(),0,1),'commitRecords',repmat(localEmptyCommit(),0,1), ...
    'consecutiveRejectedDataSymbols',0,'lossReason','','lossTimeSec',NaN, ...
    'ncoPhaseRad',0,'cfoAtStartBins',anchor.cfoBins,'rateBinsPerSec',0, ...
    'pendingDynamicUpdate',localEmptyUpdate(),'nextPhysicalRow',s.quarterDownRow,'transactionCount',0, ...
    'detectedPhysicalBins',nan(23,1),'estimatedCfoBins',nan(23,1), ...
    'candidateRecords',{cell(23,1)},'virtualPilotAccepted',false(23,1), ...
    'vpUsedLabel',nan(23,1),'releaseAtSec',nan(23,1),'firstEffectiveTimeSec',nan(23,1), ...
    'firstEffectivePhysicalRow',nan(23,1),'rejectedVpCount',0);
end
function u=localUpdate(row,time,cfoAtReference,referenceTime,rate)
u=localEmptyUpdate();u.active=isfinite(row);u.physicalRow=row;u.rateBinsPerSec=rate;
if u.active,u.cfoAtEffectiveBins=cfoAtReference+rate*(time-referenceTime);end
end
function u=localEmptyUpdate(),u=struct('active',false,'physicalRow',NaN,'cfoAtEffectiveBins',NaN,'rateBinsPerSec',NaN);end
function [row,time]=localFirstEffective(currentRow,release,s)
indices=(currentRow+1:numel(s.kind)).';starts=s.startSample(indices)/125000;eligible=indices(starts>=release-1e-12);
if isempty(eligible),row=NaN;time=NaN;else,row=eligible(1);time=s.startSample(row)/125000;end
end
function result=localResult(state,complete)
result=struct('methodName','Stage55-VP-quality-SER-SF12-noLDRO', ...
    'algorithmVersion',state.algorithmVersion,'pointAnchor',state.pointAnchor, ...
    'lockStateByData',{state.lockStateByData},'provisionalRateBinsPerSec',state.provisionalRateBinsPerSec, ...
    'detectedPhysicalBins',state.detectedPhysicalBins,'estimatedCfoBins',state.estimatedCfoBins, ...
    'candidateRecords',{state.candidateRecords},'commitRecords',state.commitRecords, ...
    'virtualPilotAccepted',state.virtualPilotAccepted,'vpUsedLabel',state.vpUsedLabel, ...
    'releaseAtSec',state.releaseAtSec,'firstEffectiveTimeSec',state.firstEffectiveTimeSec, ...
    'pilotAppliedAtPhysicalRow',state.firstEffectivePhysicalRow,'finalLockState',state.lockState, ...
    'lossReason',state.lossReason,'lossTimeSec',state.lossTimeSec, ...
    'committedVpCount',sum(state.virtualPilotAccepted),'usesHamming',false, ...
    'usesPhasePair',false,'usesMidambleObservation',false,'usesTruth',false, ...
    'complete',complete,'checkpointState',state);
end
function x=localEmptyCandidate()
x=struct('candidateId',0,'dataIndex',0,'physicalRow',0,'hardLabel',NaN,'measurementTimeSec',NaN, ...
    'decisionAtSec',NaN,'availableAtSec',NaN,'cfoCandidateBins',NaN,'predictedCfoBins',NaN, ...
    'peakRatio',NaN,'entropyNormalized',NaN,'residualPeakRatio',NaN,'innovationBins',NaN, ...
    'qualityPassed',false,'status','','rejectionReason','');
end
function x=localEmptyCommit(),x=struct('candidateId',0,'committedHardLabel',NaN,'measurementTimeSec',NaN,'releaseAtSec',NaN,'firstEffectiveTimeSec',NaN,'firstEffectivePhysicalRow',NaN,'transactionId',0);end
function y=localCompensate(rx,phase,cfoCenter,rate,c)
n=0:numel(rx)-1;t=n/c.sampleRateHz;duration=numel(rx)/c.sampleRateHz;start=cfoCenter-rate*duration/2;
y=rx.*exp(-1i*(phase+2*pi*(start*t/c.symbolDurationSec+0.5*rate*t.^2/c.symbolDurationSec)));
end
function x=localSamples(serial,s,row),first=s.startSample(row)+1;x=serial(first:first+s.sampleCount(row)-1);end
