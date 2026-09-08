function report = run_fuxian_stage55_three_method_replay(options)
%RUN_FUXIAN_STAGE55_THREE_METHOD_REPLAY Common-frame trajectory replay.

arguments
    options.SnrGridDb (:,1) double = [-21;-20]
    options.PassCount (1,1) double ...
        {mustBeInteger,mustBePositive} = 3
    options.FramesPerVisibleSegment (1,1) double = Inf
    options.PayloadSeedBase (1,1) double = 2026551800
    options.NoiseSeedBase (1,1) double = 2026551900
    options.OutputFolderName (1,:) char = ...
        'stage55_sf11_midamble_three_method_replay'
    options.ProgressEveryFrames (1,1) double = 50
    options.PaperReceiverVersion (1,1) string ...
        {mustBeMember(options.PaperReceiverVersion, ...
        ["legacy", "sf11_v2"])} = "legacy"
end

comparisonRoot = fileparts(mfilename('fullpath'));
sourceRoot = fuxianSourceRoot(comparisonRoot);
savedPath = path;
restorePath = onCleanup(@() path(savedPath));
addpath(sourceRoot,'-begin');
experiment = fuxianComparisonConfig();
experiment.paperReceiverVersion = options.PaperReceiverVersion;
experiment.sourceProfileFittedOrTuned = ...
    options.PaperReceiverVersion == "sf11_v2";
experiment.stage55ResultTuned = false;
if options.PaperReceiverVersion == "sf11_v2"
    experiment.fittedOrTuned = true;
end
config = experiment.physicalConfig;
schedule = satelliteFig3ContinuousPassSchedule(config);
trajectory = satelliteFig3Trajectory( ...
    schedule.frameCenterTimeSec,config);
driftBinsPerFrame = abs(trajectory.dopplerRateHzPerSec).* ...
    schedule.frameDurationSec/config.fftBinSpacingHz;
segmentEdges = find(diff([false;schedule.fullyVisible(:);false]));
segments = reshape(segmentEdges,2,[]).'+[0 -1];
if isfinite(options.FramesPerVisibleSegment)
    segments(:,2) = min(segments(:,2), ...
        segments(:,1)+options.FramesPerVisibleSegment-1);
end
if ~(isinf(options.FramesPerVisibleSegment) || ( ...
        options.FramesPerVisibleSegment >= 1 && ...
        options.FramesPerVisibleSegment == ...
        round(options.FramesPerVisibleSegment)))
    error('FuxianDuibi:FramesPerSegment', ...
        'FramesPerVisibleSegment must be Inf or a positive integer.');
end

resultDir = fullfile(comparisonRoot,'results', ...
    options.OutputFolderName);
if ~isfolder(resultDir)
    mkdir(resultDir);
end
framesPerPass = sum(segments(:,2)-segments(:,1)+1);
physicalFrameCount = numel(options.SnrGridDb)* ...
    options.PassCount*framesPerPass;
methodCount = numel(experiment.methodNames);
data = localPreallocate(physicalFrameCount*methodCount);
row = 0;
frameCounter = 0;

for snrIndex = 1:numel(options.SnrGridDb)
    for passIndex = 1:options.PassCount
        for segmentIndex = 1:size(segments,1)
            senLoRaState = struct();
            phaseStateRad = 0;
            for frameIndex = segments(segmentIndex,1):segments(segmentIndex,2)
                payloadSeed = options.PayloadSeedBase + ...
                    1000000*snrIndex + 10000*passIndex + frameIndex;
                noiseSeed = options.NoiseSeedBase + ...
                    1000000*snrIndex + 10000*passIndex + frameIndex;
                payload = satelliteFig3GeneratePayload(config,payloadSeed);
                layout = fuxianMidambleLayout( ...
                    payload.symbolBins,experiment);
                [rx,~,truth] = generateContinuousSatelliteFrame( ...
                    layout.physicalBins,config, ...
                    StartTimeSec=schedule.frameStartTimeSec(frameIndex), ...
                    SampleSnrDb=options.SnrGridDb(snrIndex), ...
                    NoiseSeed=noiseSeed, ...
                    InitialPhaseRad=phaseStateRad,NextSymbolBin=0);
                phaseStateRad = localWrapToPi( ...
                    truth.nextFrameStartPhaseRad);

                huang = fuxianHuangDecode(rx,config,layout);
                senlora = fuxianSenLoRaDecode(rx,config,layout, ...
                    FrameStartTimeSec= ...
                        schedule.frameStartTimeSec(frameIndex), ...
                    CrossFrameState=senLoRaState);
                if options.PaperReceiverVersion == "legacy"
                    paper = fuxianPaperMidamblePointDecode( ...
                        rx,config,layout);
                else
                    paper = fuxianPaperMidamblePointDecodeV2( ...
                        rx,config,layout);
                end
                senLoRaState = senlora.crossFrameState;
                localAssertCommonBootstrap(huang,senlora,paper);
                branches = {huang,senlora,paper};

                if driftBinsPerFrame(frameIndex) >= 0.5
                    region = 'high_doppler_rate';
                else
                    region = 'high_doppler_shift';
                end
                referenceSymbols = payload.symbolBins;
                referenceBits = payload.dataBits(:);
                truthCfoBins = truth.trueDopplerHz(layout.dataRows)/ ...
                    config.fftBinSpacingHz;
                for methodIndex = 1:methodCount
                    branch = branches{methodIndex};
                    hardSymbols = branch.detectedWaveformBins( ...
                        layout.dataRows);
                    hardBits = branch.hardDecodedDataBits(:);
                    deliveredBits = branch.decodedDataBits(:);
                    cfoError = branch.tracker.predictedCfoBins( ...
                        layout.dataRows)-truthCfoBins;
                    accepted = branch.tracker.pilotAccepted( ...
                        layout.dataRows);

                    row = row+1;
                    data.snrDb(row) = options.SnrGridDb(snrIndex);
                    data.passIndex(row) = passIndex;
                    data.segmentIndex(row) = segmentIndex;
                    data.frameIndex(row) = frameIndex;
                    data.frameCenterTimeSec(row) = ...
                        schedule.frameCenterTimeSec(frameIndex);
                    data.driftBinsPerFrame(row) = ...
                        driftBinsPerFrame(frameIndex);
                    data.region{row} = region;
                    data.method{row} = ...
                        experiment.methodNames{methodIndex};
                    data.payloadSeed(row) = payloadSeed;
                    data.noiseSeed(row) = noiseSeed;
                    data.symbolCount(row) = numel(referenceSymbols);
                    data.symbolErrors(row) = ...
                        sum(hardSymbols ~= referenceSymbols);
                    data.bitCount(row) = numel(referenceBits);
                    data.hardBitErrors(row) = ...
                        sum(hardBits ~= referenceBits);
                    data.deliveredBitErrors(row) = ...
                        sum(deliveredBits ~= referenceBits);
                    data.deliveredFrameError(row) = ...
                        data.deliveredBitErrors(row) > 0;
                    data.cfoSseBins(row) = sum(cfoError.^2);
                    data.cfoSampleCount(row) = numel(cfoError);
                    data.acceptedVirtualPilots(row) = sum(accepted);
                    data.falseAcceptedVirtualPilots(row) = ...
                        sum(accepted & hardSymbols ~= referenceSymbols);
                    data.receiverRuntimeSec(row) = NaN;
                    data.estimatedFrameCfoBins(row) = ...
                        branch.bootstrap.epsilonHatBins;
                    if methodIndex == 3
                        data.explicitMidambleAcceptedCount(row) = ...
                            sum(branch.explicitMidambleAccepted);
                    end
                end
                frameCounter = frameCounter+1;
                if isfinite(options.ProgressEveryFrames) && ...
                        options.ProgressEveryFrames > 0 && ...
                        mod(frameCounter,options.ProgressEveryFrames) == 0
                    fprintf('Fuxian three-method replay: %d/%d frames.\n', ...
                        frameCounter,physicalFrameCount);
                end
            end
        end
    end
end

records = struct2table(localTrim(data,row));
if height(records) ~= physicalFrameCount*methodCount || ...
        any(records.symbolCount ~= experiment.config.payloadSymbolCount)
    error('FuxianDuibi:IncompleteReplay', ...
        'The three-method replay did not complete its ledger.');
end
csvFile = fullfile(resultDir,'fuxian_three_method_frame_records.csv');
matFile = fullfile(resultDir,'fuxian_three_method_replay.mat');
writetable(records,csvFile);
comparisonPolicy = [ ...
    'Common 122-symbol physical frame, orbit, SNR, payload/noise seeds, ' ...
    'continuous phase and ML-soft Hamming; paper branch alone observes ' ...
    'the two explicit midambles; paper receiver version=' ...
    char(options.PaperReceiverVersion)];
save(matFile,'experiment','config','schedule','segments','options', ...
    'records','comparisonPolicy');
report = struct('resultDir',resultDir,'records',records, ...
    'csvFile',csvFile,'matFile',matFile,'experiment',experiment, ...
    'config',config,'schedule',schedule,'segments',segments, ...
    'options',options,'comparisonPolicy',comparisonPolicy);
fprintf('Fuxian three-method replay complete: %s\n',resultDir);
end

function localAssertCommonBootstrap(huang,senlora,paper)
values = [huang.bootstrap.epsilonHatBins, ...
    senlora.commonBootstrap.epsilonHatBins, ...
    paper.bootstrap.epsilonHatBins];
if any(abs(values-values(1)) > 1e-12)
    error('FuxianDuibi:BootstrapMismatch', ...
        'The three methods do not share one bootstrap estimate.');
end
end

function data = localPreallocate(count)
numericFields = {'snrDb','passIndex','segmentIndex','frameIndex', ...
    'frameCenterTimeSec','driftBinsPerFrame','payloadSeed','noiseSeed', ...
    'symbolCount','symbolErrors','bitCount','hardBitErrors', ...
    'deliveredBitErrors','cfoSseBins','cfoSampleCount', ...
    'acceptedVirtualPilots','falseAcceptedVirtualPilots', ...
    'receiverRuntimeSec','estimatedFrameCfoBins', ...
    'explicitMidambleAcceptedCount'};
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
