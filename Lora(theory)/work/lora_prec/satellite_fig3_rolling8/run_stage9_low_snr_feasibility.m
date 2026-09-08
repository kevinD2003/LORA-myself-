function report = run_stage9_low_snr_feasibility()
%RUN_STAGE9_LOW_SNR_FEASIBILITY Does low-SNR confidence recheck help?
%   This is a fair, pre-BER feasibility experiment.  Every method receives
%   identical frame symbols, Doppler trajectory and AWGN.  Labels are used
%   only after decoding to report SER and anchor precision.

root = fileparts(mfilename('fullpath'));
resultDir = fullfile(root,'results','stage9_low_snr_feasibility');
if ~isfolder(resultDir), mkdir(resultDir); end
config = satelliteFig3Config(); [window,~] = satelliteFig3VisibilityWindow(config);
snrGrid = (-24:2:-16).'; nFrames = 12;
names = {'static8','safeLock','relaxedRecheck','blindAnchor'};
nMethod = numel(names);
summary = repmat(struct('snrDb',NaN,'method','', 'symbolErrors',0, ...
    'symbolCount',0,'ser',NaN,'anchors',0,'wrongAnchors',0), ...
    numel(snrGrid)*nMethod,1);
out = 0;
for s = 1:numel(snrGrid)
    counts = zeros(nMethod,4); % symbol errors, symbols, anchors, wrong anchors
    for frame = 1:nFrames
        seed = 2026081000 + 100*s + frame;
        payload = satelliteFig3GeneratePayload(config,seed);
        bins = [zeros(config.bootstrapPilotCount,1);payload.symbolBins];
        rx = generateContinuousSatelliteFrame(bins,config, ...
            StartTimeSec=window.deltaTimeInSec,SampleSnrDb=snrGrid(s),NoiseSeed=seed+400000);
        payloadRows = config.bootstrapPilotCount+1:numel(bins);

        base = satelliteFig3RollingPilotTracker(rx,config,zeros(config.bootstrapPilotCount,1));
        baseSoft = satelliteFig3SenLoRaConfidence(base.compensatedSymbols,config);
        counts(1,:) = counts(1,:) + [sum(baseSoft.decodedWaveformBins(payloadRows) ~= bins(payloadRows)), ...
            numel(payloadRows),0,0];

        safe = satelliteFig3TrustedConfidenceDecode(rx,config,zeros(config.bootstrapPilotCount,1));
        counts(2,:) = counts(2,:) + localCounts(safe,bins,payloadRows);

        relaxedConfig = config;
        relaxedConfig.confidencePromotionSnrDb = -30;
        [relaxedConfig.confidenceAnchorMargin,relaxedConfig.confidencePromotionMargin] = ...
            localRelaxedMargins(snrGrid(s));
        relaxed = satelliteFig3TrustedConfidenceDecode(rx,relaxedConfig,zeros(config.bootstrapPilotCount,1));
        counts(3,:) = counts(3,:) + localCounts(relaxed,bins,payloadRows);

        blindConfig = relaxedConfig;
        blindConfig.confidenceAnchorMargin = 0;
        blindConfig.confidencePromotionMargin = 0;
        blind = satelliteFig3TrustedConfidenceDecode(rx,blindConfig,zeros(config.bootstrapPilotCount,1));
        counts(4,:) = counts(4,:) + localCounts(blind,bins,payloadRows);
    end
    for method = 1:nMethod
        out = out+1;
        summary(out) = struct('snrDb',snrGrid(s),'method',names{method}, ...
            'symbolErrors',counts(method,1),'symbolCount',counts(method,2), ...
            'ser',counts(method,1)/counts(method,2),'anchors',counts(method,3), ...
            'wrongAnchors',counts(method,4));
    end
end
summaryTable = struct2table(summary);
writetable(summaryTable,fullfile(resultDir,'low_snr_feasibility.csv'));
save(fullfile(resultDir,'low_snr_feasibility.mat'),'summaryTable','config','snrGrid','nFrames');

fig = figure('Visible','off','Color','w','Position',[80 80 1250 620]);
tiledlayout(1,2,'TileSpacing','compact','Padding','compact');
nexttile; hold on
colors = lines(nMethod); styles = {'o-','s-','d-','x-'};
for method = 1:nMethod
    rows = summaryTable(strcmp(summaryTable.method,names{method}),:);
    semilogy(rows.snrDb,max(rows.ser,eps),styles{method},'Color',colors(method,:), ...
        'LineWidth',1.4,'MarkerSize',7);
end
grid on; xlabel('SNR (dB)'); ylabel('Payload SER');
title('Low-SNR recheck feasibility (raw Monte Carlo points)');
legend('Static 8-preamble','Safe confidence lock','Relaxed margin (research only)', ...
    'Blind anchor (research only)','Location','southwest');
nexttile; hold on
for method = 2:nMethod
    rows = summaryTable(strcmp(summaryTable.method,names{method}),:);
    bar(rows.snrDb+(method-3)*0.28,rows.wrongAnchors,0.25, ...
        'FaceColor',colors(method,:),'DisplayName',names{method});
end
grid on; xlabel('SNR (dB)'); ylabel('Wrong anchors across 12 frames');
title('Anchor safety: lower is better'); legend('Location','northwest');
exportgraphics(fig,fullfile(resultDir,'low_snr_feasibility.png'),'Resolution',180);
savefig(fig,fullfile(resultDir,'low_snr_feasibility.fig')); close(fig);
report = struct('resultDir',resultDir,'summary',summaryTable);
fprintf('Stage 9 low-SNR feasibility: %s\n',resultDir);
end

function values = localCounts(result,bins,payloadRows)
decoded = result.secondSoft.decodedWaveformBins(payloadRows);
anchor = result.anchorMask(payloadRows);
values = [sum(decoded ~= bins(payloadRows)),numel(payloadRows), ...
    sum(anchor),sum(anchor & result.firstSoft.decodedWaveformBins(payloadRows) ~= bins(payloadRows))];
end

function [anchorMargin,promotionMargin] = localRelaxedMargins(snrDb)
% Conservative values are from the independent Stage-7 margin audit.  They
% are deliberately marked research-only until the comparison below proves
% an actual gain without unsafe anchor use.
if snrDb <= -23
    anchorMargin = 0.5; promotionMargin = 1.0;
elseif snrDb <= -21
    anchorMargin = 25; promotionMargin = 60;
elseif snrDb <= -19
    anchorMargin = 55; promotionMargin = 120;
else
    anchorMargin = 500; promotionMargin = 1000;
end
end
