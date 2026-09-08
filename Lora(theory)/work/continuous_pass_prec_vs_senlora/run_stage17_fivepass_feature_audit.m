function report = run_stage17_fivepass_feature_audit(options)
%RUN_STAGE17_FIVEPASS_FEATURE_AUDIT Inspect accepted-pilot feature separation.
%   The paper-like five-pass route runs without its estimated-SNR safety
%   gate.  Transmitted labels are consulted only after receiver processing
%   to label accepted virtual pilots as correct or wrong.

arguments
    options.SnrGridDb (:,1) double = (-24:2:-14).'
    options.FrameCount (1,1) double {mustBeInteger,mustBePositive} = 16
    options.SymbolSeedBase (1,1) double = 2026082400
    options.NoiseSeedBase (1,1) double = 2026082500
    options.OutputFolderName (1,:) char = 'stage17_fivepass_feature_audit'
end

root = fileparts(mfilename('fullpath'));
resultDir = fullfile(root,'results',options.OutputFolderName);
if ~isfolder(resultDir)
    mkdir(resultDir);
end
config = satelliteFig3Config();
[window,~] = satelliteFig3VisibilityWindow(config);
scenarioKeys = {'high_doppler_shift','high_doppler_rate'};
startTimes = [-window.deltaTimeOutSec,window.deltaTimeInSec];
known = zeros(config.bootstrapPilotCount,1);
samples = localEmptyTable();
commonNoiseMaxDifference = 0;

for snrIndex = 1:numel(options.SnrGridDb)
    for frame = 1:options.FrameCount
        symbolSeed = options.SymbolSeedBase+1000*snrIndex+frame;
        noiseSeed = options.NoiseSeedBase+1000*snrIndex+frame;
        payload = satelliteFig3GeneratePayload(config,symbolSeed);
        labels = [known;payload.symbolBins];
        payloadRows = config.bootstrapPilotCount+1:numel(labels);
        noiseReference = [];
        for scenario = 1:numel(scenarioKeys)
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

            decoded = satelliteFig3SenLoRaIterativeDecode( ...
                rx,config,known,UseEstimatedSnrGate=false);
            tracker = decoded.tracker;
            acceptedRows = payloadRows(tracker.pilotAccepted(payloadRows));
            if isempty(acceptedRows)
                continue
            end
            if numel(decoded.iterationHistory) >= 2
                sourceSoft = decoded.iterationHistory(end-1).soft;
            else
                sourceSoft = decoded.soft;
            end
            tau = sourceSoft.tauGlobal(acceptedRows);
            margin = sourceSoft.symbolCodewordMargin(acceptedRows);
            confidence = sourceSoft.confidence(acceptedRows);
            truthCfoBins = truth.trueDopplerHz/config.fftBinSpacingHz;
            count = numel(acceptedRows);
            block = table( ...
                repmat(scenarioKeys(scenario),count,1), ...
                repmat(options.SnrGridDb(snrIndex),count,1), ...
                repmat(frame,count,1), ...
                acceptedRows(:)-config.bootstrapPilotCount, ...
                tracker.detectedWaveformBins(acceptedRows), ...
                labels(acceptedRows), ...
                tracker.detectedWaveformBins(acceptedRows) == labels(acceptedRows), ...
                margin,margin./max(tau,eps), ...
                confidence./max(tau,eps), ...
                tracker.peakRatio(acceptedRows), ...
                tracker.residualPeakRatio(acceptedRows), ...
                tracker.measuredResidualBins(acceptedRows), ...
                tracker.residualPeakAtBoundary(acceptedRows), ...
                sourceSoft.decodedWaveformBins(acceptedRows) == ...
                    tracker.hardWaveformBins(acceptedRows), ...
                tracker.measuredCfoBins(acceptedRows)-truthCfoBins(acceptedRows), ...
                repmat(decoded.iterations,count,1), ...
                repmat(decoded.estimatedSnrDb,count,1), ...
                'VariableNames',samples.Properties.VariableNames);
            samples = [samples;block]; %#ok<AGROW>
        end
    end
end

writetable(samples,fullfile(resultDir,'fivepass_accepted_pilot_samples.csv'));
thresholds = [0;0.02;0.05;0.1;0.2;0.5;1;2];
screening = localScreen(samples,thresholds,scenarioKeys, ...
    options.SnrGridDb,options.FrameCount,config);
writetable(screening,fullfile(resultDir,'fivepass_margin_screening.csv'));

fig = figure('Visible','off','Color','w','Position',[70 60 1480 720]);
tiledlayout(1,2,'TileSpacing','compact','Padding','compact');
for scenario = 1:numel(scenarioKeys)
    nexttile;
    rows = strcmp(samples.scenario,scenarioKeys{scenario});
    correct = rows & samples.correct;
    wrong = rows & ~samples.correct;
    scatter(samples.snrDb(correct),max(samples.marginRatio(correct),realmin), ...
        18,[0.1 0.55 0.2],'filled','MarkerFaceAlpha',0.35);
    hold on;
    scatter(samples.snrDb(wrong),max(samples.marginRatio(wrong),realmin), ...
        38,[0.85 0.15 0.1],'x','LineWidth',1.2);
    set(gca,'YScale','log');
    grid on;
    xlabel('Sample SNR (dB)');
    ylabel('Hamming margin / global confidence threshold');
    title(strrep(scenarioKeys{scenario},'_',' '));
    legend('Correct accepted pilot','Wrong accepted pilot', ...
        'Location','best');
end
sgtitle(sprintf('Ungated five-pass accepted-pilot features: %d frames/point', ...
    options.FrameCount));
imagePath = fullfile(resultDir,'fivepass_feature_separation.png');
exportgraphics(fig,imagePath,'Resolution',180);
savefig(fig,fullfile(resultDir,'fivepass_feature_separation.fig'));
close(fig);

save(fullfile(resultDir,'fivepass_feature_audit.mat'), ...
    'config','options','scenarioKeys','startTimes','samples','screening', ...
    'thresholds','commonNoiseMaxDifference');
report = struct('resultDir',resultDir,'imagePath',imagePath, ...
    'samples',samples,'screening',screening, ...
    'commonNoiseMaxDifference',commonNoiseMaxDifference);
fprintf('Stage 17 five-pass feature audit: %s\n',resultDir);
fprintf('Accepted pilots: %d correct, %d wrong. Noise mismatch %.3g.\n', ...
    sum(samples.correct),sum(~samples.correct),commonNoiseMaxDifference);
end

function samples = localEmptyTable()
samples = table(cell(0,1),zeros(0,1),zeros(0,1),zeros(0,1), ...
    zeros(0,1),zeros(0,1),false(0,1),zeros(0,1),zeros(0,1), ...
    zeros(0,1),zeros(0,1),zeros(0,1),zeros(0,1),false(0,1), ...
    false(0,1),zeros(0,1),zeros(0,1),zeros(0,1), ...
    'VariableNames',{'scenario','snrDb','frame','payloadSymbolIndex', ...
    'detectedBin','trueBin','correct','codewordMargin','marginRatio', ...
    'confidenceRatio','hardPeakRatio','residualPeakRatio','residualBins', ...
    'residualAtBoundary','softHardAgreement','measurementErrorBins', ...
    'iterations','estimatedSnrDb'});
end

function result = localScreen(samples,thresholds,scenarioKeys,snrGrid, ...
        frameCount,config)
rowCount = numel(thresholds)*numel(scenarioKeys)*numel(snrGrid);
scenario = cell(rowCount,1);
snrDb = zeros(rowCount,1);
marginRatioThreshold = zeros(rowCount,1);
acceptedCount = zeros(rowCount,1);
falseAcceptedCount = zeros(rowCount,1);
precision = nan(rowCount,1);
acceptedPerFrame = zeros(rowCount,1);
measurementRmse = nan(rowCount,1);
meanLastPilot = zeros(rowCount,1);
row = 0;
for scenarioIndex = 1:numel(scenarioKeys)
    for snrIndex = 1:numel(snrGrid)
        base = strcmp(samples.scenario,scenarioKeys{scenarioIndex}) & ...
            samples.snrDb == snrGrid(snrIndex);
        for thresholdIndex = 1:numel(thresholds)
            row = row+1;
            selected = base & ...
                samples.marginRatio >= thresholds(thresholdIndex) & ...
                samples.softHardAgreement & ...
                ~samples.residualAtBoundary & ...
                abs(samples.residualBins) <= ...
                    config.confidenceInnovationLimitBins;
            accepted = sum(selected);
            falseAccepted = sum(selected & ~samples.correct);
            scenario{row} = scenarioKeys{scenarioIndex};
            snrDb(row) = snrGrid(snrIndex);
            marginRatioThreshold(row) = thresholds(thresholdIndex);
            acceptedCount(row) = accepted;
            falseAcceptedCount(row) = falseAccepted;
            if accepted > 0
                precision(row) = 1-falseAccepted/accepted;
                measurementRmse(row) = sqrt(mean( ...
                    samples.measurementErrorBins(selected).^2));
            end
            acceptedPerFrame(row) = accepted/frameCount;
            lastPositions = zeros(frameCount,1);
            for frame = 1:frameCount
                positions = samples.payloadSymbolIndex(selected & ...
                    samples.frame == frame);
                if ~isempty(positions)
                    lastPositions(frame) = max(positions);
                end
            end
            meanLastPilot(row) = mean(lastPositions);
        end
    end
end
result = table(scenario,snrDb,marginRatioThreshold,acceptedCount, ...
    falseAcceptedCount,precision,acceptedPerFrame,measurementRmse, ...
    meanLastPilot);
end
