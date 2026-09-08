function report = run_stage44_parallel_formal_batch(options)
%RUN_STAGE44_PARALLEL_FORMAL_BATCH Parallel frame compute, serial merge.
%   Workers never write the checkpoint.  Results are merged in ascending
%   frame order, so random seeds and accumulated statistics match the
%   ordinary formal runner exactly.

arguments
    options.FrameCount (1,1) double {mustBeInteger,mustBePositive} = 1000
    options.WorkerCount (1,1) double {mustBeInteger,mustBePositive} = 8
    options.OutputFolderName (1,:) char = ...
        'stage45_formal_ber_minus30_to_minus14'
end

root = fileparts(mfilename('fullpath'));
resultDir = fullfile(root,'results',options.OutputFolderName);
checkpointPath = fullfile(resultDir,'formal_ber_checkpoint.mat');
if ~isfile(checkpointPath)
    error('SatelliteFig3:ParallelCheckpoint','Formal checkpoint is missing.');
end
loaded = load(checkpointPath);
state = loaded.state;
formalOptions = loaded.options;
config = loaded.config;
scenarioKeys = loaded.scenarioKeys;
startTimes = loaded.startTimes;
methodNames = loaded.methodNames;
savedSignature = loaded.savedSignature;
if state.terminationReached
    report = struct('framesComputed',0,'framesMerged',0, ...
        'allCompleted',true,'checkpointPath',checkpointPath);
    return
end
snrIndex = find(~state.completed,1,'first');
if isempty(snrIndex)
    report = struct('framesComputed',0,'framesMerged',0, ...
        'allCompleted',true,'checkpointPath',checkpointPath);
    return
end

payloadBitCount = config.sf*4*floor( ...
    config.payloadSymbolCount/(4+config.cr));
remainingFramesByBits = ceil(max(0,formalOptions.MaxBitsPerPoint- ...
    state.bits(snrIndex))/payloadBitCount);
batchCount = min(options.FrameCount,remainingFramesByBits);
if batchCount <= 0
    state.completed(snrIndex) = true;
    options = formalOptions; %#ok<NASGU>
    save(checkpointPath,'state','savedSignature','options','config', ...
        'scenarioKeys','startTimes','methodNames','-v7.3');
    report = struct('framesComputed',0,'framesMerged',0, ...
        'allCompleted',all(state.completed),'checkpointPath',checkpointPath);
    return
end

firstFrame = state.frameCount(snrIndex)+1;
frameNumbers = firstFrame+(0:batchCount-1);
template = localEmptyFrameResult();
frameResults = repmat(template,batchCount,1);
pool = gcp('nocreate');
if isempty(pool) || pool.NumWorkers ~= options.WorkerCount
    if ~isempty(pool), delete(pool); end
    pool = parpool('local',options.WorkerCount); %#ok<NASGU>
end
snrDb = formalOptions.SnrGridDb(snrIndex);
symbolSeedBase = formalOptions.SymbolSeedBase;
noiseSeedBase = formalOptions.NoiseSeedBase;
parfor batchIndex = 1:batchCount
    frameResults(batchIndex) = localComputeFrame(frameNumbers(batchIndex), ...
        snrIndex,snrDb,symbolSeedBase,noiseSeedBase,config,startTimes);
end

framesMerged = 0;
for batchIndex = 1:batchCount
    if localPointComplete(state,snrIndex,formalOptions) || ...
            localUpperBerTargetReached(state,snrIndex,formalOptions)
        break
    end
    item = frameResults(batchIndex);
    state.frameCount(snrIndex) = item.frame;
    state.bits(snrIndex) = state.bits(snrIndex)+item.bitCount;
    state.errors(:,snrIndex,:) = state.errors(:,snrIndex,:)+ ...
        reshape(item.errors,2,1,3);
    state.hardAccepted(:,snrIndex) = state.hardAccepted(:,snrIndex)+ ...
        item.hardAccepted;
    state.hardFalse(:,snrIndex) = state.hardFalse(:,snrIndex)+item.hardFalse;
    state.senAccepted(:,snrIndex) = state.senAccepted(:,snrIndex)+ ...
        item.senAccepted;
    state.senFalse(:,snrIndex) = state.senFalse(:,snrIndex)+item.senFalse;
    state.senReplayTriggered(:,snrIndex) = ...
        state.senReplayTriggered(:,snrIndex)+item.senReplayTriggered;
    state.senRateReleased(:,snrIndex) = ...
        state.senRateReleased(:,snrIndex)+item.senRateReleased;
    state.hardPredictionSse(:,snrIndex) = ...
        state.hardPredictionSse(:,snrIndex)+item.hardPredictionSse;
    state.senPredictionSse(:,snrIndex) = ...
        state.senPredictionSse(:,snrIndex)+item.senPredictionSse;
    state.hardPredictionSamples(:,snrIndex) = ...
        state.hardPredictionSamples(:,snrIndex)+item.predictionSamples;
    state.senPredictionSamples(:,snrIndex) = ...
        state.senPredictionSamples(:,snrIndex)+item.predictionSamples;
    state.commonNoiseMaxDifference = max(state.commonNoiseMaxDifference, ...
        item.commonNoiseMaxDifference);
    for scene = 1:2
        if isempty(state.trace{scene,snrIndex})
            state.trace{scene,snrIndex} = item.trace{scene};
        end
    end
    framesMerged = framesMerged+1;
end
state.completed(snrIndex) = localPointComplete(state,snrIndex,formalOptions);
if localUpperBerTargetReached(state,snrIndex,formalOptions)
    state.completed(snrIndex) = true;
    state.terminationReached = true;
    state.terminationSnrIndex = snrIndex;
end
options = formalOptions; %#ok<NASGU>
save(checkpointPath,'state','savedSignature','options','config', ...
    'scenarioKeys','startTimes','methodNames','-v7.3');
report = struct('framesComputed',batchCount,'framesMerged',framesMerged, ...
    'snrIndex',snrIndex,'snrDb',snrDb, ...
    'allCompleted',state.terminationReached || all(state.completed), ...
    'pointCompleted',state.completed(snrIndex), ...
    'checkpointPath',checkpointPath);
fprintf(['Stage 44 parallel batch at %.0f dB: computed %d, merged %d, ', ...
    'point complete=%d.\n'],snrDb,batchCount,framesMerged,state.completed(snrIndex));
end

function reached = localUpperBerTargetReached(state,snrIndex,options)
if state.bits(snrIndex) <= 0
    reached = false;
    return
end
errors = reshape(state.errors(:,snrIndex,2:3),[],1);
bits = repmat(state.bits(snrIndex),numel(errors),1);
[~,~,upper] = satelliteFig3BerInterval95(errors,bits);
reached = all(upper <= options.StopUpperBerTarget);
end

function item = localComputeFrame(frame,snrIndex,snrDb,symbolSeedBase, ...
        noiseSeedBase,config,startTimes)
known = zeros(config.bootstrapPilotCount,1);
symbolSeed = symbolSeedBase+100000*snrIndex+frame;
noiseSeed = noiseSeedBase+100000*snrIndex+frame;
payload = satelliteFig3GeneratePayload(config,symbolSeed);
labels = [known;payload.symbolBins];
payloadRows = config.bootstrapPilotCount+1:numel(labels);
item = localEmptyFrameResult();
item.frame = frame;
item.bitCount = numel(payload.dataBits);
noiseReference = [];
for scene = 1:2
    [rx,tx,truth] = generateContinuousSatelliteFrame(labels,config, ...
        StartTimeSec=startTimes(scene),SampleSnrDb=snrDb,NoiseSeed=noiseSeed);
    channelNoise = rx-tx.*exp(1i*truth.phaseRad);
    if scene == 1
        noiseReference = channelNoise;
    else
        item.commonNoiseMaxDifference = max(abs( ...
            channelNoise-noiseReference),[],'all');
    end
    noCompBins = localHardBins(rx,config);
    noCompBits = satelliteFig3HardPayloadBits(noCompBins(payloadRows),config);
    hard = satelliteFig3HardPrecDecode(rx,config,known);
    sen = satelliteFig3AdaptiveRateReplaySenLoRaDecode(rx,config,known);
    decoded = {noCompBits,hard.decodedDataBits,sen.hardDecodedDataBits};
    for method = 1:3
        item.errors(scene,method) = sum( ...
            decoded{method}(:) ~= payload.dataBits(:));
    end
    hardMask = hard.pilotAccepted(payloadRows);
    senMask = sen.pilotAccepted(payloadRows);
    item.hardAccepted(scene) = sum(hardMask);
    item.hardFalse(scene) = sum(hardMask & ...
        hard.detectedWaveformBins(payloadRows) ~= labels(payloadRows));
    item.senAccepted(scene) = sum(senMask);
    item.senFalse(scene) = sum(senMask & ...
        sen.detectedWaveformBins(payloadRows) ~= labels(payloadRows));
    item.senReplayTriggered(scene) = sen.rateReplay.triggered;
    item.senRateReleased(scene) = ...
        sen.tracker.acceptedVirtualPilotCount >= config.senloraRateReleasePilotCount;
    truthBins = truth.trueDopplerHz/config.fftBinSpacingHz;
    hardDelta = hard.tracker.predictedCfoBins(payloadRows)-truthBins(payloadRows);
    senDelta = sen.tracker.predictedCfoBins(payloadRows)-truthBins(payloadRows);
    item.hardPredictionSse(scene) = sum(hardDelta.^2);
    item.senPredictionSse(scene) = sum(senDelta.^2);
    item.predictionSamples(scene) = numel(hardDelta);
    item.trace{scene} = localTrace(symbolSeed,noiseSeed,truthBins, ...
        hard,sen,payloadRows);
end
end

function item = localEmptyFrameResult()
item = struct('frame',0,'bitCount',0,'errors',zeros(2,3), ...
    'hardAccepted',zeros(2,1),'hardFalse',zeros(2,1), ...
    'senAccepted',zeros(2,1),'senFalse',zeros(2,1), ...
    'senReplayTriggered',zeros(2,1),'senRateReleased',zeros(2,1), ...
    'hardPredictionSse',zeros(2,1),'senPredictionSse',zeros(2,1), ...
    'predictionSamples',zeros(2,1),'commonNoiseMaxDifference',0, ...
    'trace',{cell(2,1)});
end

function bins = localHardBins(symbols,config)
bins = zeros(size(symbols,1),1);
for row = 1:size(symbols,1)
    decision = satelliteFig3HardDecision(symbols(row,:),config);
    bins(row) = decision.waveformBin;
end
end

function complete = localPointComplete(state,snrIndex,options)
if state.bits(snrIndex) >= options.MaxBitsPerPoint
    complete = true;
else
    complete = all(reshape(state.errors(:,snrIndex,:),[],1) >= ...
        options.TargetBitErrors);
end
end

function trace = localTrace(symbolSeed,noiseSeed,truthBins,hard,sen,rows)
trace = struct('symbolSeed',symbolSeed,'noiseSeed',noiseSeed, ...
    'payloadRows',rows(:),'truthCfoBins',truthBins(rows), ...
    'hardPredictedCfoBins',hard.tracker.predictedCfoBins(rows), ...
    'hardPredictedRateBinsPerSec',hard.tracker.predictedRateBinsPerSec(rows), ...
    'hardResidualBins',hard.tracker.measuredResidualBins(rows), ...
    'hardPilotAccepted',hard.pilotAccepted(rows), ...
    'senPredictedCfoBins',sen.tracker.predictedCfoBins(rows), ...
    'senPredictedRateBinsPerSec',sen.tracker.predictedRateBinsPerSec(rows), ...
    'senResidualBins',sen.tracker.measuredResidualBins(rows), ...
    'senPilotAccepted',sen.pilotAccepted(rows), ...
    'senRateReplay',sen.rateReplay);
end
