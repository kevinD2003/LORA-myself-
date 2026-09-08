function [state,records] = v4AdvanceFrameSequence(state,count,config,snrDb,scope,snrIndex,passIndex,parameters)
%V4ADVANCEFRAMESEQUENCE Deterministic frame advancement for resume tests.

records = repmat(struct('frameIndex',0,'fingerprint',zeros(1,3), ...
    'ledger',struct(),'crossFrameHistoryCount',0),count,1);
for item = 1:count
    frameIndex = state.nextFrameIndex;
    ledger = v4RandomLedger(config,scope,snrIndex,passIndex,frameIndex);
    frame = v4GenerateContinuousFrame(config,state.nextFrameStartTimeSec, ...
        snrDb,ledger,state.nextFrameStartPhaseRad);
    bootstrap = v4CommonBootstrap(frame.observation.rxPhysical(1:8,:),config, ...
        SearchStepBins=parameters.searchStepBins);
    measurementTime = state.nextFrameStartTimeSec+4*config.symbolDurationSec;
    [~,state.crossFrameRateState] = v4CrossFrameRateUpdate( ...
        state.crossFrameRateState,measurementTime,mean(bootstrap.cfoBins), ...
        bootstrap.rateBinsPerSec,config,parameters);
    records(item).frameIndex = frameIndex;
    records(item).fingerprint = frame.observation.sampleFingerprint;
    records(item).ledger = ledger;
    records(item).crossFrameHistoryCount = state.crossFrameRateState.historyCount;
    state.nextFrameIndex = frameIndex+1;
    state.nextFrameStartTimeSec = frame.nextFrameStartTimeSec;
    state.nextFrameStartPhaseRad = frame.nextFrameStartPhaseRad;
end
end

