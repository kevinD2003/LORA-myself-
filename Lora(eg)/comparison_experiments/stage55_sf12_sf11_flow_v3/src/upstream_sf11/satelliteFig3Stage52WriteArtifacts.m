function artifacts = satelliteFig3Stage52WriteArtifacts( ...
        resultDir,state,options,config,schedule,methodNames)
%SATELLITEFIG3STAGE52WRITEARTIFACTS Formal complete-pass-only products.
%   Time-window confidence bounds resample whole completed passes.  A
%   single completed pass is explicitly labelled as wiring-only and uses
%   Wilson/exact-zero bounds until repeated passes are available.

arguments
    resultDir (1,:) char
    state (1,1) struct
    options (1,1) struct
    config (1,1) struct
    schedule (1,1) struct
    methodNames (1,:) cell
end
if ~isfolder(resultDir), mkdir(resultDir); end

frameTable = localFrameTable(state,options,schedule);
frameCsvPath = fullfile(resultDir,'stage52_frame_records.csv');
writetable(frameTable,frameCsvPath);
passTable = localPassTable(state,options,config,schedule,methodNames);
passCsvPath = fullfile(resultDir,'stage52_complete_pass_summary.csv');
writetable(passTable,passCsvPath);
[windowTable,plotData] = localWindowTable( ...
    state,options,config,schedule,methodNames);
windowCsvPath = fullfile(resultDir,'stage52_time_window_statistics.csv');
writetable(windowTable,windowCsvPath);
summaryTable = localOverallTable( ...
    state,options,config,schedule,methodNames);
summaryCsvPath = fullfile(resultDir,'stage52_overall_summary.csv');
writetable(summaryTable,summaryCsvPath);
pairedTable = localPairedTable(state,options,schedule);
pairedCsvPath = fullfile(resultDir,'stage52_paired_differences.csv');
writetable(pairedTable,pairedCsvPath);
regionTable = localRegionTable( ...
    state,options,config,schedule,methodNames);
regionCsvPath = fullfile(resultDir,'stage52_dynamic_region_summary.csv');
writetable(regionTable,regionCsvPath);
seedTable = localSeedTable(state,options,schedule);
seedCsvPath = fullfile(resultDir,'stage52_random_seed_ledger.csv');
writetable(seedTable,seedCsvPath);

imagePaths = cell(numel(options.SnrGridDb),1);
figurePaths = cell(numel(options.SnrGridDb),1);
for snrIndex = 1:numel(options.SnrGridDb)
    if ~any(state.passCompleted(snrIndex,:)), continue; end
    [imagePaths{snrIndex},figurePaths{snrIndex}] = localPlotSnr( ...
        resultDir,snrIndex,state,options,config,schedule, ...
        methodNames,plotData{snrIndex});
end
matPath = fullfile(resultDir,'stage52_formal_time_latest.mat');
save(matPath,'state','options','config','schedule','methodNames', ...
    'frameTable','passTable','windowTable','summaryTable', ...
    'pairedTable','regionTable','seedTable','plotData','-v7.3');
artifacts = struct('frameCsvPath',frameCsvPath, ...
    'passCsvPath',passCsvPath,'windowCsvPath',windowCsvPath, ...
    'summaryCsvPath',summaryCsvPath,'pairedCsvPath',pairedCsvPath, ...
    'regionCsvPath',regionCsvPath,'seedCsvPath',seedCsvPath, ...
    'imagePaths',{imagePaths},'figurePaths',{figurePaths}, ...
    'matPath',matPath,'frameTable',frameTable,'passTable',passTable, ...
    'windowTable',windowTable,'summaryTable',summaryTable, ...
    'pairedTable',pairedTable,'regionTable',regionTable, ...
    'seedTable',seedTable);
end

function tableOut = localFrameTable(state,options,schedule)
[snrIndex,passIndex,frameIndex] = ind2sub(size(state.processed), ...
    find(state.processed));
rowCount = numel(snrIndex);
snrDb = options.SnrGridDb(snrIndex);
frameStartTimeSec = schedule.frameStartTimeSec(frameIndex);
frameCenterTimeSec = schedule.frameCenterTimeSec(frameIndex);
frameEndTimeSec = schedule.frameEndTimeSec(frameIndex);
fullyVisible = schedule.fullyVisible(frameIndex);
fullyBlind = schedule.fullyBlind(frameIndex);
transitionFrame = schedule.transitionFrame(frameIndex);
passCompleted = false(rowCount,1);
for row = 1:rowCount
    passCompleted(row) = state.passCompleted( ...
        snrIndex(row),passIndex(row));
end
includedInFormalStatistics = passCompleted & fullyVisible;
linear = sub2ind(size(state.processed),snrIndex,passIndex,frameIndex);
payloadSeed = localColumn(state.payloadSeed(linear));
noiseSeed = localColumn(state.noiseSeed(linear));
bitCount = localColumn(state.bitCount(linear));
staticBitErrors = localColumn(state.staticBitErrors(linear));
senBitErrors = localColumn(state.senBitErrors(linear));
staticFrameError = localColumn(state.staticFrameError(linear));
senFrameError = localColumn(state.senFrameError(linear));
staticCfoRmseBins = nan(rowCount,1);
senCfoRmseBins = nan(rowCount,1);
staticCfoSse = localColumn(state.staticCfoSseBins(linear));
senCfoSse = localColumn(state.senCfoSseBins(linear));
cfoSampleCount = localColumn(state.cfoSampleCount(linear));
validCfo = cfoSampleCount > 0;
staticCfoRmseBins(validCfo) = sqrt( ...
    staticCfoSse(validCfo)./cfoSampleCount(validCfo));
senCfoRmseBins(validCfo) = sqrt( ...
    senCfoSse(validCfo)./cfoSampleCount(validCfo));
senAcceptedPilots = localColumn(state.senAcceptedPilots(linear));
senFalseAcceptedPilots = localColumn( ...
    state.senFalseAcceptedPilots(linear));
staticRuntimeSec = localColumn(state.staticRuntimeSec(linear));
senRuntimeSec = localColumn(state.senRuntimeSec(linear));
tableOut = table(snrIndex,snrDb,passIndex,frameIndex, ...
    frameStartTimeSec,frameCenterTimeSec,frameEndTimeSec, ...
    fullyVisible,fullyBlind,transitionFrame,passCompleted, ...
    includedInFormalStatistics,payloadSeed,noiseSeed,bitCount, ...
    staticBitErrors,senBitErrors,staticFrameError,senFrameError, ...
    staticCfoRmseBins,senCfoRmseBins,senAcceptedPilots, ...
    senFalseAcceptedPilots,staticRuntimeSec,senRuntimeSec);
end

function tableOut = localPassTable( ...
        state,options,config,schedule,methodNames)
rows = cell(0,1);
for snrIndex = 1:numel(options.SnrGridDb)
    completed = find(state.passCompleted(snrIndex,:));
    for passIndex = completed
        for method = 1:2
            metrics = localAggregateSelection(state,snrIndex,passIndex, ...
                schedule.fullyVisible,method,config,schedule);
            rows{end+1,1} = {snrIndex,options.SnrGridDb(snrIndex), ...
                passIndex,methodNames{method},metrics.frameCount, ...
                metrics.bitCount,metrics.bitErrors,metrics.ber, ...
                metrics.frameErrors,metrics.per,metrics.cfoRmseBins, ...
                metrics.activeLinkGoodputBps, ...
                metrics.passAverageDeliveryBps,metrics.acceptedPilots, ...
                metrics.falseAcceptedPilots,metrics.runtimeSec}; %#ok<AGROW>
        end
    end
end
if isempty(rows)
    tableOut = table();
    return
end
values = vertcat(rows{:});
tableOut = cell2table(values,'VariableNames',{ ...
    'snrIndex','snrDb','passIndex','method','frameCount','bitCount', ...
    'bitErrors','ber','frameErrors','per','cfoRmseBins', ...
    'activeLinkGoodputBps','passAverageDeliveryBps', ...
    'acceptedPilots','falseAcceptedPilots','runtimeSec'});
numeric = setdiff(tableOut.Properties.VariableNames,{'method'},'stable');
for column = 1:numel(numeric)
    if iscell(tableOut.(numeric{column}))
        tableOut.(numeric{column}) = cell2mat(tableOut.(numeric{column}));
    end
end
end

function [tableOut,plotData] = localWindowTable( ...
        state,options,config,schedule,methodNames)
edges = (schedule.passStartTimeSec:options.WindowDurationSec: ...
    schedule.passEndTimeSec).';
if edges(end) < schedule.passEndTimeSec
    edges(end+1,1) = schedule.passEndTimeSec;
else
    edges(end) = schedule.passEndTimeSec;
end
windowCount = numel(edges)-1;
windowStartTimeSec = edges(1:end-1);
windowEndTimeSec = edges(2:end);
windowCenterTimeSec = (windowStartTimeSec+windowEndTimeSec)/2;
trajectory = satelliteFig3Trajectory(windowCenterTimeSec,config);
rows = cell(0,1);
plotData = cell(numel(options.SnrGridDb),1);
for snrIndex = 1:numel(options.SnrGridDb)
    completed = find(state.passCompleted(snrIndex,:));
    repeatCount = numel(completed);
    data = localEmptyPlotData(windowCenterTimeSec,trajectory,windowCount);
    data.completedPassCount = repeatCount;
    if repeatCount == 0
        plotData{snrIndex} = data;
        continue
    end
    resample = localBootstrapIndices(repeatCount, ...
        options.BootstrapReplicates,options.BootstrapSeed+snrIndex);
    for windowIndex = 1:windowCount
        inWindow = schedule.frameCenterTimeSec >= ...
            windowStartTimeSec(windowIndex) & ...
            schedule.frameCenterTimeSec < windowEndTimeSec(windowIndex) & ...
            schedule.fullyVisible;
        visibleFrameCountPerPass = sum(inWindow);
        if visibleFrameCountPerPass == 0, continue; end
        methodStats = cell(2,1);
        for method = 1:2
            [passBits,passErrors,passFrames,passFrameErrors, ...
                passCfoSse,passCfoSamples,passAccepted] = ...
                localPassWindowVectors(state,snrIndex,completed,inWindow,method);
            ratio = localBootstrapRatio(passErrors,passBits,resample,true);
            perRatio = localBootstrapRatio( ...
                passFrameErrors,passFrames,resample,false);
            cfo = localBootstrapRootRatio(passCfoSse,passCfoSamples,resample);
            nominalRateBps = localPayloadBitCount(config)/ ...
                schedule.frameDurationSec;
            goodputRaw = nominalRateBps*(1-perRatio.raw);
            goodputLower = nominalRateBps*(1-perRatio.upper);
            goodputUpper = nominalRateBps*(1-perRatio.lower);
            methodStats{method} = struct('ber',ratio,'per',perRatio, ...
                'cfo',cfo,'goodputRaw',goodputRaw, ...
                'goodputLower',goodputLower,'goodputUpper',goodputUpper, ...
                'bits',sum(passBits),'errors',sum(passErrors), ...
                'frames',sum(passFrames), ...
                'frameErrors',sum(passFrameErrors), ...
                'meanAcceptedPilots',sum(passAccepted)/sum(passFrames), ...
                'passErrors',passErrors,'passBits',passBits, ...
                'passFrameErrors',passFrameErrors,'passFrames',passFrames);
            data.berShown(windowIndex,method) = ratio.shown;
            data.berRaw(windowIndex,method) = ratio.raw;
            data.berLower95(windowIndex,method) = ratio.lower;
            data.berUpper95(windowIndex,method) = ratio.upper;
            data.perRaw(windowIndex,method) = perRatio.raw;
            data.perLower95(windowIndex,method) = perRatio.lower;
            data.perUpper95(windowIndex,method) = perRatio.upper;
            data.cfoRmseBins(windowIndex,method) = cfo.raw;
            data.cfoLower95(windowIndex,method) = cfo.lower;
            data.cfoUpper95(windowIndex,method) = cfo.upper;
            data.goodputBps(windowIndex,method) = goodputRaw;
            data.goodputLower95(windowIndex,method) = goodputLower;
            data.goodputUpper95(windowIndex,method) = goodputUpper;
        end
        data.meanAcceptedPilots(windowIndex) = ...
            methodStats{2}.meanAcceptedPilots;
        [deltaBer,deltaBerLower,deltaBerUpper] = localPairedDelta( ...
            methodStats{1}.passErrors,methodStats{1}.passBits, ...
            methodStats{2}.passErrors,methodStats{2}.passBits,resample);
        [deltaPer,deltaPerLower,deltaPerUpper] = localPairedDelta( ...
            methodStats{1}.passFrameErrors,methodStats{1}.passFrames, ...
            methodStats{2}.passFrameErrors,methodStats{2}.passFrames,resample);
        data.deltaBerStaticMinusSen(windowIndex) = deltaBer;
        data.deltaBerLower95(windowIndex) = deltaBerLower;
        data.deltaBerUpper95(windowIndex) = deltaBerUpper;
        data.deltaPerStaticMinusSen(windowIndex) = deltaPer;
        data.deltaPerLower95(windowIndex) = deltaPerLower;
        data.deltaPerUpper95(windowIndex) = deltaPerUpper;
        confidenceUnit = localConfidenceUnit(repeatCount);
        rows{end+1,1} = {snrIndex,options.SnrGridDb(snrIndex), ...
            windowIndex,windowStartTimeSec(windowIndex), ...
            windowCenterTimeSec(windowIndex),windowEndTimeSec(windowIndex), ...
            repeatCount,visibleFrameCountPerPass,confidenceUnit, ...
            trajectory.dopplerShiftHz(windowIndex), ...
            trajectory.dopplerRateHzPerSec(windowIndex), ...
            methodStats{1}.bits,methodStats{2}.bits, ...
            methodStats{1}.errors,methodStats{2}.errors, ...
            methodStats{1}.ber.raw,methodStats{2}.ber.raw, ...
            methodStats{1}.ber.shown,methodStats{2}.ber.shown, ...
            methodStats{1}.ber.lower,methodStats{2}.ber.lower, ...
            methodStats{1}.ber.upper,methodStats{2}.ber.upper, ...
            methodStats{1}.frameErrors,methodStats{2}.frameErrors, ...
            methodStats{1}.per.raw,methodStats{2}.per.raw, ...
            methodStats{1}.per.lower,methodStats{2}.per.lower, ...
            methodStats{1}.per.upper,methodStats{2}.per.upper, ...
            methodStats{1}.cfo.raw,methodStats{2}.cfo.raw, ...
            methodStats{1}.cfo.lower,methodStats{2}.cfo.lower, ...
            methodStats{1}.cfo.upper,methodStats{2}.cfo.upper, ...
            methodStats{1}.goodputRaw,methodStats{2}.goodputRaw, ...
            methodStats{1}.goodputLower,methodStats{2}.goodputLower, ...
            methodStats{1}.goodputUpper,methodStats{2}.goodputUpper, ...
            methodStats{2}.meanAcceptedPilots,deltaBer,deltaBerLower, ...
            deltaBerUpper,deltaPer,deltaPerLower,deltaPerUpper}; %#ok<AGROW>
    end
    plotData{snrIndex} = data;
end
if isempty(rows)
    tableOut = table();
    return
end
values = vertcat(rows{:});
variables = {'snrIndex','snrDb','windowIndex','windowStartTimeSec', ...
    'windowCenterTimeSec','windowEndTimeSec','completedPasses', ...
    'visibleFramesPerPass','confidenceUnit','trueDopplerHz', ...
    'trueDopplerRateHzPerSec','staticBits','senBits', ...
    'staticBitErrors','senBitErrors','staticBerRaw','senBerRaw', ...
    'staticBerShown','senBerShown','staticBerLower95','senBerLower95', ...
    'staticBerUpper95','senBerUpper95','staticFrameErrors', ...
    'senFrameErrors','staticPer','senPer','staticPerLower95', ...
    'senPerLower95','staticPerUpper95','senPerUpper95', ...
    'staticCfoRmseBins','senCfoRmseBins','staticCfoLower95', ...
    'senCfoLower95','staticCfoUpper95','senCfoUpper95', ...
    'staticGoodputBps','senGoodputBps','staticGoodputLower95', ...
    'senGoodputLower95','staticGoodputUpper95','senGoodputUpper95', ...
    'meanSenAcceptedPilots','deltaBerStaticMinusSen', ...
    'deltaBerLower95','deltaBerUpper95','deltaPerStaticMinusSen', ...
    'deltaPerLower95','deltaPerUpper95'};
tableOut = cell2table(values,'VariableNames',variables);
numeric = setdiff(variables,{'confidenceUnit'},'stable');
for column = 1:numel(numeric)
    if iscell(tableOut.(numeric{column}))
        tableOut.(numeric{column}) = cell2mat(tableOut.(numeric{column}));
    end
end
end

function data = localEmptyPlotData(time,trajectory,windowCount)
data = struct('timeSec',time,'trueDopplerHz',trajectory.dopplerShiftHz, ...
    'trueDopplerRateHzPerSec',trajectory.dopplerRateHzPerSec, ...
    'completedPassCount',0,'berRaw',nan(windowCount,2), ...
    'berShown',nan(windowCount,2),'berLower95',nan(windowCount,2), ...
    'berUpper95',nan(windowCount,2),'perRaw',nan(windowCount,2), ...
    'perLower95',nan(windowCount,2),'perUpper95',nan(windowCount,2), ...
    'cfoRmseBins',nan(windowCount,2), ...
    'cfoLower95',nan(windowCount,2),'cfoUpper95',nan(windowCount,2), ...
    'goodputBps',nan(windowCount,2), ...
    'goodputLower95',nan(windowCount,2), ...
    'goodputUpper95',nan(windowCount,2), ...
    'meanAcceptedPilots',nan(windowCount,1), ...
    'deltaBerStaticMinusSen',nan(windowCount,1), ...
    'deltaBerLower95',nan(windowCount,1), ...
    'deltaBerUpper95',nan(windowCount,1), ...
    'deltaPerStaticMinusSen',nan(windowCount,1), ...
    'deltaPerLower95',nan(windowCount,1), ...
    'deltaPerUpper95',nan(windowCount,1));
end

function tableOut = localOverallTable( ...
        state,options,config,schedule,methodNames)
rows = cell(0,1);
for snrIndex = 1:numel(options.SnrGridDb)
    completed = find(state.passCompleted(snrIndex,:));
    if isempty(completed), continue; end
    resample = localBootstrapIndices(numel(completed), ...
        options.BootstrapReplicates,options.BootstrapSeed+100+snrIndex);
    for method = 1:2
        [passBits,passErrors,passFrames,passFrameErrors,passCfoSse, ...
            passCfoSamples,passAccepted,passFalse,passRuntime] = ...
            localPassOverallVectors(state,snrIndex,completed,method,schedule);
        ber = localBootstrapRatio(passErrors,passBits,resample,true);
        per = localBootstrapRatio(passFrameErrors,passFrames,resample,false);
        cfo = localBootstrapRootRatio(passCfoSse,passCfoSamples,resample);
        payloadBitCount = localPayloadBitCount(config);
        nominal = payloadBitCount/schedule.frameDurationSec;
        activeGoodput = nominal*(1-per.raw);
        passDelivery = payloadBitCount*sum(schedule.fullyVisible)* ...
            numel(completed)* ...
            (1-per.raw)/(schedule.passSpanSec*numel(completed));
        rows{end+1,1} = {snrIndex,options.SnrGridDb(snrIndex), ...
            methodNames{method},numel(completed), ...
            state.snrCompleted(snrIndex),state.completionReason{snrIndex}, ...
            localConfidenceUnit(numel(completed)),sum(passBits), ...
            sum(passErrors),ber.raw,ber.shown,ber.lower,ber.upper, ...
            sum(passFrameErrors),per.raw,per.lower,per.upper,cfo.raw, ...
            cfo.lower,cfo.upper,activeGoodput,passDelivery, ...
            sum(passAccepted),sum(passFalse),mean(passRuntime), ...
            state.maxPhaseBridgeErrorRad(snrIndex,completed), ...
            state.maxPhasePropagationErrorRad(snrIndex,completed), ...
            state.maxTimeGapErrorSec(snrIndex,completed), ...
            state.commonBootstrapCfoMaxDifferenceBins, ...
            state.commonPayloadStartPhaseMaxDifferenceRad}; %#ok<AGROW>
    end
end
if isempty(rows), tableOut=table(); return; end
% Reduce vector continuity entries before constructing the scalar table.
for row = 1:numel(rows)
    rows{row}{26} = max(rows{row}{26});
    rows{row}{27} = max(rows{row}{27});
    rows{row}{28} = max(rows{row}{28});
end
values = vertcat(rows{:});
variables = {'snrIndex','snrDb','method','completedPasses', ...
    'snrCompleted','completionReason','confidenceUnit','bitCount', ...
    'bitErrors','berRaw','berShown','berLower95','berUpper95', ...
    'frameErrors','per','perLower95','perUpper95','cfoRmseBins', ...
    'cfoLower95','cfoUpper95','activeLinkGoodputBps', ...
    'passAverageDeliveryBps','acceptedPilots','falseAcceptedPilots', ...
    'meanRuntimeSecPerFrame','maxPhaseBridgeErrorRad', ...
    'maxPhasePropagationErrorRad','maxTimeGapErrorSec', ...
    'commonBootstrapCfoMaxDifferenceBins', ...
    'commonPayloadStartPhaseMaxDifferenceRad'};
tableOut = cell2table(values,'VariableNames',variables);
textVariables = {'method','completionReason','confidenceUnit'};
numeric = setdiff(variables,textVariables,'stable');
for column = 1:numel(numeric)
    if iscell(tableOut.(numeric{column}))
        tableOut.(numeric{column}) = cell2mat(tableOut.(numeric{column}));
    end
end
end

function tableOut = localPairedTable(state,options,schedule)
rows = cell(0,1);
for snrIndex = 1:numel(options.SnrGridDb)
    completed = find(state.passCompleted(snrIndex,:));
    if isempty(completed), continue; end
    resample = localBootstrapIndices(numel(completed), ...
        options.BootstrapReplicates,options.BootstrapSeed+200+snrIndex);
    [sb,se,sf,sfe] = localPairedOverallVectors( ...
        state,snrIndex,completed,1,schedule);
    [nb,ne,nf,nfe] = localPairedOverallVectors( ...
        state,snrIndex,completed,2,schedule);
    [deltaBer,berLo,berHi] = localPairedDelta(se,sb,ne,nb,resample);
    [deltaPer,perLo,perHi] = localPairedDelta(sfe,sf,nfe,nf,resample);
    formalBootstrapAvailable = numel(completed) >= 2;
    rows{end+1,1} = {snrIndex,options.SnrGridDb(snrIndex), ...
        numel(completed),localConfidenceUnit(numel(completed)), ...
        deltaBer,berLo,berHi,deltaPer,perLo,perHi, ...
        formalBootstrapAvailable,(deltaBer>0), ...
        (formalBootstrapAvailable && berLo>0),(deltaPer>0), ...
        (formalBootstrapAvailable && perLo>0)}; %#ok<AGROW>
end
if isempty(rows), tableOut=table(); return; end
values = vertcat(rows{:});
variables = {'snrIndex','snrDb','completedPasses','confidenceUnit', ...
    'deltaBerStaticMinusSen','deltaBerLower95','deltaBerUpper95', ...
    'deltaPerStaticMinusSen','deltaPerLower95','deltaPerUpper95', ...
    'formalPassBootstrapAvailable','senLowerPointBer', ...
    'senBerAdvantage95','senLowerPointPer','senPerAdvantage95'};
tableOut = cell2table(values,'VariableNames',variables);
numeric = setdiff(variables,{'confidenceUnit'},'stable');
for column = 1:numel(numeric)
    if iscell(tableOut.(numeric{column}))
        tableOut.(numeric{column}) = cell2mat(tableOut.(numeric{column}));
    end
end
end

function tableOut = localRegionTable( ...
        state,options,config,schedule,methodNames)
trajectory = satelliteFig3Trajectory(schedule.frameCenterTimeSec,config);
driftBinsPerFrame = abs(trajectory.dopplerRateHzPerSec)/ ...
    config.fftBinSpacingHz*schedule.frameDurationSec;
regionName = {'low_dynamic_lt_0p5_bin_per_frame', ...
    'high_dynamic_ge_0p5_bin_per_frame'};
regionMask = {schedule.fullyVisible & driftBinsPerFrame < 0.5, ...
    schedule.fullyVisible & driftBinsPerFrame >= 0.5};
rows = cell(0,1);
for snrIndex = 1:numel(options.SnrGridDb)
    completed = find(state.passCompleted(snrIndex,:));
    if isempty(completed), continue; end
    for region = 1:2
        for method = 1:2
            metrics = localAggregateSelection(state,snrIndex,completed, ...
                regionMask{region},method,config,schedule);
            rows{end+1,1} = {snrIndex,options.SnrGridDb(snrIndex), ...
                regionName{region},methodNames{method},numel(completed), ...
                sum(regionMask{region}),metrics.bitCount,metrics.bitErrors, ...
                metrics.ber,metrics.frameErrors,metrics.per, ...
                metrics.cfoRmseBins,metrics.activeLinkGoodputBps, ...
                metrics.acceptedPilots,metrics.falseAcceptedPilots}; %#ok<AGROW>
        end
    end
end
if isempty(rows), tableOut=table(); return; end
values = vertcat(rows{:});
variables = {'snrIndex','snrDb','dynamicRegion','method', ...
    'completedPasses','framesPerPass','bitCount','bitErrors','ber', ...
    'frameErrors','per','cfoRmseBins','activeLinkGoodputBps', ...
    'acceptedPilots','falseAcceptedPilots'};
tableOut = cell2table(values,'VariableNames',variables);
numeric = setdiff(variables,{'dynamicRegion','method'},'stable');
for column = 1:numel(numeric)
    if iscell(tableOut.(numeric{column}))
        tableOut.(numeric{column}) = cell2mat(tableOut.(numeric{column}));
    end
end
end

function tableOut = localSeedTable(state,options,schedule)
[snrIndex,passIndex,frameIndex] = ind2sub(size(state.processed), ...
    find(state.processed));
linear = sub2ind(size(state.processed),snrIndex,passIndex,frameIndex);
snrDb = options.SnrGridDb(snrIndex);
payloadSeed = localColumn(state.payloadSeed(linear));
noiseSeed = localColumn(state.noiseSeed(linear));
fullyVisible = schedule.fullyVisible(frameIndex);
passCompleted = false(numel(snrIndex),1);
for row = 1:numel(snrIndex)
    passCompleted(row) = state.passCompleted(snrIndex(row),passIndex(row));
end
seedPolicy = repmat({ ...
    'base + 10000*completePassIndex + frameIndex; shared across SNR/method'}, ...
    numel(snrIndex),1);
tableOut = table(snrIndex,snrDb,passIndex,frameIndex,fullyVisible, ...
    passCompleted,payloadSeed,noiseSeed,seedPolicy);
end

function metrics = localAggregateSelection( ...
        state,snrIndex,passSelection,frameMask,method,config,schedule)
if islogical(passSelection), passSelection=find(passSelection); end
if method == 1
    bitErrors = state.staticBitErrors(snrIndex,passSelection,frameMask);
    frameErrors = state.staticFrameError(snrIndex,passSelection,frameMask);
    cfoSse = state.staticCfoSseBins(snrIndex,passSelection,frameMask);
    runtime = state.staticRuntimeSec(snrIndex,passSelection,frameMask);
    accepted = zeros(size(bitErrors)); falseAccepted=zeros(size(bitErrors));
else
    bitErrors = state.senBitErrors(snrIndex,passSelection,frameMask);
    frameErrors = state.senFrameError(snrIndex,passSelection,frameMask);
    cfoSse = state.senCfoSseBins(snrIndex,passSelection,frameMask);
    runtime = state.senRuntimeSec(snrIndex,passSelection,frameMask);
    accepted = state.senAcceptedPilots(snrIndex,passSelection,frameMask);
    falseAccepted = state.senFalseAcceptedPilots( ...
        snrIndex,passSelection,frameMask);
end
bits = state.bitCount(snrIndex,passSelection,frameMask);
cfoCount = state.cfoSampleCount(snrIndex,passSelection,frameMask);
metrics.frameCount = numel(frameErrors);
metrics.bitCount = sum(bits(:),'omitnan');
metrics.bitErrors = sum(bitErrors(:),'omitnan');
metrics.ber = metrics.bitErrors/metrics.bitCount;
metrics.frameErrors = sum(frameErrors(:),'omitnan');
metrics.per = metrics.frameErrors/metrics.frameCount;
metrics.cfoRmseBins = sqrt(sum(cfoSse(:),'omitnan')/sum(cfoCount(:)));
payloadBitCount = localPayloadBitCount(config);
nominal = payloadBitCount/schedule.frameDurationSec;
metrics.activeLinkGoodputBps = nominal*(1-metrics.per);
metrics.passAverageDeliveryBps = payloadBitCount* ...
    sum(schedule.fullyVisible)*(1-metrics.per)/schedule.passSpanSec;
metrics.acceptedPilots = sum(accepted(:),'omitnan');
metrics.falseAcceptedPilots = sum(falseAccepted(:),'omitnan');
metrics.runtimeSec = sum(runtime(:),'omitnan');
end

function [bits,errors,frames,frameErrors,cfoSse,cfoSamples,accepted] = ...
        localPassWindowVectors(state,snrIndex,passes,frameMask,method)
repeatCount = numel(passes);
bits=zeros(repeatCount,1); errors=bits; frames=bits; frameErrors=bits;
cfoSse=bits; cfoSamples=bits; accepted=bits;
for repeat = 1:repeatCount
    passIndex=passes(repeat);
    bits(repeat)=sum(state.bitCount(snrIndex,passIndex,frameMask),'all');
    frames(repeat)=sum(frameMask);
    cfoSamples(repeat)=sum( ...
        state.cfoSampleCount(snrIndex,passIndex,frameMask),'all');
    if method==1
        errors(repeat)=sum(state.staticBitErrors( ...
            snrIndex,passIndex,frameMask),'all','omitnan');
        frameErrors(repeat)=sum(state.staticFrameError( ...
            snrIndex,passIndex,frameMask),'all','omitnan');
        cfoSse(repeat)=sum(state.staticCfoSseBins( ...
            snrIndex,passIndex,frameMask),'all','omitnan');
    else
        errors(repeat)=sum(state.senBitErrors( ...
            snrIndex,passIndex,frameMask),'all','omitnan');
        frameErrors(repeat)=sum(state.senFrameError( ...
            snrIndex,passIndex,frameMask),'all','omitnan');
        cfoSse(repeat)=sum(state.senCfoSseBins( ...
            snrIndex,passIndex,frameMask),'all','omitnan');
        accepted(repeat)=sum(state.senAcceptedPilots( ...
            snrIndex,passIndex,frameMask),'all','omitnan');
    end
end
end

function [bits,errors,frames,frameErrors,cfoSse,cfoSamples,accepted, ...
        falseAccepted,runtime] = localPassOverallVectors( ...
        state,snrIndex,passes,method,schedule)
frameMask=schedule.fullyVisible;
[bits,errors,frames,frameErrors,cfoSse,cfoSamples,accepted] = ...
    localPassWindowVectors(state,snrIndex,passes,frameMask,method);
repeatCount=numel(passes); falseAccepted=zeros(repeatCount,1);
runtime=zeros(repeatCount,1);
for repeat=1:repeatCount
    p=passes(repeat);
    if method==1
        runtime(repeat)=sum(state.staticRuntimeSec( ...
            snrIndex,p,frameMask),'all','omitnan');
    else
        falseAccepted(repeat)=sum(state.senFalseAcceptedPilots( ...
            snrIndex,p,frameMask),'all','omitnan');
        runtime(repeat)=sum(state.senRuntimeSec( ...
            snrIndex,p,frameMask),'all','omitnan');
    end
end
runtime=runtime/sum(frameMask);
end

function [bits,errors,frames,frameErrors] = localPairedOverallVectors( ...
        state,snrIndex,passes,method,schedule)
[bits,errors,frames,frameErrors] = localPassWindowVectors( ...
    state,snrIndex,passes,schedule.fullyVisible,method);
end

function indices = localBootstrapIndices(repeats,replicates,seed)
if repeats < 2
    indices = zeros(0,0);
    return
end
stream = RandStream('mt19937ar','Seed',seed);
indices = randi(stream,repeats,[repeats,replicates]);
end

function stats = localBootstrapRatio(errors,counts,resample,zeroIsBer)
totalErrors=sum(errors); totalCounts=sum(counts);
[shown,wilsonLower,wilsonUpper] = satelliteFig3BerInterval95( ...
    totalErrors,totalCounts);
raw=totalErrors/totalCounts;
if isempty(resample)
    lower=wilsonLower; upper=wilsonUpper;
else
    boot=sum(errors(resample),1)./sum(counts(resample),1);
    lower=prctile(boot,2.5); upper=prctile(boot,97.5);
    if totalErrors==0
        lower=0; upper=wilsonUpper;
    end
end
if ~zeroIsBer && totalErrors==0
    shown=0;
end
stats=struct('raw',raw,'shown',shown,'lower',lower,'upper',upper);
end

function stats = localBootstrapRootRatio(numerator,denominator,resample)
raw=sqrt(sum(numerator)/sum(denominator));
if isempty(resample)
    lower=raw; upper=raw;
else
    boot=sqrt(sum(numerator(resample),1)./sum(denominator(resample),1));
    lower=prctile(boot,2.5); upper=prctile(boot,97.5);
end
stats=struct('raw',raw,'lower',lower,'upper',upper);
end

function [delta,lower,upper] = localPairedDelta( ...
        staticErrors,staticCounts,senErrors,senCounts,resample)
delta=sum(staticErrors)/sum(staticCounts)-sum(senErrors)/sum(senCounts);
if isempty(resample)
    lower=delta; upper=delta;
else
    boot=sum(staticErrors(resample),1)./sum(staticCounts(resample),1)- ...
        sum(senErrors(resample),1)./sum(senCounts(resample),1);
    lower=prctile(boot,2.5); upper=prctile(boot,97.5);
end
end

function text = localConfidenceUnit(repeatCount)
if repeatCount >= 2
    text='paired_complete_pass_bootstrap_95';
else
    text='single_complete_pass_wilson_wiring_only';
end
end

function [imagePath,figurePath] = localPlotSnr( ...
        resultDir,snrIndex,state,options,config,schedule,methodNames,data)
time=data.timeSec; colors=[0.85 0.15 0.10;0.00 0.35 0.85];
styles={'s--','o-'};
fig=figure('Visible','off','Color','w','Position',[55 25 1420 1120]);
tiledlayout(5,1,'TileSpacing','compact','Padding','compact');

ax1=nexttile;
yyaxis left; plot(time,data.trueDopplerHz/1e3,'Color',[0 0.45 0.74], ...
    'LineWidth',1.5); ylabel('Shift (kHz)'); ylim([-20 20]);
yyaxis right; plot(time,data.trueDopplerRateHzPerSec, ...
    'Color',[0.85 0.33 0.10],'LineWidth',1.5); ylabel('Rate (Hz/s)');
ylim([-250 0]);
grid on; grid minor; title('Continuous Figure-3 orbit','FontWeight','normal');
localBlindLines(ax1,schedule.window);

ax2=nexttile; set(ax2,'YScale','log'); hold on;
for method=1:2
    localBand(ax2,time,max(data.berLower95(:,method),1e-7), ...
        data.berUpper95(:,method),colors(method,:));
end
for method=1:2
    semilogy(time,data.berShown(:,method),styles{method}, ...
        'Color',colors(method,:),'LineWidth',1.35,'MarkerSize',4.5, ...
        'MarkerFaceColor','none','DisplayName',methodNames{method});
end
grid on; grid minor; ylim([1e-5 1]); ylabel('Window BER');
legend('Location','best','FontSize',8,'Box','on');
localShadeBlind(ax2,schedule.window);

ax3=nexttile; hold on;
for method=1:2
    localBand(ax3,time,data.perLower95(:,method), ...
        data.perUpper95(:,method),colors(method,:));
end
for method=1:2
    plot(time,data.perRaw(:,method),styles{method}, ...
        'Color',colors(method,:),'LineWidth',1.35,'MarkerSize',4.5, ...
        'MarkerFaceColor','none','DisplayName',methodNames{method});
end
grid on; grid minor; ylim([-0.03 1.03]); ylabel('Window PER');
legend('Location','best','FontSize',8,'Box','on');
localShadeBlind(ax3,schedule.window);

ax4=nexttile; yyaxis left; set(ax4,'YScale','log'); hold on;
for method=1:2
    localBand(ax4,time,max(data.cfoLower95(:,method),1e-5), ...
        data.cfoUpper95(:,method),colors(method,:));
end
for method=1:2
    semilogy(time,data.cfoRmseBins(:,method),styles{method}, ...
        'Color',colors(method,:),'LineWidth',1.35,'MarkerSize',4.5, ...
        'MarkerFaceColor','none','DisplayName',methodNames{method});
end
ylabel('CFO RMSE (bin)');
yyaxis right; plot(time,data.meanAcceptedPilots,'b:', ...
    'LineWidth',1.15,'DisplayName','SenLoRa accepted pilots');
ylabel('Accepted pilots/frame'); grid on; grid minor;
localBlindLines(ax4,schedule.window);

ax5=nexttile; hold on;
for method=1:2
    localBand(ax5,time,data.goodputLower95(:,method), ...
        data.goodputUpper95(:,method),colors(method,:));
end
for method=1:2
    plot(time,data.goodputBps(:,method),styles{method}, ...
        'Color',colors(method,:),'LineWidth',1.35,'MarkerSize',4.5, ...
        'MarkerFaceColor','none','DisplayName',methodNames{method});
end
nominal=localPayloadBitCount(config)/schedule.frameDurationSec;
yline(nominal,'k:','Nominal 716.1 bit/s','HandleVisibility','off');
grid on; grid minor; ylim([0 1.08*nominal]); ylabel('Goodput (bit/s)');
xlabel('Time relative to closest pass point (s)');
legend('Location','best','FontSize',8,'Box','on');
localShadeBlind(ax5,schedule.window);

axesList=[ax1 ax2 ax3 ax4 ax5];
for ax=axesList
    xlim(ax,[schedule.passStartTimeSec schedule.passEndTimeSec]);
    set(ax,'FontName','Times New Roman','FontSize',9.5,'Box','on', ...
        'GridLineStyle',':','MinorGridLineStyle',':');
end
confidenceText=localConfidenceUnit(data.completedPassCount);
sgtitle(sprintf(['Stage 52 fixed-SNR complete-pass comparison: %.1f dB, ' ...
    '%d passes, %s'],options.SnrGridDb(snrIndex), ...
    data.completedPassCount,strrep(confidenceText,'_',' ')), ...
    'FontName','Times New Roman','FontWeight','normal');
role=localSnrRole(options.SnrGridDb(snrIndex));
base=sprintf('stage52_time_%s_%s_dB',role, ...
    strrep(sprintf('%g',options.SnrGridDb(snrIndex)),'-','minus'));
imagePath=fullfile(resultDir,[base '.png']);
figurePath=fullfile(resultDir,[base '.fig']);
drawnow;
exportgraphics(fig,imagePath,'Resolution',200); savefig(fig,figurePath);
close(fig);
end

function role=localSnrRole(snrDb)
if snrDb==-21, role='main'; elseif snrDb==-20, role='supplemental';
else, role='diagnostic'; end
end

function localBand(ax,x,lower,upper,color)
valid=isfinite(x) & isfinite(lower) & isfinite(upper) & upper>=lower;
starts=find(valid & [true;~valid(1:end-1)]);
ends=find(valid & [~valid(2:end);true]);
for segment=1:numel(starts)
    index=starts(segment):ends(segment);
    patch(ax,[x(index);flipud(x(index))], ...
        [lower(index);flipud(upper(index))],color, ...
        'FaceAlpha',0.10,'EdgeColor','none','HandleVisibility','off');
end
end

function localShadeBlind(ax,window)
hold(ax,'on'); limits=ylim(ax); blind=window.blindIntervalSec;
patch(ax,[blind(1) blind(2) blind(2) blind(1)], ...
    [limits(1) limits(1) limits(2) limits(2)],[0.88 0.88 0.88], ...
    'FaceAlpha',0.30,'EdgeColor','none','HandleVisibility','off');
localBlindLines(ax,window); ylim(ax,limits);
end

function localBlindLines(ax,window)
xline(ax,window.blindIntervalSec(1),'Color',[0.45 0.45 0.45], ...
    'LineStyle',':','HandleVisibility','off');
xline(ax,window.blindIntervalSec(2),'Color',[0.45 0.45 0.45], ...
    'LineStyle',':','HandleVisibility','off');
end

function value = localColumn(value)
value = value(:);
end

function bitCount = localPayloadBitCount(config)
codewordLength = 4+config.cr;
blockCount = config.payloadSymbolCount/codewordLength;
if blockCount ~= round(blockCount)
    error('SatelliteFig3:Stage52PayloadBlocks', ...
        'The payload does not contain a whole number of coding blocks.');
end
bitCount = blockCount*config.sf*4;
end
