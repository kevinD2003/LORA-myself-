function report = run_stage8_trusted_confidence_visualization()
%RUN_STAGE8_TRUSTED_CONFIDENCE_VISUALIZATION Audit the finished detector.
%   Correct/wrong colours are evaluation-only.  The detector itself takes
%   only RX samples and the eight known preamble symbols.

root = fileparts(mfilename('fullpath'));
resultDir = fullfile(root,'results','stage8_trusted_confidence');
if ~isfolder(resultDir), mkdir(resultDir); end
config = satelliteFig3Config(); [window,~] = satelliteFig3VisibilityWindow(config);
snrCases = [-24,-22,-16,-14];
audit = repmat(struct('snrDb',NaN,'estimatedSnrDb',NaN,'quarantined',0, ...
    'anchors',0,'promoted',0,'falsePromoted',0),numel(snrCases),1);
fig = figure('Visible','off','Color','w','Position',[70 70 1360 760]);
tiledlayout(2,2,'TileSpacing','compact','Padding','compact');
for k = 1:numel(snrCases)
    snrDb = snrCases(k); seed = 2026080900+k;
    payload = satelliteFig3GeneratePayload(config,seed);
    bins = [zeros(config.bootstrapPilotCount,1);payload.symbolBins];
    rx = generateContinuousSatelliteFrame(bins,config, ...
        StartTimeSec=window.deltaTimeInSec,SampleSnrDb=snrDb,NoiseSeed=seed+3000);
    result = satelliteFig3TrustedConfidenceDecode(rx,config,zeros(config.bootstrapPilotCount,1));
    rows = config.bootstrapPilotCount+1:numel(bins);
    correct = result.detectedWaveformBins(rows) == bins(rows);
    q = result.quarantineMask(rows); a = result.anchorMask(rows); p = result.promotedMask(rows);
    nexttile; hold on
    scatter(rows(correct),zeros(sum(correct),1),18,[0.15 0.60 0.25],'filled');
    scatter(rows(~correct),zeros(sum(~correct),1),25,[0.85 0.20 0.15],'x','LineWidth',1.1);
    scatter(rows(q),ones(sum(q),1),55,[0.15 0.35 0.90],'d','LineWidth',1.1);
    scatter(rows(a),2*ones(sum(a),1),70,[0.55 0.15 0.75],'^','filled');
    scatter(rows(p),3*ones(sum(p),1),70,[0 0 0],'s','LineWidth',1.3);
    grid on; xlim([rows(1),rows(end)]); ylim([-0.45,3.45]);
    yticks(0:3); yticklabels({'decoded (audit colour)','quarantined','trusted anchor','promoted pilot'});
    xlabel('Payload symbol index');
    title(sprintf('Injected %g dB, receiver estimate %.1f dB',snrDb,result.estimatedSnrDb));
    if k == 1
        legend('Correct (audit only)','Wrong (audit only)','Quarantine','Anchor','Promoted','Location','best');
    end
    audit(k) = struct('snrDb',snrDb,'estimatedSnrDb',result.estimatedSnrDb, ...
        'quarantined',sum(q),'anchors',sum(a),'promoted',sum(p), ...
        'falsePromoted',sum(p & ~correct));
end
exportgraphics(fig,fullfile(resultDir,'trusted_confidence_states.png'),'Resolution',180);
savefig(fig,fullfile(resultDir,'trusted_confidence_states.fig')); close(fig);
auditTable = struct2table(audit);
writetable(auditTable,fullfile(resultDir,'trusted_confidence_states.csv'));
save(fullfile(resultDir,'trusted_confidence_states.mat'),'audit','config');
report = struct('resultDir',resultDir,'audit',auditTable);
fprintf('Stage 8 trusted-confidence visualisation: %s\n',resultDir);
end
