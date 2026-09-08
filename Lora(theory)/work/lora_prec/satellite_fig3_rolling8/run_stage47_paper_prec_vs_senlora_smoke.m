function report = run_stage47_paper_prec_vs_senlora_smoke(options)
%RUN_STAGE47_PAPER_PREC_VS_SENLORA_SMOKE Same-channel four-curve check.
%   Paper PREC and SenLoRa receive identical dynamic-Doppler samples.

arguments
    options.SnrGridDb (:,1) double = (-24:2:-16).'
    options.FrameCount (1,1) double {mustBeInteger,mustBePositive} = 4
    options.SymbolSeedBase (1,1) double = 2026111100
    options.NoiseSeedBase (1,1) double = 2026111200
    options.OutputFolderName (1,:) char = ...
        'stage47_paper_prec_vs_senlora_smoke'
end

root = fileparts(mfilename('fullpath'));
resultDir = fullfile(root,'results',options.OutputFolderName);
if ~isfolder(resultDir), mkdir(resultDir); end
config = satelliteFig3Config();
[window,~] = satelliteFig3VisibilityWindow(config);
scenarioKeys = {'high_doppler_shift','high_doppler_rate'};
scenarioTitles = {'High Doppler shift','High Doppler rate'};
startTimes = [-window.deltaTimeOutSec,window.deltaTimeInSec];
methodNames = {'Doppler, no compensation', ...
    'Paper PREC, 8 upchirps','SenLoRa rolling-8'};
sceneCount = numel(scenarioKeys);
snrCount = numel(options.SnrGridDb);
methodCount = numel(methodNames);
known = zeros(config.bootstrapPilotCount,1);

errors = zeros(sceneCount,snrCount,methodCount);
bits = zeros(sceneCount,snrCount);
paperCfoSse = zeros(sceneCount,snrCount);
paperCoherentGain = zeros(sceneCount,snrCount);
senAccepted = zeros(sceneCount,snrCount);
senFalse = zeros(sceneCount,snrCount);
commonNoiseMaxDifference = 0;
for snrIndex = 1:snrCount
    for frame = 1:options.FrameCount
        symbolSeed = options.SymbolSeedBase+1000*snrIndex+frame;
        noiseSeed = options.NoiseSeedBase+1000*snrIndex+frame;
        payload = satelliteFig3GeneratePayload(config,symbolSeed);
        labels = [known;payload.symbolBins];
        payloadRows = config.bootstrapPilotCount+1:numel(labels);
        noiseReference = [];
        for scene = 1:sceneCount
            [rx,tx,truth] = generateContinuousSatelliteFrame(labels,config, ...
                StartTimeSec=startTimes(scene), ...
                SampleSnrDb=options.SnrGridDb(snrIndex), ...
                NoiseSeed=noiseSeed);
            channelNoise = rx-tx.*exp(1i*truth.phaseRad);
            if scene == 1
                noiseReference = channelNoise;
            else
                commonNoiseMaxDifference = max(commonNoiseMaxDifference, ...
                    max(abs(channelNoise-noiseReference),[],'all'));
            end

            noCompBins = localHardBins(rx,config);
            noCompBits = satelliteFig3HardPayloadBits( ...
                noCompBins(payloadRows),config);
            paper = satelliteFig3PaperPrecDecode(rx,config,known);
            sen = satelliteFig3AdaptiveRateReplaySenLoRaDecode( ...
                rx,config,known);
            decoded = {noCompBits,paper.decodedDataBits, ...
                sen.hardDecodedDataBits};
            for method = 1:methodCount
                errors(scene,snrIndex,method) = ...
                    errors(scene,snrIndex,method)+sum( ...
                    decoded{method}(:) ~= payload.dataBits(:));
            end
            bits(scene,snrIndex) = bits(scene,snrIndex)+ ...
                numel(payload.dataBits);

            preambleTruthBins = truth.trueDopplerHz( ...
                1:config.bootstrapPilotCount,:)/config.fftBinSpacingHz;
            paperCfoSse(scene,snrIndex) = paperCfoSse(scene,snrIndex)+ ...
                (paper.epsilonHatBins-mean(preambleTruthBins,'all'))^2;
            paperCoherentGain(scene,snrIndex) = ...
                paperCoherentGain(scene,snrIndex)+paper.preambleCoherentGain;
            senMask = sen.pilotAccepted(payloadRows);
            senAccepted(scene,snrIndex) = senAccepted(scene,snrIndex)+ ...
                sum(senMask);
            senFalse(scene,snrIndex) = senFalse(scene,snrIndex)+sum( ...
                senMask & sen.detectedWaveformBins(payloadRows) ~= ...
                labels(payloadRows));
        end
    end
end

bitScale = repmat(reshape(bits,sceneCount,snrCount,1),1,1,methodCount);
[shownBer,lower95,upper95] = satelliteFig3BerInterval95(errors,bitScale);
rawBer = errors./bitScale;
[theoryBer,theoryUncodedBer] = satelliteFig3TheoreticalHammingBerAwgn( ...
    config.sf,options.SnrGridDb);
paperCfoRmseBins = sqrt(paperCfoSse/options.FrameCount);
paperMeanCoherentGain = paperCoherentGain/options.FrameCount;

rowCount = sceneCount*snrCount;
scenario = cell(rowCount,1); snrDb = zeros(rowCount,1);
bitCount = zeros(rowCount,1); theory = zeros(rowCount,1);
err = zeros(rowCount,methodCount); ber = err; lo = err; hi = err;
paperRmse = zeros(rowCount,1); coherentGain = paperRmse;
accepted = paperRmse; falseAccepted = paperRmse;
row = 0;
for scene = 1:sceneCount
    for snrIndex = 1:snrCount
        row = row+1;
        scenario{row} = scenarioKeys{scene};
        snrDb(row) = options.SnrGridDb(snrIndex);
        bitCount(row) = bits(scene,snrIndex);
        theory(row) = theoryBer(snrIndex);
        err(row,:) = reshape(errors(scene,snrIndex,:),1,[]);
        ber(row,:) = reshape(shownBer(scene,snrIndex,:),1,[]);
        lo(row,:) = reshape(lower95(scene,snrIndex,:),1,[]);
        hi(row,:) = reshape(upper95(scene,snrIndex,:),1,[]);
        paperRmse(row) = paperCfoRmseBins(scene,snrIndex);
        coherentGain(row) = paperMeanCoherentGain(scene,snrIndex);
        accepted(row) = senAccepted(scene,snrIndex);
        falseAccepted(row) = senFalse(scene,snrIndex);
    end
end
resultTable = table(scenario,snrDb,bitCount,theory, ...
    err(:,1),err(:,2),err(:,3),ber(:,1),ber(:,2),ber(:,3), ...
    lo(:,1),lo(:,2),lo(:,3),hi(:,1),hi(:,2),hi(:,3), ...
    paperRmse,coherentGain,accepted,falseAccepted, ...
    'VariableNames',{'scenario','snrDb','bits','berTheoryHamming', ...
    'errNoComp','errPaperPrec','errSenLoRa', ...
    'berNoComp','berPaperPrec','berSenLoRa', ...
    'lower95NoComp','lower95PaperPrec','lower95SenLoRa', ...
    'upper95NoComp','upper95PaperPrec','upper95SenLoRa', ...
    'paperCfoRmseBins','paperPreambleCoherentGain', ...
    'senAccepted','senFalseAccepted'});
writetable(resultTable,fullfile(resultDir,'paper_prec_vs_senlora_smoke.csv'));

fig = figure('Visible','off','Color','w','Position',[60 60 1450 640]);
tiledlayout(1,2,'TileSpacing','compact','Padding','compact');
styles = {'s-.','x--','o-'};
colors = [0.90 0.00 0.90;0.20 0.65 0.90;1.00 0.15 0.05];
for scene = 1:sceneCount
    ax = nexttile;
    semilogy(options.SnrGridDb,max(theoryBer,realmin),'k--', ...
        'LineWidth',1.7,'DisplayName','Theoretical AWGN, Hamming(7,4)');
    hold on;
    for method = 1:methodCount
        y = reshape(shownBer(scene,:,method),[],1);
        low = reshape(lower95(scene,:,method),[],1);
        high = reshape(upper95(scene,:,method),[],1);
        errorbar(options.SnrGridDb,y,y-max(low,1e-6),high-y, ...
            styles{method},'Color',colors(method,:),'LineWidth',1.25, ...
            'MarkerSize',5.5,'MarkerFaceColor','none','CapSize',3, ...
            'DisplayName',methodNames{method});
    end
    grid on; grid minor; ylim([1e-6 1]);
    if snrCount == 1
        xlim(options.SnrGridDb+[-0.5;0.5]);
    else
        xlim([min(options.SnrGridDb),max(options.SnrGridDb)]);
    end
    xlabel('Sample SNR (dB)','FontWeight','bold');
    ylabel('Decoded payload BER','FontWeight','bold');
    title(sprintf('%s: %d frames/point', ...
        scenarioTitles{scene},options.FrameCount),'FontWeight','normal');
    legend('Location','southwest','FontSize',8,'Box','on');
    set(ax,'FontName','Times New Roman','FontSize',11, ...
        'GridLineStyle',':','MinorGridLineStyle',':','Box','on');
end
sgtitle('Same dynamic Doppler: thesis PREC versus SenLoRa rolling-8', ...
    'FontName','Times New Roman','FontWeight','normal');
imagePath = fullfile(resultDir,'paper_prec_vs_senlora_smoke.png');
exportgraphics(fig,imagePath,'Resolution',180);
savefig(fig,fullfile(resultDir,'paper_prec_vs_senlora_smoke.fig'));
close(fig);
save(fullfile(resultDir,'paper_prec_vs_senlora_smoke.mat'), ...
    'config','options','scenarioKeys','startTimes','methodNames', ...
    'errors','bits','rawBer','shownBer','lower95','upper95', ...
    'theoryBer','theoryUncodedBer','paperCfoRmseBins', ...
    'paperMeanCoherentGain','senAccepted','senFalse', ...
    'commonNoiseMaxDifference','resultTable');
report = struct('resultDir',resultDir,'imagePath',imagePath, ...
    'table',resultTable,'errors',errors,'bits',bits, ...
    'paperCfoRmseBins',paperCfoRmseBins, ...
    'commonNoiseMaxDifference',commonNoiseMaxDifference);
fprintf('Stage 47 paper-PREC/SenLoRa smoke: %s\n',resultDir);
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
