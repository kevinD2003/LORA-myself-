function report = run_stage15_two_scenario_ber_smoke(options)
%RUN_STAGE15_TWO_SCENARIO_BER_SMOKE Common-random-number BER wiring check.
%   This fixed-frame experiment validates both orbit scenes and all receiver
%   arms before the checkpointed error-target BER run.  It is not a formal
%   performance result and applies no fitted smoothing.

arguments
    options.SnrGridDb (:,1) double = (-24:2:-14).'
    options.FrameCount (1,1) double {mustBeInteger,mustBePositive} = 4
    options.SymbolSeedBase (1,1) double = 2026081700
    options.NoiseSeedBase (1,1) double = 2026081800
    options.OutputFolderName (1,:) char = 'stage15_two_scenario_ber_smoke'
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
methodNames = {'AWGN Monte Carlo','Ideal samplewise compensation', ...
    'Doppler, no compensation','Static 8-preamble', ...
    'Hard PREC rolling-8','Trusted SenLoRa rolling-8'};
methodCount = numel(methodNames);
scenarioCount = numel(scenarioKeys);
snrCount = numel(options.SnrGridDb);

errors = zeros(scenarioCount,snrCount,methodCount);
bits = zeros(scenarioCount,snrCount);
hardAccepted = zeros(scenarioCount,snrCount);
hardFalseAccepted = zeros(scenarioCount,snrCount);
senAccepted = zeros(scenarioCount,snrCount);
senFalseAccepted = zeros(scenarioCount,snrCount);
commonNoiseMaxDifference = 0;
known = zeros(config.bootstrapPilotCount,1);

for snrIndex = 1:snrCount
    for frame = 1:options.FrameCount
        symbolSeed = options.SymbolSeedBase+1000*snrIndex+frame;
        noiseSeed = options.NoiseSeedBase+1000*snrIndex+frame;
        payload = satelliteFig3GeneratePayload(config,symbolSeed);
        labels = [known;payload.symbolBins];
        payloadRows = config.bootstrapPilotCount+1:numel(labels);
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

            awgnSoft = satelliteFig3SenLoRaConfidence(tx+channelNoise,config);
            idealSoft = satelliteFig3SenLoRaConfidence( ...
                rx.*exp(-1i*truth.phaseRad),config);
            noCompBins = localHardBins(rx,config);
            noCompBits = satelliteFig3HardPayloadBits( ...
                noCompBins(payloadRows),config);
            staticTracker = satelliteFig3RollingPilotTracker(rx,config,known);
            staticSoft = satelliteFig3SenLoRaConfidence( ...
                staticTracker.compensatedSymbols,config);
            hardPrec = satelliteFig3HardPrecDecode(rx,config,known);
            trusted = satelliteFig3TrustedConfidenceDecode(rx,config,known);

            decoded = {awgnSoft.decodedDataBits, ...
                idealSoft.decodedDataBits,noCompBits, ...
                staticSoft.decodedDataBits,hardPrec.decodedDataBits, ...
                trusted.finalSoft.decodedDataBits};
            for method = 1:methodCount
                errors(scenario,snrIndex,method) = ...
                    errors(scenario,snrIndex,method)+ ...
                    sum(decoded{method}(:) ~= payload.dataBits(:));
            end
            bits(scenario,snrIndex) = bits(scenario,snrIndex)+ ...
                numel(payload.dataBits);

            hardMask = hardPrec.pilotAccepted(payloadRows);
            hardAccepted(scenario,snrIndex) = ...
                hardAccepted(scenario,snrIndex)+sum(hardMask);
            hardFalseAccepted(scenario,snrIndex) = ...
                hardFalseAccepted(scenario,snrIndex)+sum(hardMask & ...
                hardPrec.detectedWaveformBins(payloadRows) ~= ...
                labels(payloadRows));
            senMask = trusted.virtualPilotTracker.pilotAccepted(payloadRows);
            senAccepted(scenario,snrIndex) = ...
                senAccepted(scenario,snrIndex)+sum(senMask);
            senFalseAccepted(scenario,snrIndex) = ...
                senFalseAccepted(scenario,snrIndex)+sum(senMask & ...
                trusted.virtualPilotTracker.detectedWaveformBins(payloadRows) ~= ...
                labels(payloadRows));
        end
    end
end

bitScale = reshape(bits,scenarioCount,snrCount,1);
ber = errors./bitScale;
upper95 = -log(0.05)./bits;
shownBer = ber;
for method = 1:methodCount
    layer = shownBer(:,:,method);
    zeroMask = errors(:,:,method) == 0;
    layer(zeroMask) = upper95(zeroMask);
    shownBer(:,:,method) = layer;
end
theoryBer = satelliteFig3TheoreticalBerAwgn(config.sf,options.SnrGridDb);

rowCount = scenarioCount*snrCount;
scenarioColumn = cell(rowCount,1);
snrColumn = zeros(rowCount,1);
bitsColumn = zeros(rowCount,1);
theoryColumn = zeros(rowCount,1);
errorColumns = zeros(rowCount,methodCount);
berColumns = zeros(rowCount,methodCount);
hardAcceptedColumn = zeros(rowCount,1);
hardFalseColumn = zeros(rowCount,1);
senAcceptedColumn = zeros(rowCount,1);
senFalseColumn = zeros(rowCount,1);
row = 0;
for scenario = 1:scenarioCount
    for snrIndex = 1:snrCount
        row = row+1;
        scenarioColumn{row} = scenarioKeys{scenario};
        snrColumn(row) = options.SnrGridDb(snrIndex);
        bitsColumn(row) = bits(scenario,snrIndex);
        theoryColumn(row) = theoryBer(snrIndex);
        errorColumns(row,:) = reshape(errors(scenario,snrIndex,:),1,[]);
        berColumns(row,:) = reshape(shownBer(scenario,snrIndex,:),1,[]);
        hardAcceptedColumn(row) = hardAccepted(scenario,snrIndex);
        hardFalseColumn(row) = hardFalseAccepted(scenario,snrIndex);
        senAcceptedColumn(row) = senAccepted(scenario,snrIndex);
        senFalseColumn(row) = senFalseAccepted(scenario,snrIndex);
    end
end

resultTable = table(scenarioColumn,snrColumn,bitsColumn,theoryColumn, ...
    errorColumns(:,1),errorColumns(:,2),errorColumns(:,3), ...
    errorColumns(:,4),errorColumns(:,5),errorColumns(:,6), ...
    berColumns(:,1),berColumns(:,2),berColumns(:,3), ...
    berColumns(:,4),berColumns(:,5),berColumns(:,6), ...
    hardAcceptedColumn,hardFalseColumn,senAcceptedColumn,senFalseColumn, ...
    'VariableNames',{'scenario','snrDb','bits','berTheoryUncoded', ...
    'errAwgn','errIdeal','errNoComp','errStatic','errHardPrec','errSenLoRa', ...
    'berAwgn','berIdeal','berNoComp','berStatic','berHardPrec','berSenLoRa', ...
    'hardAccepted','hardFalseAccepted','senAccepted','senFalseAccepted'});
writetable(resultTable,fullfile(resultDir,'two_scenario_ber_smoke.csv'));

fig = figure('Visible','off','Color','w','Position',[70 70 1480 650]);
tiledlayout(1,2,'TileSpacing','compact','Padding','compact');
styles = {'o-','s-','d-','^-','v-','p-'};
for scenario = 1:scenarioCount
    nexttile;
    semilogy(options.SnrGridDb,max(theoryBer,realmin),'k--', ...
        'LineWidth',1.4);
    hold on;
    for method = 1:methodCount
        semilogy(options.SnrGridDb, ...
            reshape(shownBer(scenario,:,method),[],1),styles{method}, ...
            'LineWidth',1.15,'MarkerSize',5);
    end
    grid on;
    ylim([1e-4 1]);
    xlabel('Sample SNR (dB)');
    ylabel('Decoded payload BER');
    title(sprintf('%s: %d frames/point', ...
        scenarioTitles{scenario},options.FrameCount));
    legend([{'Uncoded orthogonal-CSS theory'},methodNames], ...
        'Location','southwest','FontSize',8);
end
sgtitle('Two-scenario BER smoke: raw Monte Carlo and 95% zero-error bounds');
imagePath = fullfile(resultDir,'two_scenario_ber_smoke.png');
exportgraphics(fig,imagePath,'Resolution',180);
savefig(fig,fullfile(resultDir,'two_scenario_ber_smoke.fig'));
close(fig);

save(fullfile(resultDir,'two_scenario_ber_smoke.mat'), ...
    'config','options','scenarioKeys','startTimes','methodNames', ...
    'errors','bits','ber','shownBer','upper95','theoryBer', ...
    'hardAccepted','hardFalseAccepted','senAccepted','senFalseAccepted', ...
    'commonNoiseMaxDifference','resultTable');
report = struct('resultDir',resultDir,'imagePath',imagePath, ...
    'table',resultTable,'errors',errors,'bits',bits,'ber',ber, ...
    'shownBer',shownBer,'theoryBer',theoryBer, ...
    'commonNoiseMaxDifference',commonNoiseMaxDifference);
fprintf('Stage 15 two-scenario BER smoke: %s\n',resultDir);
fprintf('Maximum cross-scenario noise mismatch: %.3g\n', ...
    commonNoiseMaxDifference);
end

function bins = localHardBins(symbols,config)
bins = zeros(size(symbols,1),1);
for symbol = 1:size(symbols,1)
    decision = satelliteFig3HardDecision(symbols(symbol,:),config);
    bins(symbol) = decision.waveformBin;
end
end
