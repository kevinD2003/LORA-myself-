function report = run_stage55_huang_prec_cp_fresh_replay(options)
%RUN_STAGE55_HUANG_PREC_CP_FRESH_REPLAY Fair Huang-PREC Stage55 replay.
%   Reuses the exact Stage55 frame ledger: payload/noise seeds, continuous
%   Doppler phase, SNR, preamble/payload lengths, coding, and visible-frame
%   selection are identical.  Only the receiver algorithm changes.
%
%   Huang's eta/FFT search is adapted to continuous inter-symbol CFO phase
%   by accumulating the eight individual preamble FFT powers.  The payload
%   CFO remains frozen.  Hard BER is the decoder-fair tracking metric; the
%   delivered BER uses the same ML-soft Hamming engine as Stage55.

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
    error('SatelliteFig3:HuangPrecFreshFramesPerSegment', ...
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
                decoded = satelliteFig3HuangPrecCpMatchedDecode( ...
                    rx,config,known);
                runtimeSec = toc(receiverClock);
                referenceSymbols = labels(payloadRows);
                hardSymbols = decoded.detectedWaveformBins(payloadRows);
                referenceBits = payload.dataBits(:);
                hardBits = decoded.hardDecodedDataBits(:);
                deliveredBits = decoded.decodedDataBits(:);
                truthCfoBins = truth.trueDopplerHz(payloadRows)/ ...
                    config.fftBinSpacingHz;
                predictedCfoBins = ...
                    decoded.tracker.predictedCfoBins(payloadRows);
                cfoError = predictedCfoBins-truthCfoBins;

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
                data.method{row} = 'Huang-PREC-CP';
                data.payloadSeed(row) = payloadSeed;
                data.noiseSeed(row) = noiseSeed;
                data.symbolCount(row) = numel(referenceSymbols);
                data.symbolErrors(row) = sum(hardSymbols ~= referenceSymbols);
                data.bitCount(row) = numel(referenceBits);
                data.hardBitErrors(row) = sum(hardBits ~= referenceBits);
                data.deliveredBitErrors(row) = ...
                    sum(deliveredBits ~= referenceBits);
                data.deliveredFrameError(row) = ...
                    data.deliveredBitErrors(row) > 0;
                data.cfoSseBins(row) = sum(cfoError.^2);
                data.cfoSampleCount(row) = numel(cfoError);
                data.acceptedVirtualPilots(row) = 0;
                data.falseAcceptedVirtualPilots(row) = 0;
                data.receiverRuntimeSec(row) = runtimeSec;
                data.estimatedFrameCfoBins(row) = ...
                    decoded.bootstrap.epsilonHatBins;

                if isfinite(options.ProgressEveryFrames) && ...
                        options.ProgressEveryFrames > 0 && ...
                        mod(row,options.ProgressEveryFrames) == 0
                    fprintf('Fresh Huang-PREC-CP replay: %d/%d frames.\n', ...
                        row,maximumFrames);
                end
            end
        end
    end
end

records = struct2table(localTrim(data,row));
if height(records) ~= maximumFrames || ...
        any(records.symbolCount ~= config.payloadSymbolCount)
    error('SatelliteFig3:HuangPrecFreshIncomplete', ...
        'The fresh Huang-PREC-CP replay did not complete its frame ledger.');
end
csvFile = fullfile(resultDir,'stage55_fresh_huang_prec_cp_records.csv');
matFile = fullfile(resultDir,'stage55_fresh_huang_prec_cp_records.mat');
writetable(records,csvFile);
receiverName = 'Huang-PREC-CP';
receiverProvenance = [ ...
    'Huang thesis equations (4-1)--(4-7), eta step 0.1; ' ...
    'continuous-phase preamble power combining; frozen payload CFO'];
comparisonPolicy = [ ...
    'Same Stage55 frames/noise/channel/coding; hard BER is decoder-fair; ' ...
    'delivered BER uses common ML-soft Hamming'];
save(matFile,'config','schedule','segments','options','records', ...
    'receiverName','receiverProvenance','comparisonPolicy');
report = struct('resultDir',resultDir,'records',records, ...
    'csvFile',csvFile,'matFile',matFile, ...
    'receiverName',receiverName, ...
    'receiverProvenance',receiverProvenance, ...
    'comparisonPolicy',comparisonPolicy);
fprintf('Fresh Huang-PREC-CP replay complete: %s\n',resultDir);
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
