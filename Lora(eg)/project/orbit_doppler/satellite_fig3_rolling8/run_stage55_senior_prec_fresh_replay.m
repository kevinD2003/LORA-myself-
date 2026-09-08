function report = run_stage55_senior_prec_fresh_replay(options)
%RUN_STAGE55_SENIOR_PREC_FRESH_REPLAY Exact senior-code PREC on fresh frames.
%   This is an independent regeneration, not a read of a frozen Stage55
%   performance table.  The payload, noise, continuous Doppler phase, SNR,
%   pass count, and visible-frame ledger are selected by the same rules as
%   run_stage55_vp_mechanism_ablation.  The receiver is the exact
%   satelliteFig3PaperPrecDecode reference: one preamble CFO estimate is
%   held fixed over the complete payload, with no virtual pilots.

arguments
    options.SnrGridDb (:,1) double = [-21;-20]
    options.PassCount (1,1) double ...
        {mustBeInteger,mustBePositive} = 3
    options.FramesPerVisibleSegment (1,1) double = Inf
    options.PayloadSeedBase (1,1) double = 2026551800
    options.NoiseSeedBase (1,1) double = 2026551900
    options.OutputFolderName (1,:) char = ...
        'stage55_vp_quality_fresh_rerun_20260812'
    options.ProgressEveryFrames (1,1) double = 50
end

if ~(isinf(options.FramesPerVisibleSegment) || ( ...
        options.FramesPerVisibleSegment >= 1 && ...
        options.FramesPerVisibleSegment == ...
        round(options.FramesPerVisibleSegment)))
    error('SatelliteFig3:SeniorFreshFramesPerSegment', ...
        'FramesPerVisibleSegment must be Inf or a positive integer.');
end

root = fileparts(mfilename('fullpath'));
resultDir = fullfile(root,'results',options.OutputFolderName);
if ~isfolder(resultDir), mkdir(resultDir); end
config = satelliteFig3Config();
schedule = satelliteFig3ContinuousPassSchedule(config);
trajectory = satelliteFig3Trajectory(schedule.frameCenterTimeSec,config);
driftBinsPerFrame = abs(trajectory.dopplerRateHzPerSec).* ...
    schedule.frameDurationSec/config.fftBinSpacingHz;
segmentEdges = find(diff([false;schedule.fullyVisible(:);false]));
segments = reshape(segmentEdges,2,[]).'+[0 -1];
if isfinite(options.FramesPerVisibleSegment)
    segments(:,2) = min(segments(:,2), ...
        segments(:,1)+options.FramesPerVisibleSegment-1);
end

known = zeros(config.bootstrapPilotCount,1);
payloadRows = (config.bootstrapPilotCount+1:config.frameSymbolCount).';
framesPerPass = sum(segments(:,2)-segments(:,1)+1);
maximumFrames = numel(options.SnrGridDb)*options.PassCount*framesPerPass;
data = localPreallocate(maximumFrames);
row = 0;

for snrIndex = 1:numel(options.SnrGridDb)
    for passIndex = 1:options.PassCount
        for segmentIndex = 1:size(segments,1)
            phaseStateRad = 0;
            for frameIndex = segments(segmentIndex,1):segments(segmentIndex,2)
                payloadSeed = options.PayloadSeedBase+ ...
                    1000000*snrIndex+10000*passIndex+frameIndex;
                noiseSeed = options.NoiseSeedBase+ ...
                    1000000*snrIndex+10000*passIndex+frameIndex;
                payload = satelliteFig3GeneratePayload(config,payloadSeed);
                labels = [known;payload.symbolBins];
                [rx,~,truth] = generateContinuousSatelliteFrame( ...
                    labels,config, ...
                    StartTimeSec=schedule.frameStartTimeSec(frameIndex), ...
                    SampleSnrDb=options.SnrGridDb(snrIndex), ...
                    NoiseSeed=noiseSeed,InitialPhaseRad=phaseStateRad, ...
                    NextSymbolBin=0);
                phaseStateRad = localWrapToPi(truth.nextFrameStartPhaseRad);

                receiverClock = tic;
                decoded = satelliteFig3PaperPrecDecode(rx,config,known);
                runtimeSec = toc(receiverClock);
                referenceSymbols = labels(payloadRows);
                hardSymbols = decoded.detectedWaveformBins(payloadRows);
                referenceBits = payload.dataBits(:);
                hardBits = decoded.decodedDataBits(:);
                truthCfoBins = truth.trueDopplerHz(payloadRows)/ ...
                    config.fftBinSpacingHz;
                cfoError = decoded.epsilonHatBins-truthCfoBins;

                row = row+1;
                data.snrDb(row) = options.SnrGridDb(snrIndex);
                data.passIndex(row) = passIndex;
                data.segmentIndex(row) = segmentIndex;
                data.frameIndex(row) = frameIndex;
                data.frameCenterTimeSec(row) = ...
                    schedule.frameCenterTimeSec(frameIndex);
                data.driftBinsPerFrame(row) = driftBinsPerFrame(frameIndex);
                if driftBinsPerFrame(frameIndex) >= 0.5
                    data.region{row} = 'high_doppler_rate';
                else
                    data.region{row} = 'high_doppler_shift';
                end
                data.method{row} = 'Senior-PREC';
                data.payloadSeed(row) = payloadSeed;
                data.noiseSeed(row) = noiseSeed;
                data.symbolCount(row) = numel(referenceSymbols);
                data.symbolErrors(row) = sum(hardSymbols ~= referenceSymbols);
                data.bitCount(row) = numel(referenceBits);
                data.hardBitErrors(row) = sum(hardBits ~= referenceBits);
                data.deliveredBitErrors(row) = data.hardBitErrors(row);
                data.deliveredFrameError(row) = ...
                    data.deliveredBitErrors(row) > 0;
                data.cfoSseBins(row) = sum(cfoError.^2);
                data.cfoSampleCount(row) = numel(cfoError);
                data.acceptedVirtualPilots(row) = 0;
                data.falseAcceptedVirtualPilots(row) = 0;
                data.receiverRuntimeSec(row) = runtimeSec;
                data.estimatedFrameCfoBins(row) = decoded.epsilonHatBins;

                if isfinite(options.ProgressEveryFrames) && ...
                        options.ProgressEveryFrames > 0 && ...
                        mod(row,options.ProgressEveryFrames) == 0
                    fprintf('Fresh Senior-PREC replay: %d/%d frames.\n', ...
                        row,maximumFrames);
                end
            end
        end
    end
end

records = struct2table(localTrim(data,row));
if height(records) ~= maximumFrames || ...
        any(records.symbolCount ~= config.payloadSymbolCount)
    error('SatelliteFig3:SeniorFreshIncomplete', ...
        'The fresh Senior-PREC replay did not complete its frame ledger.');
end
csvFile = fullfile(resultDir,'stage55_fresh_senior_prec_records.csv');
matFile = fullfile(resultDir,'stage55_fresh_senior_prec_records.mat');
writetable(records,csvFile);
save(matFile,'config','schedule','segments','options','records');
report = struct('resultDir',resultDir,'records',records, ...
    'csvFile',csvFile,'matFile',matFile);
fprintf('Fresh Senior-PREC replay complete: %s\n',resultDir);
end

function data = localPreallocate(count)
numericFields = {'snrDb','passIndex','segmentIndex','frameIndex', ...
    'frameCenterTimeSec','driftBinsPerFrame','payloadSeed','noiseSeed', ...
    'symbolCount','symbolErrors','bitCount','hardBitErrors', ...
    'deliveredBitErrors','cfoSseBins','cfoSampleCount', ...
    'acceptedVirtualPilots','falseAcceptedVirtualPilots', ...
    'receiverRuntimeSec','estimatedFrameCfoBins'};
for index = 1:numel(numericFields)
    data.(numericFields{index}) = zeros(count,1);
end
data.region = cell(count,1);
data.method = cell(count,1);
data.deliveredFrameError = false(count,1);
end

function data = localTrim(data,count)
fields = fieldnames(data);
for index = 1:numel(fields)
    data.(fields{index}) = data.(fields{index})(1:count,:);
end
end

function angleRad = localWrapToPi(angleRad)
angleRad = mod(angleRad+pi,2*pi)-pi;
end
