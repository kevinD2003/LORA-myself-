function candidatePath = backfill_stage42_hard_prec()
%BACKFILL_STAGE42_HARD_PREC Recompute only the corrected hard-PREC arm.
%   No-compensation and SenLoRa state are preserved bit-for-bit.  The same
%   payload/noise seeds and trajectory calls reconstruct every prior frame.

root = fileparts(mfilename('fullpath'));
resultDir = fullfile(root,'results','stage42_formal_ber_minus30_to_minus10');
checkpointPath = fullfile(resultDir,'formal_ber_checkpoint.mat');
candidatePath = fullfile(resultDir, ...
    'formal_ber_checkpoint_stage43_candidate.mat');
if ~isfile(checkpointPath)
    error('SatelliteFig3:BackfillSource','Stage 42 checkpoint is missing.');
end
if isfile(candidatePath)
    error('SatelliteFig3:BackfillTarget', ...
        'Backfill candidate already exists; refusing to overwrite it.');
end

source = load(checkpointPath);
state = source.state;
options = source.options;
config = satelliteFig3Config();
[window,~] = satelliteFig3VisibilityWindow(config);
startTimes = [-window.deltaTimeOutSec,window.deltaTimeInSec];
known = zeros(config.bootstrapPilotCount,1);

state.errors(:,:,2) = 0;
state.hardAccepted(:) = 0;
state.hardFalse(:) = 0;
state.hardPredictionSse(:) = 0;
state.hardPredictionSamples(:) = 0;

for snrIndex = 1:numel(options.SnrGridDb)
    for frame = 1:state.frameCount(snrIndex)
        symbolSeed = options.SymbolSeedBase+100000*snrIndex+frame;
        noiseSeed = options.NoiseSeedBase+100000*snrIndex+frame;
        payload = satelliteFig3GeneratePayload(config,symbolSeed);
        labels = [known;payload.symbolBins];
        payloadRows = config.bootstrapPilotCount+1:numel(labels);
        for scene = 1:2
            [rx,~,truth] = generateContinuousSatelliteFrame(labels,config, ...
                StartTimeSec=startTimes(scene), ...
                SampleSnrDb=options.SnrGridDb(snrIndex), ...
                NoiseSeed=noiseSeed);
            hard = satelliteFig3HardPrecDecode(rx,config,known);
            state.errors(scene,snrIndex,2) = ...
                state.errors(scene,snrIndex,2)+sum( ...
                hard.decodedDataBits(:) ~= payload.dataBits(:));
            accepted = hard.pilotAccepted(payloadRows);
            state.hardAccepted(scene,snrIndex) = ...
                state.hardAccepted(scene,snrIndex)+sum(accepted);
            state.hardFalse(scene,snrIndex) = ...
                state.hardFalse(scene,snrIndex)+sum(accepted & ...
                hard.detectedWaveformBins(payloadRows) ~= labels(payloadRows));
            truthBins = truth.trueDopplerHz/config.fftBinSpacingHz;
            predictionError = hard.tracker.predictedCfoBins(payloadRows)- ...
                truthBins(payloadRows);
            state.hardPredictionSse(scene,snrIndex) = ...
                state.hardPredictionSse(scene,snrIndex)+sum(predictionError.^2);
            state.hardPredictionSamples(scene,snrIndex) = ...
                state.hardPredictionSamples(scene,snrIndex)+numel(predictionError);
            if frame == state.frameCount(snrIndex) && ...
                    ~isempty(state.trace{scene,snrIndex})
                trace = state.trace{scene,snrIndex};
                trace.hardPredictedCfoBins = ...
                    hard.tracker.predictedCfoBins(payloadRows);
                trace.hardPredictedRateBinsPerSec = ...
                    hard.tracker.predictedRateBinsPerSec(payloadRows);
                trace.hardResidualBins = ...
                    hard.tracker.measuredResidualBins(payloadRows);
                trace.hardPilotAccepted = hard.pilotAccepted(payloadRows);
                state.trace{scene,snrIndex} = trace;
            end
        end
    end
    pointErrors = reshape(state.errors(:,snrIndex,:),[],1);
    state.completed(snrIndex) = state.bits(snrIndex) >= ...
        options.MaxBitsPerPoint || all(pointErrors >= options.TargetBitErrors);
    fprintf('Backfilled hard PREC at %.0f dB: %d frames.\n', ...
        options.SnrGridDb(snrIndex),state.frameCount(snrIndex));
end

savedSignature = source.savedSignature;
savedSignature.hardPrecRateReleasePilotCount = ...
    config.hardPrecRateReleasePilotCount;
savedSignature.hardPrecRateTrackingDeviationLimitBinsPerSec = ...
    config.hardPrecRateTrackingDeviationLimitBinsPerSec;
methodNames = source.methodNames;
scenarioKeys = source.scenarioKeys;
save(candidatePath,'state','savedSignature','options','config', ...
    'methodNames','scenarioKeys','startTimes','-v7.3');
fprintf('Stage 43 hard-PREC backfill candidate: %s\n',candidatePath);
end
