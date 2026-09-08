function report = run_stage11_independent_low_snr_validation()
%RUN_STAGE11_INDEPENDENT_LOW_SNR_VALIDATION Hold-out test for pair anchors.
%   Validates the Stage-10 two-anchor result on new random frames.  The
%   temporary -20 dB profile remains experimental until this hold-out test
%   has completed; no truth is passed to the receiver.

root = fileparts(mfilename('fullpath'));
resultDir = fullfile(root,'results','stage11_independent_low_snr');
if ~isfolder(resultDir), mkdir(resultDir); end
config = satelliteFig3Config(); [window,~] = satelliteFig3VisibilityWindow(config);
snrGrid = [-22,-20,-16]; nFrames = 48;
summary = repmat(struct('snrDb',NaN,'method','', 'symbolErrors',0, ...
    'symbolCount',0,'ser',NaN,'anchors',0,'wrongAnchors',0),2*numel(snrGrid),1);
out = 0;
for s = 1:numel(snrGrid)
    counts = zeros(2,4);
    testConfig = localProfile(config,snrGrid(s));
    for frame = 1:nFrames
        seed = 2026081200 + 100*s + frame;
        payload = satelliteFig3GeneratePayload(config,seed);
        bins = [zeros(config.bootstrapPilotCount,1);payload.symbolBins];
        rx = generateContinuousSatelliteFrame(bins,config, ...
            StartTimeSec=window.deltaTimeInSec,SampleSnrDb=snrGrid(s),NoiseSeed=seed+600000);
        payloadRows = config.bootstrapPilotCount+1:numel(bins);
        staticTracker = satelliteFig3RollingPilotTracker(rx,config,zeros(config.bootstrapPilotCount,1));
        staticSoft = satelliteFig3SenLoRaConfidence(staticTracker.compensatedSymbols,config);
        counts(1,:) = counts(1,:) + [sum(staticSoft.decodedWaveformBins(payloadRows) ~= bins(payloadRows)), ...
            numel(payloadRows),0,0];
        recheck = satelliteFig3TrustedConfidenceDecode(rx,testConfig,zeros(config.bootstrapPilotCount,1));
        anchor = recheck.recheckTracker.pilotAccepted(payloadRows);
        counts(2,:) = counts(2,:) + [ ...
            sum(recheck.secondSoft.decodedWaveformBins(payloadRows) ~= bins(payloadRows)), ...
            numel(payloadRows),sum(anchor), ...
            sum(anchor & recheck.firstSoft.decodedWaveformBins(payloadRows) ~= bins(payloadRows))];
    end
    out = out+1;
    summary(out) = localRow(snrGrid(s),'Static 8-preamble',counts(1,:));
    out = out+1;
    summary(out) = localRow(snrGrid(s),'Two-anchor recheck',counts(2,:));
end
summaryTable = struct2table(summary);
writetable(summaryTable,fullfile(resultDir,'independent_low_snr_validation.csv'));
save(fullfile(resultDir,'independent_low_snr_validation.mat'),'summaryTable','config','snrGrid','nFrames');

fig = figure('Visible','off','Color','w','Position',[100 100 1100 510]);
tiledlayout(1,2,'TileSpacing','compact','Padding','compact');
nexttile; hold on
methods = {'Static 8-preamble','Two-anchor recheck'}; colors = lines(2);
for k = 1:2
    rows = summaryTable(strcmp(summaryTable.method,methods{k}),:);
    semilogy(rows.snrDb,rows.ser,'o-','LineWidth',1.5,'MarkerSize',7, ...
        'Color',colors(k,:),'DisplayName',methods{k});
end
grid on; xlabel('SNR (dB)'); ylabel('Payload SER');
title(sprintf('Independent validation: %d frames per point',nFrames)); legend('Location','southwest');
nexttile; hold on
rows = summaryTable(strcmp(summaryTable.method,'Two-anchor recheck'),:);
bar(rows.snrDb,rows.anchors,0.55,'FaceColor',colors(2,:));
grid on; xlabel('SNR (dB)'); ylabel('Accepted anchors across validation frames');
title(sprintf('Wrong anchors: %d',sum(rows.wrongAnchors)));
exportgraphics(fig,fullfile(resultDir,'independent_low_snr_validation.png'),'Resolution',180);
savefig(fig,fullfile(resultDir,'independent_low_snr_validation.fig')); close(fig);
report = struct('resultDir',resultDir,'summary',summaryTable);
fprintf('Stage 11 independent validation: %s\n',resultDir);
end

function row = localRow(snrDb,name,count)
row = struct('snrDb',snrDb,'method',name,'symbolErrors',count(1), ...
    'symbolCount',count(2),'ser',count(1)/count(2), ...
    'anchors',count(3),'wrongAnchors',count(4));
end

function trial = localProfile(config,snrDb)
trial = config;
if snrDb == -20
    trial.confidencePromotionSnrDb = -30;
    trial.confidenceAnchorMargin = 55;
    trial.confidencePromotionMargin = 120;
elseif snrDb == -22
    % This is deliberately tested as a rejection control: it does not turn
    % on recheck because the formal promotion SNR remains -16 dB.
    trial.confidencePromotionSnrDb = -16;
end
end
