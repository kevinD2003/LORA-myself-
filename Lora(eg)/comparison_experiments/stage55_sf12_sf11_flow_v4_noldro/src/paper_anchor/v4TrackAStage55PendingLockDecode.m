function result=v4TrackAStage55PendingLockDecode(packet,config,parameters,options)
%V4TRACKASTAGE55PENDINGLOCKDECODE R4 causal pending/locked/lost receiver.
arguments
    packet (1,1) struct
    config (1,1) struct
    parameters (1,1) struct
    options.ProcessingDelaySec (1,1) double {mustBeNonnegative}=0
    options.StopAfterPhysicalRow (1,1) double=Inf
    options.ResumeState (1,1) struct=struct()
end
s=packet.schedule; m=config.samplesPerSymbol;
if isempty(fieldnames(options.ResumeState))
    point=localSamples(packet.rx,s,s.pointDownRow);
    initial=v4PaperNativePointEstimate(point,config);
    state=localInitialState(initial,s);
else
    state=options.ResumeState;
    initial=state.initialPoint;
end
lastRow=min(numel(s.kind),options.StopAfterPhysicalRow);
for row=state.nextPhysicalRow:lastRow
    samples=localSamples(packet.rx,s,row).';
    duration=numel(samples)/config.sampleRateHz;
    centerCfo=state.cfoAtStartBins+state.rateBinsPerSec*duration/2;
    compensated=localCompensate(samples,state.ncoPhaseRad,centerCfo, ...
        state.rateBinsPerSec,config);
    oldCfo=state.cfoAtStartBins; oldRate=state.rateBinsPerSec;
    if s.kind(row)=="data"
        data=s.dataIndex(row); centerTime=s.centerTimeOffsetSec(row);
        available=(s.startSample(row)+s.sampleCount(row))/config.sampleRateHz;
        likelihood=v4SymbolLikelihood(compensated,config,packet.noiseVariance);
        residual=v4PhaseRotationEstimate(compensated,likelihood.physicalBin,config, ...
            (-1:parameters.residualStepBins:1).');
        candidate=v4TrackACandidate(data,row,centerTime,available,centerCfo, ...
            likelihood,residual,parameters);
        state.detectedPhysicalBins(data)=likelihood.physicalBin;
        state.estimatedCfoBins(data)=centerCfo;
        state.candidateRecords{data}=candidate;
        if strcmp(state.lockState,'PENDING_BOOTSTRAP')
            state=localPendingStep(state,candidate,row,available,s,parameters,options.ProcessingDelaySec);
        elseif strcmp(state.lockState,'LOCKED')
            state=localLockedStep(state,candidate,row,available,s,parameters,options.ProcessingDelaySec);
        else
            candidate.status='REJECTED';candidate.rejectionReason='receiver-lost';
            state.candidateRecords{data}=candidate;
            state.rejectedVpCount=state.rejectedVpCount+1;
        end
    end
    phaseCycles=oldCfo*duration/config.symbolDurationSec+ ...
        0.5*oldRate*duration^2/config.symbolDurationSec;
    state.ncoPhaseRad=mod(state.ncoPhaseRad+2*pi*phaseCycles,2*pi);
    if state.stateUpdatedAtRow~=row
        state.cfoAtStartBins=oldCfo+oldRate*duration;
    end
    state.nextPhysicalRow=row+1;
end
result=localResult(state,initial,lastRow>=numel(s.kind));
end

function state=localInitialState(initial,s)
state=struct('algorithmVersion','Stage55-A-causal-pending-lock-v1', ...
    'lockState','PENDING_BOOTSTRAP','pendingCandidates',repmat(localEmptyCandidate(),0,1), ...
    'committedHistory',repmat(localEmptyCandidate(),0,1),'commitRecords',repmat(localEmptyCommit(),0,1), ...
    'consecutiveRejectedDataSymbols',0,'lossReason','','lossTimeSec',NaN, ...
    'ncoPhaseRad',0,'cfoAtStartBins',initial.offsetBins,'rateBinsPerSec',0, ...
    'nextPhysicalRow',s.quarterDownRow,'stateUpdatedAtRow',NaN,'transactionCount',0, ...
    'detectedPhysicalBins',nan(23,1),'estimatedCfoBins',nan(23,1), ...
    'candidateRecords',{cell(23,1)},'virtualPilotAccepted',false(23,1), ...
    'vpUsedLabel',nan(23,1),'releaseAtSec',nan(23,1), ...
    'firstEffectiveTimeSec',nan(23,1),'firstEffectivePhysicalRow',nan(23,1), ...
    'expiredVpCount',0,'rejectedVpCount',0,'initialPoint',initial);
end

function state=localPendingStep(state,candidate,row,available,s,p,delay)
if candidate.qualityPassed
    state.pendingCandidates(end+1,1)=candidate;
else
    candidate.status='REJECTED';candidate.rejectionReason='single-symbol-quality';
    state.candidateRecords{candidate.dataIndex}=candidate;
    state.rejectedVpCount=state.rejectedVpCount+1;
end
if ~isempty(state.pendingCandidates)
    expired=[state.pendingCandidates.dataIndex] < candidate.dataIndex-p.pendingWindowDataSymbols+1;
    for index=find(expired)
        id=state.pendingCandidates(index).dataIndex;
        old=state.candidateRecords{id};old.status='EXPIRED';old.rejectionReason='pending-window-expired';
        state.candidateRecords{id}=old;state.expiredVpCount=state.expiredVpCount+1;
    end
    state.pendingCandidates=state.pendingCandidates(~expired);
end
decision=v4TrackABranchConsistency(state.pendingCandidates,p,available);
if decision.release
    selected=state.pendingCandidates(decision.indices);
    state.transactionCount=state.transactionCount+1;
    release=available+delay; [effectiveRow,effectiveTime]=localFirstEffective(row,release,s);
    for index=1:numel(selected)
        state=localRecordCommit(state,selected(index),release,effectiveRow,effectiveTime);
    end
    state.committedHistory=selected;
    fit=v4TrackACommittedHistoryFit(state.committedHistory,available,p);
    state.cfoAtStartBins=fit.cfoBins;state.rateBinsPerSec=fit.rateBinsPerSec;
    state.lockState='LOCKED';state.pendingCandidates=repmat(localEmptyCandidate(),0,1);
    state.consecutiveRejectedDataSymbols=0;state.stateUpdatedAtRow=row;
elseif decision.ambiguous
    candidate=state.candidateRecords{candidate.dataIndex};candidate.rejectionReason='ambiguous-pairs-pending';
    state.candidateRecords{candidate.dataIndex}=candidate;
end
end

function state=localLockedStep(state,candidate,row,available,s,p,delay)
committed=false; visibleConflict=abs(candidate.cfoCandidateBins-candidate.predictedCfoBins)>=0.5;
if candidate.qualityPassed
    proposed=[state.committedHistory;candidate];
    if numel(proposed)>p.historyLength,proposed=proposed(end-p.historyLength+1:end);end
    fit=v4TrackACommittedHistoryFit(proposed,available,p);
    if fit.withinRateBound && fit.withinResidualBound
        release=available+delay;[effectiveRow,effectiveTime]=localFirstEffective(row,release,s);
        state.transactionCount=state.transactionCount+1;
        state=localRecordCommit(state,candidate,release,effectiveRow,effectiveTime);
        state.committedHistory=proposed;state.cfoAtStartBins=fit.cfoBins;
        state.rateBinsPerSec=fit.rateBinsPerSec;state.stateUpdatedAtRow=row;
        state.consecutiveRejectedDataSymbols=0;committed=true;
    end
end
if committed,return,end
candidate=state.candidateRecords{candidate.dataIndex};candidate.status='REJECTED';
if visibleConflict
    candidate.rejectionReason='integer-branch-conflict';state.lockState='LOST';
    state.lossReason='integer-branch-conflict';state.lossTimeSec=available;
else
    candidate.rejectionReason='locked-gate-rejection';
    state.consecutiveRejectedDataSymbols=state.consecutiveRejectedDataSymbols+1;
    if state.consecutiveRejectedDataSymbols>=p.lostAfterRejectedData
        state.lockState='LOST';state.lossReason='three-consecutive-rejections';state.lossTimeSec=available;
    end
end
state.candidateRecords{candidate.dataIndex}=candidate;state.rejectedVpCount=state.rejectedVpCount+1;
end

function state=localRecordCommit(state,candidate,release,effectiveRow,effectiveTime)
id=candidate.dataIndex;candidate.status='COMMITTED';candidate.rejectionReason='';
state.candidateRecords{id}=candidate;state.virtualPilotAccepted(id)=true;
state.vpUsedLabel(id)=candidate.hardLabel;state.releaseAtSec(id)=release;
state.firstEffectiveTimeSec(id)=effectiveTime;state.firstEffectivePhysicalRow(id)=effectiveRow;
record=localEmptyCommit();record.candidateId=id;record.committedHardLabel=candidate.hardLabel;
record.measurementTimeSec=candidate.measurementTimeSec;record.releaseAtSec=release;
record.firstEffectiveTimeSec=effectiveTime;record.firstEffectivePhysicalRow=effectiveRow;
record.transactionId=state.transactionCount;state.commitRecords(end+1,1)=record;
end
function [row,time]=localFirstEffective(currentRow,release,s)
indices=(currentRow+1:numel(s.kind)).';
eligible=indices(s.startSample(indices)/125000>=release-1e-12);
if isempty(eligible),row=NaN;time=NaN;else,row=eligible(1);time=s.startSample(row)/125000;end
end
function result=localResult(state,initial,complete)
result=struct('methodName','Stage55-VP-quality-SER-SF12-noLDRO', ...
    'algorithmVersion',state.algorithmVersion,'detectedPhysicalBins',state.detectedPhysicalBins, ...
    'estimatedCfoBins',state.estimatedCfoBins,'virtualPilotAccepted',state.virtualPilotAccepted, ...
    'vpUsedLabel',state.vpUsedLabel,'releaseAtSec',state.releaseAtSec, ...
    'firstEffectiveTimeSec',state.firstEffectiveTimeSec, ...
    'pilotAppliedAtPhysicalRow',state.firstEffectivePhysicalRow, ...
    'candidateRecords',{state.candidateRecords},'commitRecords',state.commitRecords, ...
    'finalLockState',state.lockState,'lossReason',state.lossReason,'lossTimeSec',state.lossTimeSec, ...
    'committedVpCount',sum(state.virtualPilotAccepted),'expiredVpCount',state.expiredVpCount, ...
    'rejectedVpCount',state.rejectedVpCount,'initialPoint',initial, ...
    'usesHamming',false,'usesPhasePair',false,'usesMidambleObservation',false, ...
    'usesTruth',false,'complete',complete,'checkpointState',state);
end
function x=localEmptyCandidate()
x=struct('candidateId',0,'dataIndex',0,'physicalRow',0,'hardLabel',NaN, ...
    'measurementTimeSec',NaN,'decisionAtSec',NaN,'availableAtSec',NaN, ...
    'cfoCandidateBins',NaN,'predictedCfoBins',NaN,'peakRatio',NaN, ...
    'entropyNormalized',NaN,'residualPeakRatio',NaN,'innovationBins',NaN, ...
    'qualityPassed',false,'status','','rejectionReason','');
end
function x=localEmptyCommit()
x=struct('candidateId',0,'committedHardLabel',NaN,'measurementTimeSec',NaN, ...
    'releaseAtSec',NaN,'firstEffectiveTimeSec',NaN,'firstEffectivePhysicalRow',NaN, ...
    'transactionId',0);
end
function y=localCompensate(rx,phase,cfoCenter,rate,config)
n=0:numel(rx)-1;t=n/config.sampleRateHz;duration=numel(rx)/config.sampleRateHz;
startCfo=cfoCenter-rate*duration/2;cycles=startCfo*t/config.symbolDurationSec+ ...
    0.5*rate*t.^2/config.symbolDurationSec;y=rx.*exp(-1i*(phase+2*pi*cycles));
end
function samples=localSamples(serial,schedule,row)
first=schedule.startSample(row)+1;samples=serial(first:first+schedule.sampleCount(row)-1);
end
