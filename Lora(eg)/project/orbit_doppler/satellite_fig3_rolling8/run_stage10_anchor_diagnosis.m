function report = run_stage10_anchor_diagnosis()
%RUN_STAGE10_ANCHOR_DIAGNOSIS Trace SER changes back to anchor CFO quality.
%   Channel truth is used only for post-run diagnosis; the trusted decoder
%   receives only RX samples and the eight known preamble symbols.

root = fileparts(mfilename('fullpath'));
resultDir = fullfile(root,'results','stage10_anchor_diagnosis');
if ~isfolder(resultDir), mkdir(resultDir); end
config = satelliteFig3Config(); [window,~] = satelliteFig3VisibilityWindow(config);
snrCases = [-20,-16]; nFrames = 32;
rows = repmat(struct('snrDb',NaN,'frame',0,'baseSer',NaN,'recheckSer',NaN, ...
    'serDelta',NaN,'requestedAnchors',0,'acceptedAnchors',0, ...
    'wrongAnchorLabels',0,'anchorCfoRmseBins',NaN, ...
    'basePredictionRmseBins',NaN,'recheckPredictionRmseBins',NaN), ...
    numel(snrCases)*nFrames,1);
out = 0;
for s = 1:numel(snrCases)
    trialConfig = config;
    if snrCases(s) == -20
        % Research-only setting responsible for the Stage-9 -20 dB gain.
        trialConfig.confidencePromotionSnrDb = -30;
        trialConfig.confidenceAnchorMargin = 55;
        trialConfig.confidencePromotionMargin = 120;
    end
    for frame = 1:nFrames
        seed = 2026081100 + 100*s + frame;
        payload = satelliteFig3GeneratePayload(trialConfig,seed);
        bins = [zeros(trialConfig.bootstrapPilotCount,1);payload.symbolBins];
        [rx,~,truth] = generateContinuousSatelliteFrame(bins,trialConfig, ...
            StartTimeSec=window.deltaTimeInSec,SampleSnrDb=snrCases(s),NoiseSeed=seed+500000);
        payloadRows = trialConfig.bootstrapPilotCount+1:numel(bins);
        result = satelliteFig3TrustedConfidenceDecode(rx,trialConfig, ...
            zeros(trialConfig.bootstrapPilotCount,1));
        truthBins = truth.trueDopplerHz/trialConfig.fftBinSpacingHz;
        baseErr = result.firstSoft.decodedWaveformBins(payloadRows) ~= bins(payloadRows);
        recheckErr = result.secondSoft.decodedWaveformBins(payloadRows) ~= bins(payloadRows);
        requested = result.anchorMask(payloadRows);
        accepted = result.recheckTracker.pilotAccepted(payloadRows);
        anchorRows = payloadRows(accepted);
        if isempty(anchorRows)
            cfoRmse = NaN;
        else
            cfoRmse = sqrt(mean((result.recheckTracker.measuredCfoBins(anchorRows) - ...
                truthBins(anchorRows)).^2));
        end
        out = out+1;
        rows(out) = struct('snrDb',snrCases(s),'frame',frame, ...
            'baseSer',mean(baseErr),'recheckSer',mean(recheckErr), ...
            'serDelta',mean(recheckErr)-mean(baseErr), ...
            'requestedAnchors',sum(requested),'acceptedAnchors',sum(accepted), ...
            'wrongAnchorLabels',sum(requested & ...
                result.firstSoft.decodedWaveformBins(payloadRows) ~= bins(payloadRows)), ...
            'anchorCfoRmseBins',cfoRmse, ...
            'basePredictionRmseBins',sqrt(mean((result.bootstrapTracker.predictedCfoBins(payloadRows) - truthBins(payloadRows)).^2)), ...
            'recheckPredictionRmseBins',sqrt(mean((result.recheckTracker.predictedCfoBins(payloadRows) - truthBins(payloadRows)).^2)));
    end
end
diagnosis = struct2table(rows);
writetable(diagnosis,fullfile(resultDir,'anchor_diagnosis.csv'));
save(fullfile(resultDir,'anchor_diagnosis.mat'),'diagnosis','config','snrCases','nFrames');

fig = figure('Visible','off','Color','w','Position',[90 90 1220 570]);
tiledlayout(1,2,'TileSpacing','compact','Padding','compact');
nexttile; hold on
for s = 1:numel(snrCases)
    group = diagnosis(diagnosis.snrDb == snrCases(s),:);
    scatter(group.anchorCfoRmseBins,group.serDelta,42,'filled', ...
        'DisplayName',sprintf('%g dB',snrCases(s)));
end
xline(0,'k:'); yline(0,'k--','No SER change'); grid on
xlabel('Accepted-anchor CFO RMSE (bin, audit only)'); ylabel('Recheck SER - static SER');
title('Does CFO measurement quality explain recheck loss?'); legend('Location','best');
nexttile; hold on
for s = 1:numel(snrCases)
    group = diagnosis(diagnosis.snrDb == snrCases(s),:);
    scatter(group.basePredictionRmseBins,group.recheckPredictionRmseBins,42,'filled', ...
        'DisplayName',sprintf('%g dB',snrCases(s)));
end
lims = xlim; plot(lims,lims,'k--','DisplayName','Equal prediction error'); grid on
xlabel('Static bootstrap prediction RMSE (bin, audit only)');
ylabel('Recheck prediction RMSE (bin, audit only)');
title('Doppler trajectory change after trusted anchors'); legend('Location','best');
exportgraphics(fig,fullfile(resultDir,'anchor_diagnosis.png'),'Resolution',180);
savefig(fig,fullfile(resultDir,'anchor_diagnosis.fig')); close(fig);
report = struct('resultDir',resultDir,'diagnosis',diagnosis);
fprintf('Stage 10 anchor diagnosis: %s\n',resultDir);
end
