function [records,diagnostic] = v4RunCompletePass(config,parameters,schedule,snrDb,snrIndex,passIndex)
%V4RUNCOMPLETEPASS Run one complete paired formal pass.

eligibleCount = sum(schedule.metricEligible);
recordCount = eligibleCount*3;
methodName = strings(recordCount,1);
frameIndexColumn = zeros(recordCount,1);
frameCenterTimeSec = zeros(recordCount,1);
region = strings(recordCount,1);
symbolErrors = zeros(recordCount,1);
symbolCount = zeros(recordCount,1);
hardBitErrors = zeros(recordCount,1);
hardBitCount = zeros(recordCount,1);
softBitErrors = zeros(recordCount,1);
softBitCount = zeros(recordCount,1);
packetError = zeros(recordCount,1);
cfoSquaredErrorSum = zeros(recordCount,1);
vpAccepted = zeros(recordCount,1);
vpFalseAccepted = zeros(recordCount,1);
firstVpEffectivePhysicalRow = nan(recordCount,1);
fftCount = zeros(recordCount,1);
runtimeSec = zeros(recordCount,1);
deadlineMiss = false(recordCount,1);
fingerprintEnergy = zeros(recordCount,1);
fingerprintReal = zeros(recordCount,1);
fingerprintImag = zeros(recordCount,1);
payloadSeed = zeros(recordCount,1);
noiseSeed = zeros(recordCount,1);
channelSeed = zeros(recordCount,1);
crossFrameHistoryCount = zeros(recordCount,1);
passIndexColumn = repmat(passIndex,recordCount,1);
snrDbColumn = repmat(snrDb,recordCount,1);

trajectory = v4Trajectory(schedule.frameCenterTimeSec,config);
rateBinsPerSec = trajectory.dopplerRateHzPerSec/config.fftBinSpacingHz;
regionThreshold = median(abs(rateBinsPerSec(schedule.metricEligible)));
state = struct('nextFrameStartTimeSec',schedule.passStartTimeSec, ...
    'nextFrameStartPhaseRad',0,'crossFrameRateState',struct());
outputRow = 0;
symbolCfoSquaredErrorSum = zeros(3,2,config.payloadSymbolCount);
symbolCfoObservationCount = zeros(3,2);
for frameIndex = 1:schedule.frameCount
    ledger = v4RandomLedger(config,'formal',snrIndex,passIndex,frameIndex);
    frame = v4GenerateContinuousFrame(config,state.nextFrameStartTimeSec, ...
        snrDb,ledger,state.nextFrameStartPhaseRad);
    state.nextFrameStartTimeSec = frame.nextFrameStartTimeSec;
    state.nextFrameStartPhaseRad = frame.nextFrameStartPhaseRad;
    if ~schedule.metricEligible(frameIndex)
        continue
    end
    bootstrap = v4CommonBootstrap(frame.observation.rxPhysical(1:8,:),config, ...
        SearchStepBins=parameters.searchStepBins);
    measurementTime = schedule.frameStartTimeSec(frameIndex)+ ...
        4*config.symbolDurationSec;
    [crossRate,state.crossFrameRateState] = v4CrossFrameRateUpdate( ...
        state.crossFrameRateState,measurementTime,mean(bootstrap.cfoBins), ...
        bootstrap.rateBinsPerSec,config,parameters);
    receivers = cell(3,1);
    timers = zeros(3,1);
    start = tic;
    receivers{1} = v4HuangStaticDecode(frame.observation,bootstrap,config);
    timers(1) = toc(start);
    start = tic;
    receivers{2} = v4Stage55Decode(frame.observation,bootstrap,config,parameters, ...
        CrossFrameRateBinsPerSec=crossRate, ...
        CrossFrameHistoryCount=state.crossFrameRateState.historyCount);
    timers(2) = toc(start);
    start = tic;
    receivers{3} = v4PaperMidambleDecode(frame.observation,bootstrap,config,parameters);
    timers(3) = toc(start);
    if abs(rateBinsPerSec(frameIndex)) >= regionThreshold
        frameRegion = "high-dynamic";
    else
        frameRegion = "low-dynamic";
    end
    for method = 1:3
        outputRow = outputRow+1;
        metrics = v4EvaluateFrame(receivers{method},frame.truth,config);
        methodName(outputRow) = string(metrics.methodName);
        frameIndexColumn(outputRow) = frameIndex;
        frameCenterTimeSec(outputRow) = schedule.frameCenterTimeSec(frameIndex);
        region(outputRow) = frameRegion;
        symbolErrors(outputRow) = metrics.symbolErrors;
        symbolCount(outputRow) = metrics.symbolCount;
        hardBitErrors(outputRow) = metrics.hardBitErrors;
        hardBitCount(outputRow) = metrics.hardBitCount;
        softBitErrors(outputRow) = metrics.softBitErrors;
        softBitCount(outputRow) = metrics.softBitCount;
        packetError(outputRow) = metrics.packetError;
        cfoSquaredErrorSum(outputRow) = metrics.cfoSquaredErrorSum;
        cfoError = receivers{method}.estimatedCfoBins-frame.truth.dataCfoBins;
        if frameRegion == "low-dynamic", regionIndex = 1; else, regionIndex = 2; end
        currentCfoSum = squeeze(symbolCfoSquaredErrorSum(method,regionIndex,:));
        symbolCfoSquaredErrorSum(method,regionIndex,:) = ...
            reshape(currentCfoSum+cfoError.^2,1,1,[]);
        symbolCfoObservationCount(method,regionIndex) = ...
            symbolCfoObservationCount(method,regionIndex)+1;
        fftCount(outputRow) = metrics.fftCount;
        runtimeSec(outputRow) = timers(method);
        deadlineMiss(outputRow) = timers(method) > schedule.frameDurationSec;
        fingerprintEnergy(outputRow) = frame.observation.sampleFingerprint(1);
        fingerprintReal(outputRow) = frame.observation.sampleFingerprint(2);
        fingerprintImag(outputRow) = frame.observation.sampleFingerprint(3);
        payloadSeed(outputRow) = ledger.payloadSeed;
        noiseSeed(outputRow) = ledger.noiseSeed;
        channelSeed(outputRow) = ledger.channelSeed;
        crossFrameHistoryCount(outputRow) = state.crossFrameRateState.historyCount;
        if method == 2
            accepted = receivers{2}.virtualPilotAccepted;
            vpAccepted(outputRow) = sum(accepted);
            vpFalseAccepted(outputRow) = sum(accepted & ...
                receivers{2}.detectedPhysicalBins ~= frame.truth.payloadPhysicalBins);
            effective = receivers{2}.pilotFirstEffectivePhysicalRow;
            if any(isfinite(effective))
                firstVpEffectivePhysicalRow(outputRow) = min(effective(isfinite(effective)));
            end
        end
    end
end
records = table(snrDbColumn,passIndexColumn,frameIndexColumn, ...
    frameCenterTimeSec,region,methodName,symbolErrors,symbolCount, ...
    hardBitErrors,hardBitCount,softBitErrors,softBitCount,packetError, ...
    cfoSquaredErrorSum,vpAccepted,vpFalseAccepted,firstVpEffectivePhysicalRow, ...
    fftCount,runtimeSec, ...
    deadlineMiss,fingerprintEnergy,fingerprintReal,fingerprintImag, ...
    payloadSeed,noiseSeed,channelSeed,crossFrameHistoryCount);
diagnostic = struct('passIndex',passIndex,'snrDb',snrDb, ...
    'symbolCfoSquaredErrorSum',symbolCfoSquaredErrorSum, ...
    'symbolCfoObservationCount',symbolCfoObservationCount);
end
