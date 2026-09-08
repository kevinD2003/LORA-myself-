function report = run_stage23_four_curve_ber_smoke(options)
%RUN_STAGE23_FOUR_CURVE_BER_SMOKE Validate the final BER experiment wiring.
%   The four plotted curves are the theoretical coded AWGN reference,
%   uncompensated dynamic Doppler, hard-decision PREC rolling-8, and
%   quality-gated SenLoRa rolling-8.  Both orbit scenarios reuse exactly
%   the same payload and noise realization at every SNR/frame pair.

arguments
    options.SnrGridDb (:,1) double = (-24:2:-14).'
    options.FrameCount (1,1) double {mustBeInteger,mustBePositive} = 8
    options.SymbolSeedBase (1,1) double = 2026090200
    options.NoiseSeedBase (1,1) double = 2026090300
    options.OutputFolderName (1,:) char = 'stage23_four_curve_ber_smoke'
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
methodNames = {'Doppler, no compensation', ...
    'Hard-decision PREC rolling-8','SenLoRa rolling-8'};
scenarioCount = numel(scenarioKeys);
snrCount = numel(options.SnrGridDb);
methodCount = numel(methodNames);
known = zeros(config.bootstrapPilotCount,1);

errors = zeros(scenarioCount,snrCount,methodCount);
bits = zeros(scenarioCount,snrCount);
hardAccepted = zeros(scenarioCount,snrCount);
hardFalse = zeros(scenarioCount,snrCount);
senAccepted = zeros(scenarioCount,snrCount);
senFalse = zeros(scenarioCount,snrCount);
senRateReplayTriggered = zeros(scenarioCount,snrCount);
commonNoiseMaxDifference = 0;

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

            noCompBins = localHardBins(rx,config);
            noCompBits = satelliteFig3HardPayloadBits( ...
                noCompBins(payloadRows),config);
            hard = satelliteFig3HardPrecDecode(rx,config,known);
            sen = satelliteFig3AdaptiveRateReplaySenLoRaDecode( ...
                rx,config,known);
            decoded = {noCompBits,hard.decodedDataBits, ...
                sen.hardDecodedDataBits};
            for method = 1:methodCount
                errors(scenario,snrIndex,method) = ...
                    errors(scenario,snrIndex,method)+ ...
                    sum(decoded{method}(:) ~= payload.dataBits(:));
            end
            bits(scenario,snrIndex) = bits(scenario,snrIndex)+ ...
                numel(payload.dataBits);

            hardMask = hard.pilotAccepted(payloadRows);
            hardAccepted(scenario,snrIndex) = ...
                hardAccepted(scenario,snrIndex)+sum(hardMask);
            hardFalse(scenario,snrIndex) = hardFalse(scenario,snrIndex)+ ...
                sum(hardMask & hard.detectedWaveformBins(payloadRows) ~= ...
                labels(payloadRows));
            senMask = sen.pilotAccepted(payloadRows);
            senAccepted(scenario,snrIndex) = ...
                senAccepted(scenario,snrIndex)+sum(senMask);
            senFalse(scenario,snrIndex) = senFalse(scenario,snrIndex)+ ...
                sum(senMask & sen.detectedWaveformBins(payloadRows) ~= ...
                labels(payloadRows));
            senRateReplayTriggered(scenario,snrIndex) = ...
                senRateReplayTriggered(scenario,snrIndex)+ ...
                sen.rateReplay.triggered;
        end
    end
end

bitScale = reshape(bits,scenarioCount,snrCount,1);
bitScale = repmat(bitScale,1,1,methodCount);
[shownBer,lower95,upper95] = satelliteFig3BerInterval95(errors,bitScale);
rawBer = errors./bitScale;
[theoryBer,theoryUncodedBer] = ...
    satelliteFig3TheoreticalHammingBerAwgn( ...
    config.sf,options.SnrGridDb);

rowCount = scenarioCount*snrCount;
scenarioColumn = cell(rowCount,1);
snrColumn = zeros(rowCount,1);
bitsColumn = zeros(rowCount,1);
theoryColumn = zeros(rowCount,1);
errorColumns = zeros(rowCount,methodCount);
berColumns = zeros(rowCount,methodCount);
lowerColumns = zeros(rowCount,methodCount);
upperColumns = zeros(rowCount,methodCount);
hardAcceptedColumn = zeros(rowCount,1);
hardFalseColumn = zeros(rowCount,1);
senAcceptedColumn = zeros(rowCount,1);
senFalseColumn = zeros(rowCount,1);
senReplayColumn = zeros(rowCount,1);
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
        lowerColumns(row,:) = reshape(lower95(scenario,snrIndex,:),1,[]);
        upperColumns(row,:) = reshape(upper95(scenario,snrIndex,:),1,[]);
        hardAcceptedColumn(row) = hardAccepted(scenario,snrIndex);
        hardFalseColumn(row) = hardFalse(scenario,snrIndex);
        senAcceptedColumn(row) = senAccepted(scenario,snrIndex);
        senFalseColumn(row) = senFalse(scenario,snrIndex);
        senReplayColumn(row) = ...
            senRateReplayTriggered(scenario,snrIndex);
    end
end
resultTable = table(scenarioColumn,snrColumn,bitsColumn,theoryColumn, ...
    errorColumns(:,1),errorColumns(:,2),errorColumns(:,3), ...
    berColumns(:,1),berColumns(:,2),berColumns(:,3), ...
    lowerColumns(:,1),lowerColumns(:,2),lowerColumns(:,3), ...
    upperColumns(:,1),upperColumns(:,2),upperColumns(:,3), ...
    hardAcceptedColumn,hardFalseColumn,senAcceptedColumn,senFalseColumn, ...
    senReplayColumn, ...
    'VariableNames',{'scenario','snrDb','bits','berTheoryHamming', ...
    'errNoComp','errHardPrec','errSenLoRa', ...
    'berNoComp','berHardPrec','berSenLoRa', ...
    'lower95NoComp','lower95HardPrec','lower95SenLoRa', ...
    'upper95NoComp','upper95HardPrec','upper95SenLoRa', ...
    'hardAccepted','hardFalseAccepted','senAccepted','senFalseAccepted', ...
    'senRateReplayTriggeredFrames'});
writetable(resultTable,fullfile(resultDir,'four_curve_ber_smoke.csv'));

fig = figure('Visible','off','Color','w','Position',[70 70 1480 650]);
tiledlayout(1,2,'TileSpacing','compact','Padding','compact');
styles = {'o-','s-','d-'};
colors = lines(methodCount);
for scenario = 1:scenarioCount
    nexttile;
    semilogy(options.SnrGridDb,max(theoryBer,realmin),'k--', ...
        'LineWidth',1.5, ...
        'DisplayName','Theoretical AWGN, Hamming(7,4)');
    hold on;
    for method = 1:methodCount
        y = reshape(shownBer(scenario,:,method),[],1);
        lo = reshape(lower95(scenario,:,method),[],1);
        hi = reshape(upper95(scenario,:,method),[],1);
        loPlot = max(lo,1e-6);
        errorbar(options.SnrGridDb,y,y-loPlot,hi-y,styles{method}, ...
            'Color',colors(method,:),'LineWidth',1.15,'MarkerSize',5, ...
            'CapSize',4,'DisplayName',methodNames{method});
    end
    grid on;
    ylim([1e-6 1]);
    xlabel('Sample SNR (dB)');
    ylabel('Decoded payload BER');
    title(sprintf('%s: %d frames/point', ...
        scenarioTitles{scenario},options.FrameCount));
    legend('Location','southwest','FontSize',8);
end
sgtitle('Final four-curve wiring: raw Monte Carlo with 95% intervals');
imagePath = fullfile(resultDir,'four_curve_ber_smoke.png');
exportgraphics(fig,imagePath,'Resolution',180);
savefig(fig,fullfile(resultDir,'four_curve_ber_smoke.fig'));
close(fig);

save(fullfile(resultDir,'four_curve_ber_smoke.mat'), ...
    'config','options','scenarioKeys','startTimes','methodNames', ...
    'errors','bits','rawBer','shownBer','lower95','upper95', ...
    'theoryBer','theoryUncodedBer', ...
    'hardAccepted','hardFalse','senAccepted','senFalse', ...
    'senRateReplayTriggered', ...
    'commonNoiseMaxDifference','resultTable');
report = struct('resultDir',resultDir,'imagePath',imagePath, ...
    'table',resultTable,'errors',errors,'bits',bits,'rawBer',rawBer, ...
    'shownBer',shownBer,'lower95',lower95,'upper95',upper95, ...
    'theoryBer',theoryBer, ...
    'commonNoiseMaxDifference',commonNoiseMaxDifference);
fprintf('Stage 23 four-curve BER smoke: %s\n',resultDir);
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
