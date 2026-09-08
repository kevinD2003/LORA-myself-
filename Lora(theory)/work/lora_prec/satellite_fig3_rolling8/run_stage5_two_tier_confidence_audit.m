function report = run_stage5_two_tier_confidence_audit()
%RUN_STAGE5_TWO_TIER_CONFIDENCE_AUDIT Visualise safe immediate/provisional classes.

root = fileparts(mfilename('fullpath'));
modelPath = fullfile(root,'results','stage4_confidence_gate','confidence_gate_model.mat');
if ~isfile(modelPath), error('SatelliteFig3:MissingConfidenceModel','Run stage 4 first.'); end
loaded = load(modelPath,'model'); model = loaded.model;
resultDir = fullfile(root,'results','stage5_two_tier_confidence');
if ~isfolder(resultDir), mkdir(resultDir); end
config = satelliteFig3Config(); [window,~] = satelliteFig3VisibilityWindow(config);
snrCases = [-22,-16];
audit = repmat(struct('snrDb',NaN,'immediateCount',0,'provisionalCount',0, ...
    'falseImmediate',0,'falseProvisional',0),numel(snrCases),1);
fig = figure('Visible','off','Color','w','Position',[80 80 1320 700]);
for caseIdx = 1:numel(snrCases)
    snrDb = snrCases(caseIdx);
    payload = satelliteFig3GeneratePayload(config,950000+caseIdx);
    bins = [zeros(config.bootstrapPilotCount,1);payload.symbolBins];
    rx = generateContinuousSatelliteFrame(bins,config, ...
        StartTimeSec=window.deltaTimeInSec,SampleSnrDb=snrDb,NoiseSeed=960000+caseIdx);
    tracker = satelliteFig3RollingPilotTracker(rx,config,zeros(config.bootstrapPilotCount,1));
    soft = satelliteFig3SenLoRaConfidence(tracker.compensatedSymbols,config);
    tier = satelliteFig3TwoTierPilotDecision(tracker,soft,config,model,snrDb);
    rows = tier.features.payloadRows;
    correct = soft.decodedWaveformBins(rows) == bins(rows);
    x = rows;
    subplot(2,1,caseIdx)
    scatter(x(correct),tier.posterior(correct),28,[0.1 0.55 0.2],'filled'); hold on
    scatter(x(~correct),tier.posterior(~correct),34,[0.85 0.2 0.15],'x','LineWidth',1.2);
    immediate = tier.immediatePayload; provisional = tier.provisionalPayload;
    scatter(x(provisional),tier.posterior(provisional),70,[0.1 0.35 0.9],'d','LineWidth',1.3);
    scatter(x(immediate),tier.posterior(immediate),85,'ko','LineWidth',1.5);
    yline(min(1,tier.directPosteriorThreshold),'k--','Immediate threshold','LineWidth',1.1);
    grid on; ylim([-0.02 1.02]); xlim([config.bootstrapPilotCount+1,numel(bins)]);
    xlabel('Payload symbol index'); ylabel('Posterior reliability');
    title(sprintf('%g dB: immediate %d (false %d), provisional %d (false %d)', ...
        snrDb,sum(immediate),sum(immediate & ~correct), ...
        sum(provisional),sum(provisional & ~correct)));
    legend('Correct (audit only)','Wrong (audit only)','Provisional - no state update', ...
        'Immediate virtual pilot','Immediate threshold','Location','best');
    audit(caseIdx) = struct('snrDb',snrDb,'immediateCount',sum(immediate), ...
        'provisionalCount',sum(provisional), ...
        'falseImmediate',sum(immediate & ~correct), ...
        'falseProvisional',sum(provisional & ~correct));
end
exportgraphics(fig,fullfile(resultDir,'two_tier_confidence_audit.png'),'Resolution',180);
savefig(fig,fullfile(resultDir,'two_tier_confidence_audit.fig')); close(fig);
report = struct('audit',audit,'resultDir',resultDir);
save(fullfile(resultDir,'two_tier_confidence_audit.mat'),'report');
fprintf('Stage 5 two-tier audit: %s\\n',resultDir);
end
