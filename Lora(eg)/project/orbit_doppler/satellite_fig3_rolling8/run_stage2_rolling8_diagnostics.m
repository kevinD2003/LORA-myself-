function report = run_stage2_rolling8_diagnostics()
%RUN_STAGE2_ROLLING8_DIAGNOSTICS Plot causal tracker state before BER runs.

root = fileparts(mfilename('fullpath'));
resultDir = fullfile(root,'results','stage2_rolling8_diagnostics');
if ~isfolder(resultDir)
    mkdir(resultDir);
end
config = satelliteFig3Config();
[window,~] = satelliteFig3VisibilityWindow(config);
startTime = window.deltaTimeInSec; % Figure 3 high-rate scenario.
payload = satelliteFig3GeneratePayload(config,config.randomSeedSymbols);
bins = [zeros(config.bootstrapPilotCount,1);payload.symbolBins];
[rx,~,truth] = generateContinuousSatelliteFrame(bins,config, ...
    StartTimeSec=startTime,SampleSnrDb=-16,NoiseSeed=config.randomSeedNoise);
known = zeros(config.bootstrapPilotCount,1);

bootstrapOnly = satelliteFig3RollingPilotTracker(rx,config,known);
allHardMask = true(numel(bins),1);
hardRolling = satelliteFig3RollingPilotTracker(rx,config,known, ...
    AcceptedMask=allHardMask,ForceAccept=true);
senlora = satelliteFig3SenLoRaIterativeDecode(rx,config,known);

truthCfoBins = truth.trueDopplerHz/config.fftBinSpacingHz;
symbol = (1:numel(bins)).';
fig = figure('Visible','off','Color','w','Position',[80 80 1320 850]);
subplot(3,1,1)
plot(symbol,truthCfoBins,'k-','LineWidth',2.0); hold on
plot(symbol,bootstrapOnly.predictedCfoBins,'--','LineWidth',1.3);
plot(symbol,hardRolling.predictedCfoBins,'-.','LineWidth',1.2);
plot(symbol,senlora.tracker.predictedCfoBins,'-','LineWidth',1.5);
grid on; ylabel('CFO (FFT bins)');
title('High-rate single-device frame: causal rolling-8 Doppler prediction');
legend('Exact channel truth (evaluation only)','8-preamble only', ...
    'Hard-decision rolling 8','SenLoRa confidence rolling 8','Location','best');
subplot(3,1,2)
plot(symbol,bootstrapOnly.predictedCfoBins-truthCfoBins,'--','LineWidth',1.2); hold on
plot(symbol,hardRolling.predictedCfoBins-truthCfoBins,'-.','LineWidth',1.2);
plot(symbol,senlora.tracker.predictedCfoBins-truthCfoBins,'-','LineWidth',1.5);
yline(0,'k:'); grid on; ylabel('Prediction error (bins)');
legend('8-preamble only','Hard-decision rolling 8','SenLoRa rolling 8','Location','best');
subplot(3,1,3)
stairs(symbol,double(senlora.pilotAccepted),'LineWidth',1.5); hold on
stairs(symbol,senlora.tracker.activeHistoryCount/10,'LineWidth',1.2);
confidence = senlora.confidence;
confidence(~isfinite(confidence)) = 0;
normalizedConfidence = confidence/max(max(confidence),eps);
plot(symbol,normalizedConfidence,'LineWidth',1.0);
grid on; ylim([-0.05 1.1]); xlabel('Symbol index');
ylabel('Acceptance / normalized confidence');
legend('Accepted virtual pilot','History length / 10','SenLoRa confidence (normalized)','Location','best');
exportgraphics(fig,fullfile(resultDir,'rolling8_tracking_diagnostics.png'),'Resolution',180);
savefig(fig,fullfile(resultDir,'rolling8_tracking_diagnostics.fig'));
close(fig);

payloadRows = config.bootstrapPilotCount+1:numel(bins);
report = struct( ...
    'sampleSnrDb',-16, 'scenario','high_doppler_rate', ...
    'startTimeSec',startTime, 'truthCfoBins',truthCfoBins, ...
    'bootstrapOnlyRmseBins',sqrt(mean((bootstrapOnly.predictedCfoBins(payloadRows)-truthCfoBins(payloadRows)).^2)), ...
    'hardRollingRmseBins',sqrt(mean((hardRolling.predictedCfoBins(payloadRows)-truthCfoBins(payloadRows)).^2)), ...
    'senLoRaRollingRmseBins',sqrt(mean((senlora.tracker.predictedCfoBins(payloadRows)-truthCfoBins(payloadRows)).^2)), ...
    'senLoRaAcceptedPayloadCount',sum(senlora.pilotAccepted(payloadRows)), ...
    'senLoRaIterations',senlora.iterations, ...
    'resultDir',resultDir);
save(fullfile(resultDir,'stage2_rolling8_report.mat'),'report','truth','bootstrapOnly','hardRolling','senlora');
fprintf('Stage 2 result folder: %s\\n',resultDir);
fprintf('RMSE bins: bootstrap %.4g, hard %.4g, SenLoRa %.4g; accepted payload %d; iterations %d\\n', ...
    report.bootstrapOnlyRmseBins,report.hardRollingRmseBins, ...
    report.senLoRaRollingRmseBins,report.senLoRaAcceptedPayloadCount, ...
    report.senLoRaIterations);
end
