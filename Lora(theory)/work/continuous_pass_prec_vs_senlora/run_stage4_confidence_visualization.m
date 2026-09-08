function report = run_stage4_confidence_visualization()
%RUN_STAGE4_CONFIDENCE_VISUALIZATION Visual audit of per-symbol gate output.

root = fileparts(mfilename('fullpath'));
modelPath = fullfile(root,'results','stage4_confidence_gate','confidence_gate_model.mat');
if ~isfile(modelPath)
    error('SatelliteFig3:MissingConfidenceModel', ...
        'Run train_stage4_confidence_gate first.');
end
loaded = load(modelPath,'model'); model = loaded.model;
resultDir = fullfile(root,'results','stage4_confidence_gate');
config = satelliteFig3Config();
[window,~] = satelliteFig3VisibilityWindow(config);
snrCases = [-22,-16];
audit = repmat(struct('snrDb',NaN,'acceptedCount',0, ...
    'falseAcceptedCount',0,'candidateCount',0,'threshold',NaN, ...
    'posterior',[],'correct',[],'accepted',[]),numel(snrCases),1);
fig = figure('Visible','off','Color','w','Position',[80 80 1320 700]);
for caseIdx = 1:numel(snrCases)
    snrDb = snrCases(caseIdx);
    payload = satelliteFig3GeneratePayload(config,930000+caseIdx);
    bins = [zeros(config.bootstrapPilotCount,1);payload.symbolBins];
    rx = generateContinuousSatelliteFrame(bins,config, ...
        StartTimeSec=window.deltaTimeInSec,SampleSnrDb=snrDb, ...
        NoiseSeed=940000+caseIdx);
    tracker = satelliteFig3RollingPilotTracker(rx,config, ...
        zeros(config.bootstrapPilotCount,1));
    soft = satelliteFig3SenLoRaConfidence(tracker.compensatedSymbols,config);
    gate = satelliteFig3ApplyConfidenceGate(tracker,soft,config,model,snrDb);
    rows = gate.features.payloadRows;
    correct = soft.decodedWaveformBins(rows) == bins(rows);
    x = rows;
    subplot(2,1,caseIdx)
    scatter(x(correct),gate.posterior(correct),28,[0.1 0.55 0.2],'filled'); hold on
    scatter(x(~correct),gate.posterior(~correct),34,[0.85 0.2 0.15],'x','LineWidth',1.2);
    accepted = gate.acceptedPayload;
    scatter(x(accepted),gate.posterior(accepted),70,'ko','LineWidth',1.2);
    yline(gate.threshold,'k--','Gate threshold','LineWidth',1.2);
    ylim([-0.02 1.02]); xlim([config.bootstrapPilotCount+1,numel(bins)]); grid on
    xlabel('Payload symbol index'); ylabel('Posterior reliability');
    title(sprintf('Confidence-pilot audit at %g dB: accepted %d, false accepted %d', ...
        snrDb,sum(accepted),sum(accepted & ~correct)));
    legend('Correct (audit only)','Wrong (audit only)','Accepted virtual pilot', ...
        'Gate threshold','Location','best');
    audit(caseIdx) = struct('snrDb',snrDb,'acceptedCount',sum(accepted), ...
        'falseAcceptedCount',sum(accepted & ~correct), ...
        'candidateCount',sum(gate.features.candidateMask), ...
        'threshold',gate.threshold,'posterior',gate.posterior, ...
        'correct',correct,'accepted',accepted);
end
exportgraphics(fig,fullfile(resultDir,'confidence_symbol_audit.png'),'Resolution',180);
savefig(fig,fullfile(resultDir,'confidence_symbol_audit.fig')); close(fig);
report = struct('audit',audit,'modelPath',modelPath,'resultDir',resultDir);
save(fullfile(resultDir,'confidence_symbol_audit.mat'),'report');
fprintf('Confidence-symbol visualisation: %s\\n',resultDir);
end
