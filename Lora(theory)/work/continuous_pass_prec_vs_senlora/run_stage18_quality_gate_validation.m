function report = run_stage18_quality_gate_validation(options)
%RUN_STAGE18_QUALITY_GATE_VALIDATION Independent pilot-quality validation.
%   This runner does not compute BER.  It validates the fixed, SNR-
%   independent SenLoRa quality gate on seeds not used to select it.

arguments
    options.SnrGridDb (:,1) double = (-24:2:-14).'
    options.FrameCount (1,1) double {mustBeInteger,mustBePositive} = 32
    options.SymbolSeedBase (1,1) double = 2026082900
    options.NoiseSeedBase (1,1) double = 2026083000
    options.OutputFolderName (1,:) char = 'stage18_quality_gate_validation_final'
end

root = fileparts(mfilename('fullpath'));
resultDir = fullfile(root,'results',options.OutputFolderName);
if ~isfolder(resultDir)
    mkdir(resultDir);
end
config = satelliteFig3Config();
[window,~] = satelliteFig3VisibilityWindow(config);
scenarioKeys = {'high_doppler_shift','high_doppler_rate'};
scenarioTitles = {'High Doppler shift','High Doppler rate'};
startTimes = [-window.deltaTimeOutSec,window.deltaTimeInSec];
scenarioCount = numel(scenarioKeys);
snrCount = numel(options.SnrGridDb);
known = zeros(config.bootstrapPilotCount,1);
payloadCount = config.payloadSymbolCount;

acceptedCount = zeros(scenarioCount,snrCount);
falseAcceptedCount = zeros(scenarioCount,snrCount);
noPilotFrames = zeros(scenarioCount,snrCount);
maximumGapSum = zeros(scenarioCount,snrCount);
lastPilotSum = zeros(scenarioCount,snrCount);
measurementErrors = cell(scenarioCount,snrCount);
staticPredictionSse = zeros(scenarioCount,snrCount);
qualityPredictionSse = zeros(scenarioCount,snrCount);
staticSecondHalfSse = zeros(scenarioCount,snrCount);
qualitySecondHalfSse = zeros(scenarioCount,snrCount);
commonNoiseMaxDifference = 0;

for snrIndex = 1:snrCount
    for frame = 1:options.FrameCount
        symbolSeed = options.SymbolSeedBase+1000*snrIndex+frame;
        noiseSeed = options.NoiseSeedBase+1000*snrIndex+frame;
        payload = satelliteFig3GeneratePayload(config,symbolSeed);
        labels = [known;payload.symbolBins];
        payloadRows = config.bootstrapPilotCount+1:numel(labels);
        secondHalfRows = payloadRows(floor(payloadCount/2)+1:end);
        noiseReference = [];
        for scenario = 1:scenarioCount
            [rx,tx,truth] = generateContinuousSatelliteFrame(labels,config, ...
                StartTimeSec=startTimes(scenario), ...
                SampleSnrDb=options.SnrGridDb(snrIndex), ...
                NoiseSeed=noiseSeed);
            channelNoise = rx-tx.*exp(1i*truth.phaseRad);
            if scenario == 1
                noiseReference = channelNoise;
            else
                commonNoiseMaxDifference = max(commonNoiseMaxDifference, ...
                    max(abs(channelNoise-noiseReference),[],'all'));
            end

            staticTracker = satelliteFig3RollingPilotTracker(rx,config,known);
            quality = satelliteFig3QualityGatedSenLoRaDecode(rx,config,known);
            tracker = quality.tracker;
            truthCfoBins = truth.trueDopplerHz/config.fftBinSpacingHz;
            staticError = staticTracker.predictedCfoBins-truthCfoBins;
            qualityError = tracker.predictedCfoBins-truthCfoBins;
            staticPredictionSse(scenario,snrIndex) = ...
                staticPredictionSse(scenario,snrIndex)+ ...
                sum(staticError(payloadRows).^2);
            qualityPredictionSse(scenario,snrIndex) = ...
                qualityPredictionSse(scenario,snrIndex)+ ...
                sum(qualityError(payloadRows).^2);
            staticSecondHalfSse(scenario,snrIndex) = ...
                staticSecondHalfSse(scenario,snrIndex)+ ...
                sum(staticError(secondHalfRows).^2);
            qualitySecondHalfSse(scenario,snrIndex) = ...
                qualitySecondHalfSse(scenario,snrIndex)+ ...
                sum(qualityError(secondHalfRows).^2);

            mask = tracker.pilotAccepted(payloadRows);
            acceptedRows = payloadRows(mask);
            wrong = tracker.detectedWaveformBins(acceptedRows) ~= ...
                labels(acceptedRows);
            acceptedCount(scenario,snrIndex) = ...
                acceptedCount(scenario,snrIndex)+sum(mask);
            falseAcceptedCount(scenario,snrIndex) = ...
                falseAcceptedCount(scenario,snrIndex)+sum(wrong);
            measurementErrors{scenario,snrIndex} = [ ...
                measurementErrors{scenario,snrIndex}; ...
                tracker.measuredCfoBins(acceptedRows)- ...
                truthCfoBins(acceptedRows)];

            positions = find(mask);
            if isempty(positions)
                noPilotFrames(scenario,snrIndex) = ...
                    noPilotFrames(scenario,snrIndex)+1;
                maximumGap = payloadCount;
                lastPosition = 0;
            else
                maximumGap = max(diff([0;positions;payloadCount+1])-1);
                lastPosition = positions(end);
            end
            maximumGapSum(scenario,snrIndex) = ...
                maximumGapSum(scenario,snrIndex)+maximumGap;
            lastPilotSum(scenario,snrIndex) = ...
                lastPilotSum(scenario,snrIndex)+lastPosition;
        end
    end
end

precision = 1-falseAcceptedCount./acceptedCount;
precision(acceptedCount == 0) = NaN;
falsePilotUpper95 = nan(size(acceptedCount));
zeroFalse = acceptedCount > 0 & falseAcceptedCount == 0;
falsePilotUpper95(zeroFalse) = ...
    1-0.05.^(1./acceptedCount(zeroFalse));
measurementRmse = nan(size(acceptedCount));
measurementP95 = nan(size(acceptedCount));
for scenario = 1:scenarioCount
    for snrIndex = 1:snrCount
        values = measurementErrors{scenario,snrIndex};
        if isempty(values)
            continue
        end
        measurementRmse(scenario,snrIndex) = sqrt(mean(values.^2));
        measurementP95(scenario,snrIndex) = ...
            localPercentile(abs(values),95);
    end
end
sampleCount = options.FrameCount*payloadCount;
secondHalfCount = options.FrameCount*(payloadCount-floor(payloadCount/2));
staticRmse = sqrt(staticPredictionSse/sampleCount);
qualityRmse = sqrt(qualityPredictionSse/sampleCount);
staticSecondRmse = sqrt(staticSecondHalfSse/secondHalfCount);
qualitySecondRmse = sqrt(qualitySecondHalfSse/secondHalfCount);

rowCount = scenarioCount*snrCount;
scenarioColumn = cell(rowCount,1);
snrColumn = zeros(rowCount,1);
acceptedColumn = zeros(rowCount,1);
falseColumn = zeros(rowCount,1);
precisionColumn = nan(rowCount,1);
upperColumn = nan(rowCount,1);
measurementRmseColumn = nan(rowCount,1);
measurementP95Column = nan(rowCount,1);
noPilotColumn = zeros(rowCount,1);
meanGapColumn = zeros(rowCount,1);
meanLastColumn = zeros(rowCount,1);
staticRmseColumn = zeros(rowCount,1);
qualityRmseColumn = zeros(rowCount,1);
staticSecondColumn = zeros(rowCount,1);
qualitySecondColumn = zeros(rowCount,1);
row = 0;
for scenario = 1:scenarioCount
    for snrIndex = 1:snrCount
        row = row+1;
        scenarioColumn{row} = scenarioKeys{scenario};
        snrColumn(row) = options.SnrGridDb(snrIndex);
        acceptedColumn(row) = acceptedCount(scenario,snrIndex);
        falseColumn(row) = falseAcceptedCount(scenario,snrIndex);
        precisionColumn(row) = precision(scenario,snrIndex);
        upperColumn(row) = falsePilotUpper95(scenario,snrIndex);
        measurementRmseColumn(row) = measurementRmse(scenario,snrIndex);
        measurementP95Column(row) = measurementP95(scenario,snrIndex);
        noPilotColumn(row) = noPilotFrames(scenario,snrIndex);
        meanGapColumn(row) = ...
            maximumGapSum(scenario,snrIndex)/options.FrameCount;
        meanLastColumn(row) = ...
            lastPilotSum(scenario,snrIndex)/options.FrameCount;
        staticRmseColumn(row) = staticRmse(scenario,snrIndex);
        qualityRmseColumn(row) = qualityRmse(scenario,snrIndex);
        staticSecondColumn(row) = staticSecondRmse(scenario,snrIndex);
        qualitySecondColumn(row) = qualitySecondRmse(scenario,snrIndex);
    end
end

validationTable = table(scenarioColumn,snrColumn,acceptedColumn, ...
    acceptedColumn/options.FrameCount,falseColumn,precisionColumn,upperColumn, ...
    measurementRmseColumn,measurementP95Column,noPilotColumn, ...
    meanGapColumn,meanLastColumn,staticRmseColumn,qualityRmseColumn, ...
    staticSecondColumn,qualitySecondColumn, ...
    'VariableNames',{'scenario','snrDb','acceptedCount', ...
    'acceptedPerFrame','falseAcceptedCount','precision', ...
    'zeroFalseUpper95','measurementRmseBins','measurementP95Bins', ...
    'framesWithoutPilot','meanMaximumGap','meanLastPilot', ...
    'staticPredictionRmse','qualityPredictionRmse', ...
    'staticSecondHalfRmse','qualitySecondHalfRmse'});
writetable(validationTable,fullfile(resultDir,'quality_gate_validation.csv'));

fig = figure('Visible','off','Color','w','Position',[70 40 1480 1030]);
tiledlayout(3,2,'TileSpacing','compact','Padding','compact');
for scenario = 1:scenarioCount
    rows = (scenario-1)*snrCount+(1:snrCount);
    nexttile(scenario);
    plot(options.SnrGridDb, ...
        validationTable.acceptedPerFrame(rows),'o-', ...
        'LineWidth',1.4,'MarkerSize',6);
    grid on;
    ylabel('Accepted pilots / frame');
    title(scenarioTitles{scenario});

    nexttile(2+scenario);
    plot(options.SnrGridDb,validationTable.precision(rows),'s-', ...
        'LineWidth',1.4,'MarkerSize',6);
    grid on;
    ylim([0 1.05]);
    ylabel('Accepted-pilot precision');

    nexttile(4+scenario);
    semilogy(options.SnrGridDb, ...
        validationTable.staticPredictionRmse(rows),'o--', ...
        'LineWidth',1.3,'MarkerSize',6);
    hold on;
    semilogy(options.SnrGridDb, ...
        validationTable.qualityPredictionRmse(rows),'s-', ...
        'LineWidth',1.4,'MarkerSize',6);
    grid on;
    xlabel('Sample SNR (dB)');
    ylabel('CFO prediction RMSE (bins)');
    legend('Static 8-preamble','Quality-gated SenLoRa','Location','best');
end
sgtitle(sprintf(['Independent quality-gate validation: ratio >= %.2f, ' ...
    '%d frames/point'],config.senloraMinimumMarginRatio,options.FrameCount));
imagePath = fullfile(resultDir,'quality_gate_validation.png');
exportgraphics(fig,imagePath,'Resolution',180);
savefig(fig,fullfile(resultDir,'quality_gate_validation.fig'));
close(fig);

save(fullfile(resultDir,'quality_gate_validation.mat'), ...
    'config','options','scenarioKeys','startTimes','acceptedCount', ...
    'falseAcceptedCount','precision','falsePilotUpper95', ...
    'measurementErrors','measurementRmse','measurementP95', ...
    'staticRmse','qualityRmse','staticSecondRmse','qualitySecondRmse', ...
    'validationTable','commonNoiseMaxDifference');
report = struct('resultDir',resultDir,'imagePath',imagePath, ...
    'table',validationTable,'acceptedCount',acceptedCount, ...
    'falseAcceptedCount',falseAcceptedCount,'precision',precision, ...
    'falsePilotUpper95',falsePilotUpper95, ...
    'commonNoiseMaxDifference',commonNoiseMaxDifference);
fprintf('Stage 18 quality-gate validation: %s\n',resultDir);
fprintf('Accepted pilots: %d; false: %d; noise mismatch %.3g.\n', ...
    sum(acceptedCount,'all'),sum(falseAcceptedCount,'all'), ...
    commonNoiseMaxDifference);
end

function value = localPercentile(samples,percent)
samples = sort(samples(:));
position = 1+(numel(samples)-1)*percent/100;
lowerIndex = floor(position);
upperIndex = ceil(position);
weight = position-lowerIndex;
value = (1-weight)*samples(lowerIndex)+weight*samples(upperIndex);
end
