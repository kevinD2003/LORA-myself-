function report = run_stage39_phase_layer_audit(options)
%RUN_STAGE39_PHASE_LAYER_AUDIT Locate apparent below-theory performance.

arguments
    options.SnrDb (1,1) double = -20
    options.FrameCount (1,1) double {mustBeInteger,mustBePositive} = 64
    options.SymbolSeedBase (1,1) double = 2027199100
    options.NoiseSeedBase (1,1) double = 2027199200
    options.OutputFolderName (1,:) char = 'stage39_phase_layer_audit'
end

root = fileparts(mfilename('fullpath'));
resultDir = fullfile(root,'results',options.OutputFolderName);
if ~isfolder(resultDir), mkdir(resultDir); end
config = satelliteFig3Config();
[window,~] = satelliteFig3VisibilityWindow(config);
starts = [-window.deltaTimeOutSec,window.deltaTimeInSec];
names = {'high_doppler_shift','high_doppler_rate'};
known = zeros(config.bootstrapPilotCount,1);
counts = zeros(2,7);
gainSum = zeros(2,1);
gainMin = ones(2,1);
gainCount = zeros(2,1);

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
        idealBits = satelliteFig3HardPayloadBits(idealBins(payloadRows),config);
        sen = satelliteFig3AdaptiveRateReplaySenLoRaDecode(rx,config,known);
        firstTracker = sen.iterationHistory(1).tracker;
        firstBits = satelliteFig3HardPayloadBits( ...
            firstTracker.hardWaveformBins(payloadRows),config);
        finalBits = sen.hardDecodedDataBits;
        idealError = idealBits(:) ~= payload.dataBits(:);
        firstError = firstBits(:) ~= payload.dataBits(:);
        finalError = finalBits(:) ~= payload.dataBits(:);
        counts(scene,:) = counts(scene,:)+[numel(idealError), ...
            sum(idealError),sum(firstError),sum(finalError), ...
            sum(idealError & finalError), ...
            sum(idealError & ~finalError), ...
            sum(~idealError & finalError)];
        gain = localCoherentGain(sen.tracker,truth,config,payloadRows);
        gainSum(scene) = gainSum(scene)+sum(gain);
        gainCount(scene) = gainCount(scene)+numel(gain);
        gainMin(scene) = min(gainMin(scene),min(gain));
    end
end

scenario = names.';
bits = counts(:,1);
idealErrors = counts(:,2);
orbitPriorFirstPassErrors = counts(:,3);
senLoRaFinalErrors = counts(:,4);
bothIdealAndSenErrors = counts(:,5);
idealOnlyErrors = counts(:,6);
senOnlyErrors = counts(:,7);
idealBer = idealErrors./bits;
orbitPriorFirstPassBer = orbitPriorFirstPassErrors./bits;
senLoRaFinalBer = senLoRaFinalErrors./bits;
meanCoherentGain = gainSum./gainCount;
minimumCoherentGain = gainMin;
tableOut = table(scenario,bits,idealErrors,orbitPriorFirstPassErrors, ...
    senLoRaFinalErrors,bothIdealAndSenErrors,idealOnlyErrors,senOnlyErrors, ...
    idealBer,orbitPriorFirstPassBer,senLoRaFinalBer, ...
    meanCoherentGain,minimumCoherentGain);
writetable(tableOut,fullfile(resultDir,'phase_layer_audit.csv'));
save(fullfile(resultDir,'phase_layer_audit.mat'),'tableOut','options','config');
report = struct('table',tableOut,'resultDir',resultDir);
fprintf('Stage 39 phase-layer audit: %s\n',resultDir);
end

function bins = localHardBins(symbols,config)
bins = zeros(size(symbols,1),1);
for row = 1:size(symbols,1)
    decision = satelliteFig3HardDecision(symbols(row,:),config);
    bins(row) = decision.waveformBin;
end
end

function gain = localCoherentGain(tracker,truth,config,rows)
m = config.samplesPerSymbol;
sampleTime = (0:m-1)/config.sampleRateHz;
duration = config.symbolDurationSec;
gain = zeros(numel(rows),1);
for index = 1:numel(rows)
    row = rows(index);
    center = tracker.predictedCfoBins(row);
    rate = tracker.predictedRateBinsPerSec(row);
    startCfo = center-rate*duration/2;
    predicted = tracker.predictedPhaseStartRad(row)+2*pi*( ...
        startCfo*(sampleTime/duration)+ ...
        0.5*rate*(sampleTime.^2/duration));
    residual = truth.phaseRad(row,:)-predicted;
    gain(index) = abs(mean(exp(1i*residual)));
end
end
