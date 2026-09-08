function report = run_stage14_hard_prec_diagnostics(options)
%RUN_STAGE14_HARD_PREC_DIAGNOSTICS Inspect hard PREC in both orbit scenes.
%   This is a one-frame diagnostic, not a BER result.  Receiver algorithms
%   share the same received frame; channel truth is used only for plotting
%   and post-receiver error counts.

arguments
    options.SampleSnrDb (1,1) double = -16
    options.SymbolSeed (1,1) double = 2026081501
    options.NoiseSeed (1,1) double = 2026081502
end

root = fileparts(mfilename('fullpath'));
resultDir = fullfile(root,'results','stage14_hard_prec_diagnostics');
if ~isfolder(resultDir)
    mkdir(resultDir);
end

config = satelliteFig3Config();
[window,~] = satelliteFig3VisibilityWindow(config);
scenarioNames = {'High Doppler shift','High Doppler rate'};
scenarioKeys = {'high_doppler_shift','high_doppler_rate'};
startTimes = [-window.deltaTimeOutSec,window.deltaTimeInSec];
known = zeros(config.bootstrapPilotCount,1);
payload = satelliteFig3GeneratePayload(config,options.SymbolSeed);
bins = [known;payload.symbolBins];
symbolIndex = (1:numel(bins)).';
payloadRows = config.bootstrapPilotCount+1:numel(bins);

summaryCell = cell(numel(startTimes),1);
fig = figure('Visible','off','Color','w','Position',[70 70 1480 860]);
tiledlayout(2,2,'TileSpacing','compact','Padding','compact');
for scenario = 1:numel(startTimes)
    [rx,~,truth] = generateContinuousSatelliteFrame(bins,config, ...
        StartTimeSec=startTimes(scenario), ...
        SampleSnrDb=options.SampleSnrDb, ...
        NoiseSeed=options.NoiseSeed);
    staticTracker = satelliteFig3RollingPilotTracker(rx,config,known);
    hardPrec = satelliteFig3HardPrecDecode(rx,config,known);
    truthCfoBins = truth.trueDopplerHz/config.fftBinSpacingHz;
    staticError = staticTracker.predictedCfoBins-truthCfoBins;
    hardError = hardPrec.tracker.predictedCfoBins-truthCfoBins;
    acceptedPayload = hardPrec.pilotAccepted(payloadRows);
    falseAccepted = acceptedPayload & ...
        hardPrec.detectedWaveformBins(payloadRows) ~= bins(payloadRows);

    nexttile(scenario);
    plot(symbolIndex,truthCfoBins,'k-','LineWidth',1.8);
    hold on;
    plot(symbolIndex,staticTracker.predictedCfoBins,'--', ...
        'LineWidth',1.2);
    plot(symbolIndex,hardPrec.tracker.predictedCfoBins,'-', ...
        'LineWidth',1.35);
    grid on;
    xlabel('Frame symbol index');
    ylabel('CFO (FFT bins)');
    title(sprintf('%s, SNR = %.1f dB', ...
        scenarioNames{scenario},options.SampleSnrDb));
    legend('Exact orbit truth','Static 8-preamble', ...
        'Hard PREC rolling-8','Location','best');

    nexttile(2+scenario);
    plot(symbolIndex,staticError,'--','LineWidth',1.2);
    hold on;
    plot(symbolIndex,hardError,'-','LineWidth',1.35);
    acceptedRows = payloadRows(acceptedPayload);
    plot(acceptedRows,hardError(acceptedRows),'o', ...
        'MarkerSize',4,'LineWidth',0.9);
    yline(0,'k:');
    grid on;
    xlabel('Frame symbol index');
    ylabel('CFO prediction error (bins)');
    title(sprintf('Accepted payload pilots: %d, false: %d', ...
        sum(acceptedPayload),sum(falseAccepted)));
    legend('Static 8-preamble','Hard PREC rolling-8', ...
        'Accepted hard pilots','Location','best');

    summaryCell{scenario} = struct( ...
        'scenario',scenarioKeys{scenario}, ...
        'startTimeSec',startTimes(scenario), ...
        'sampleSnrDb',options.SampleSnrDb, ...
        'staticRmseBins',sqrt(mean(staticError(payloadRows).^2)), ...
        'hardPrecRmseBins',sqrt(mean(hardError(payloadRows).^2)), ...
        'requestedPayloadCount',numel(payloadRows), ...
        'acceptedPayloadCount',sum(acceptedPayload), ...
        'falseAcceptedPayloadCount',sum(falseAccepted), ...
        'acceptedPayloadRows',acceptedRows(:), ...
        'truthCfoBins',truthCfoBins, ...
        'staticPredictedCfoBins',staticTracker.predictedCfoBins, ...
        'hardPrecPredictedCfoBins',hardPrec.tracker.predictedCfoBins);
end
summary = vertcat(summaryCell{:});

titleText = sprintf(['Hard-decision PREC diagnostic: common payload/noise, ' ...
    'truth used only for evaluation']);
sgtitle(titleText);
imagePath = fullfile(resultDir,'hard_prec_two_scenario_diagnostics.png');
exportgraphics(fig,imagePath,'Resolution',180);
savefig(fig,fullfile(resultDir,'hard_prec_two_scenario_diagnostics.fig'));
close(fig);

summaryTable = struct2table(rmfield(summary,{ ...
    'acceptedPayloadRows','truthCfoBins','staticPredictedCfoBins', ...
    'hardPrecPredictedCfoBins'}));
writetable(summaryTable,fullfile(resultDir,'hard_prec_summary.csv'));
save(fullfile(resultDir,'hard_prec_diagnostics.mat'), ...
    'summary','summaryTable','config','options','bins');
report = struct('resultDir',resultDir,'imagePath',imagePath, ...
    'summary',summary,'summaryTable',summaryTable);
fprintf('Stage 14 hard-PREC diagnostic: %s\n',resultDir);
disp(summaryTable);
end
