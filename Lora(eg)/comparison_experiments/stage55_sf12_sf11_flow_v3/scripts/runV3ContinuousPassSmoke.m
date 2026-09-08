function summary = runV3ContinuousPassSmoke()
%RUNV3CONTINUOUSPASSSMOKE One complete paired pass, wiring evidence only.

root = v3SetupPaths();
config = sf12Sf11FlowConfig();
[parameters,manifest] = v3LoadFrozenReceiverParameters(config);
schedule = v3ContinuousPassSchedule(config);
smokeSnrDb = -24;
passIndex = 4;
state = struct('nextFrameStartTimeSec',schedule.passStartTimeSec, ...
    'nextFrameStartPhaseRad',0,'crossFrameRateState',struct());

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
cfoRmseBins = zeros(recordCount,1);
vpAccepted = zeros(recordCount,1);
vpFalseAccepted = zeros(recordCount,1);
firstVpEffectivePhysicalRow = nan(recordCount,1);
fftCount = zeros(recordCount,1);
runtimeSec = zeros(recordCount,1);
deadlineMiss = false(recordCount,1);
fingerprintEnergy = zeros(recordCount,1);
fingerprintReal = zeros(recordCount,1);
fingerprintImag = zeros(recordCount,1);
crossFrameHistoryCount = zeros(recordCount,1);

trajectory = v3Trajectory(schedule.frameCenterTimeSec,config);
rateBinsPerSec = trajectory.dopplerRateHzPerSec/config.fftBinSpacingHz;
eligibleRate = abs(rateBinsPerSec(schedule.metricEligible));
regionThreshold = median(eligibleRate);
outputRow = 0;
for frameIndex = 1:schedule.frameCount
    ledger = v3RandomLedger(config,'validation',1,passIndex,frameIndex);
    frame = v3GenerateContinuousFrame(config,state.nextFrameStartTimeSec, ...
        smokeSnrDb,ledger,state.nextFrameStartPhaseRad);
    state.nextFrameStartTimeSec = frame.nextFrameStartTimeSec;
    state.nextFrameStartPhaseRad = frame.nextFrameStartPhaseRad;
    if schedule.metricEligible(frameIndex)
        bootstrap = v3CommonBootstrap(frame.observation.rxPhysical(1:8,:), ...
            config,SearchStepBins=parameters.searchStepBins);
        measurementTime = schedule.frameStartTimeSec(frameIndex)+ ...
            4*config.symbolDurationSec;
        [crossFrameRate,state.crossFrameRateState] = v3CrossFrameRateUpdate( ...
            state.crossFrameRateState,measurementTime,mean(bootstrap.cfoBins), ...
            bootstrap.rateBinsPerSec,config,parameters);
        timers = zeros(3,1);
        start = tic;
        receivers = cell(3,1);
        receivers{1} = v3HuangStaticDecode(frame.observation,bootstrap,config);
        timers(1) = toc(start);
        start = tic;
        receivers{2} = v3Stage55Decode(frame.observation,bootstrap,config,parameters, ...
            CrossFrameRateBinsPerSec=crossFrameRate, ...
            CrossFrameHistoryCount=state.crossFrameRateState.historyCount);
        timers(2) = toc(start);
        start = tic;
        receivers{3} = v3PaperMidambleDecode( ...
            frame.observation,bootstrap,config,parameters);
        timers(3) = toc(start);
        if abs(rateBinsPerSec(frameIndex)) >= regionThreshold
            frameRegion = "high-dynamic";
        else
            frameRegion = "low-dynamic";
        end
        for method = 1:3
            outputRow = outputRow+1;
            metrics = v3EvaluateFrame(receivers{method},frame.truth,config);
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
            cfoRmseBins(outputRow) = metrics.cfoRmseBins;
            fftCount(outputRow) = metrics.fftCount;
            runtimeSec(outputRow) = timers(method);
            deadlineMiss(outputRow) = timers(method) > schedule.frameDurationSec;
            fingerprintEnergy(outputRow) = frame.observation.sampleFingerprint(1);
            fingerprintReal(outputRow) = frame.observation.sampleFingerprint(2);
            fingerprintImag(outputRow) = frame.observation.sampleFingerprint(3);
            crossFrameHistoryCount(outputRow) = state.crossFrameRateState.historyCount;
            if method == 2
                vpAccepted(outputRow) = sum(receivers{2}.virtualPilotAccepted);
                vpFalseAccepted(outputRow) = sum(receivers{2}.virtualPilotAccepted & ...
                    receivers{2}.detectedPhysicalBins ~= frame.truth.payloadPhysicalBins);
                effective = receivers{2}.pilotFirstEffectivePhysicalRow;
                if any(isfinite(effective))
                    firstVpEffectivePhysicalRow(outputRow) = min(effective(isfinite(effective)));
                end
            end
        end
    end
    if mod(frameIndex,10) == 0 || frameIndex == schedule.frameCount
        fprintf('V3 smoke frame %d/%d\n',frameIndex,schedule.frameCount);
    end
end

frameRecords = table(frameIndexColumn,frameCenterTimeSec,region,methodName, ...
    symbolErrors,symbolCount,hardBitErrors,hardBitCount,softBitErrors, ...
    softBitCount,packetError,cfoSquaredErrorSum,cfoRmseBins,vpAccepted, ...
    vpFalseAccepted,firstVpEffectivePhysicalRow,fftCount,runtimeSec, ...
    deadlineMiss,fingerprintEnergy,fingerprintReal,fingerprintImag, ...
    crossFrameHistoryCount);
summary = struct('wiringOnly',true,'parameterRevision',4,'snrDb',smokeSnrDb, ...
    'frameCount',schedule.frameCount,'eligibleFrameCount',eligibleCount, ...
    'blindFrameCount',sum(schedule.fullyBlind), ...
    'transitionFrameCount',sum(schedule.transitionFrame), ...
    'regionThresholdAbsRateBinsPerSec',regionThreshold, ...
    'algorithmSignature',manifest.algorithmSignature, ...
    'receiverParameterStatus',manifest.status, ...
    'frameRecords',frameRecords);
outputDir = fullfile(root,'results','validation');
save(fullfile(outputDir,'v3_complete_pass_smoke_v4.mat'),'summary','-v7.3');
writetable(frameRecords,fullfile(outputDir,'v3_complete_pass_smoke_v4.csv'));
fprintf('V3 complete-pass smoke finished: %d eligible frames, wiring only.\n', ...
    eligibleCount);
end
