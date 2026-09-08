function report = run_stage41_ideal_sample_audit(options)
%RUN_STAGE41_IDEAL_SAMPLE_AUDIT Same-seed ideal compensation error count.

arguments
    options.SnrDb (1,1) double = -20
    options.FrameCount (1,1) double {mustBeInteger,mustBePositive} = 546
    options.SymbolSeedBase (1,1) double = 2027199100
    options.NoiseSeedBase (1,1) double = 2027199200
    options.OutputFolderName (1,:) char = 'stage41_ideal_sample_audit'
end

root = fileparts(mfilename('fullpath'));
resultDir = fullfile(root,'results',options.OutputFolderName);
if ~isfolder(resultDir), mkdir(resultDir); end
config = satelliteFig3Config();
[window,~] = satelliteFig3VisibilityWindow(config);
starts = [-window.deltaTimeOutSec,window.deltaTimeInSec];
scenario = {'high_doppler_shift';'high_doppler_rate'};
known = zeros(config.bootstrapPilotCount,1);
idealErrors = zeros(2,1);
bits = zeros(2,1);

for frame = 1:options.FrameCount
    symbolSeed = options.SymbolSeedBase+1000+frame;
    noiseSeed = options.NoiseSeedBase+1000+frame;
    payload = satelliteFig3GeneratePayload(config,symbolSeed);
    labels = [known;payload.symbolBins];
    payloadRows = config.bootstrapPilotCount+1:numel(labels);
    for scene = 1:2
        [rx,~,truth] = generateContinuousSatelliteFrame(labels,config, ...
            StartTimeSec=starts(scene),SampleSnrDb=options.SnrDb, ...
            NoiseSeed=noiseSeed);
        idealBins = localHardBins(rx.*exp(-1i*truth.phaseRad),config);
        decoded = satelliteFig3HardPayloadBits(idealBins(payloadRows),config);
        idealErrors(scene) = idealErrors(scene)+ ...
            sum(decoded(:) ~= payload.dataBits(:));
        bits(scene) = bits(scene)+numel(payload.dataBits);
    end
end

idealBer = idealErrors./bits;
[theoryBer,~] = satelliteFig3TheoreticalHammingBerAwgn(config.sf,options.SnrDb);
theoryBer = repmat(theoryBer,2,1);
[~,lower95,upper95] = satelliteFig3BerInterval95(idealErrors,bits);
tableOut = table(scenario,bits,idealErrors,idealBer,lower95,upper95,theoryBer);
writetable(tableOut,fullfile(resultDir,'ideal_sample_audit.csv'));
save(fullfile(resultDir,'ideal_sample_audit.mat'),'tableOut','options','config');
report = struct('table',tableOut,'resultDir',resultDir);
fprintf('Stage 41 ideal-sample audit: %s\n',resultDir);
end

function bins = localHardBins(symbols,config)
bins = zeros(size(symbols,1),1);
for row = 1:size(symbols,1)
    decision = satelliteFig3HardDecision(symbols(row,:),config);
    bins(row) = decision.waveformBin;
end
end
