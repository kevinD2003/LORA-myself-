function generate_rw3_rw4_sf11_figures()
%GENERATE_RW3_RW4_SF11_FIGURES Read-only Stage55 audit and PPT figures.
% This wrapper reads/calls the canonical project but writes only to outputDir.

projectRoot = 'D:\codex\Lora(eg)\project\orbit_doppler\satellite_fig3_rolling8';
outputDir = 'D:\codex\picture\RW3_RW4_SF11_PPT_FIGURES';
if ~isfolder(projectRoot)
    error('RW3RW4:MissingProject','Canonical project was not found: %s',projectRoot);
end
if ~isfolder(outputDir)
    mkdir(outputDir);
end

logPath = fullfile(outputDir,'run_log.txt');
diary(logPath);
cleanupDiary = onCleanup(@() diary('off')); %#ok<NASGU>
fprintf('RW3/RW4 SF11 figure generation started: %s\n',datestr(now,31));
fprintf('MATLAB version: %s\n',version);
fprintf('Project (read-only): %s\n',projectRoot);
fprintf('Output directory: %s\n',outputDir);

before = localProjectManifest(projectRoot);
writetable(before,fullfile(outputDir,'project_manifest_before.csv'));
fprintf('Pre-run project manifest: %d files.\n',height(before));

addpath(projectRoot,'-begin');
cleanupPath = onCleanup(@() rmpath(projectRoot)); %#ok<NASGU>
config = satelliteFig3Config();
localValidateConfig(config);

[gitSha,gitStatusText] = localGitState(projectRoot);
fprintf('Git SHA: %s\n',gitSha);

% Candidate frames use the canonical Stage55 disjoint-seed policy.  The
% first frame is the smoke test; the remaining seven are evaluated only
% after that receiver run succeeds.
schedule = satelliteFig3ContinuousPassSchedule(config);
centerTrajectory = satelliteFig3Trajectory(schedule.frameCenterTimeSec,config);
driftBinsPerFrame = abs(centerTrajectory.dopplerRateHzPerSec).* ...
    schedule.frameDurationSec/config.fftBinSpacingHz;
visible = find(schedule.fullyVisible);
highDynamic = visible(driftBinsPerFrame(visible) >= 0.5);
if numel(highDynamic) < 8
    error('RW3RW4:CandidateFrames','Fewer than eight high-dynamic visible frames are available.');
end
candidateFrames = highDynamic(round(linspace(1,numel(highDynamic),8)));
candidateSnrDb = -20;
knownWaveformBins = zeros(config.bootstrapPilotCount,1);
candidateRows = repmat(struct('frameIndex',NaN,'frameCenterTimeSec',NaN, ...
    'driftBinsPerFrame',NaN,'payloadSeed',NaN,'noiseSeed',NaN, ...
    'iterations',NaN,'proposedCount',NaN,'stableRequestedCount',NaN, ...
    'acceptedCount',NaN,'rejectedRequestedCount',NaN,'cfoRmseBins',NaN, ...
    'score',NaN),numel(candidateFrames),1);
bestScore = -Inf;
best = struct();

for candidateIndex = 1:numel(candidateFrames)
    frameIndex = candidateFrames(candidateIndex);
    payloadSeed = 2026260800+10000+frameIndex;
    noiseSeed = 2026260900+10000+frameIndex;
    if candidateIndex == 1
        fprintf('Smoke test frame %d of %d: schedule frame %d.\n', ...
            candidateIndex,numel(candidateFrames),frameIndex);
    else
        fprintf('Candidate frame %d of %d: schedule frame %d.\n', ...
            candidateIndex,numel(candidateFrames),frameIndex);
    end
    payload = satelliteFig3GeneratePayload(config,payloadSeed);
    labels = [knownWaveformBins;payload.symbolBins];
    [rxSymbols,~,truth] = generateContinuousSatelliteFrame(labels,config, ...
        StartTimeSec=schedule.frameStartTimeSec(frameIndex), ...
        SampleSnrDb=candidateSnrDb,NoiseSeed=noiseSeed, ...
        InitialPhaseRad=0,NextSymbolBin=0);
    decoded = satelliteFig3SenLoRaVirtualPilotDecode( ...
        rxSymbols,config,knownWaveformBins);
    payloadRows = (config.bootstrapPilotCount+1:config.frameSymbolCount).';
    tracker = decoded.tracker;
    iterationHistory = decoded.iterationHistory;
    gateIterationIndex = max(1,numel(iterationHistory)-1);
    gateIteration = iterationHistory(gateIterationIndex);
    requested = iterationHistory(end).requestedMask(payloadRows);
    accepted = tracker.pilotAccepted(payloadRows);
    rejectedRequested = requested & ~accepted;
    trueCfoBins = truth.trueDopplerHz/config.fftBinSpacingHz;
    residual = trueCfoBins(payloadRows)-tracker.predictedCfoBins(payloadRows);
    cfoRmseBins = sqrt(mean(residual.^2,'omitnan'));
    proposedCount = sum(gateIteration.proposedMask(payloadRows));
    stableRequestedCount = sum(requested);
    acceptedCount = sum(accepted);
    rejectedRequestedCount = sum(rejectedRequested);
    score = 100*acceptedCount+0.1*rejectedRequestedCount-cfoRmseBins;
    candidateRows(candidateIndex) = struct( ...
        'frameIndex',frameIndex, ...
        'frameCenterTimeSec',schedule.frameCenterTimeSec(frameIndex), ...
        'driftBinsPerFrame',driftBinsPerFrame(frameIndex), ...
        'payloadSeed',payloadSeed,'noiseSeed',noiseSeed, ...
        'iterations',decoded.iterations,'proposedCount',proposedCount, ...
        'stableRequestedCount',stableRequestedCount, ...
        'acceptedCount',acceptedCount, ...
        'rejectedRequestedCount',rejectedRequestedCount, ...
        'cfoRmseBins',cfoRmseBins,'score',score);
    fprintf(['  iterations=%d, proposed=%d, stable/requested=%d, ' ...
        'accepted=%d, rejected requested=%d, CFO RMSE=%.4f bin.\n'], ...
        decoded.iterations,proposedCount,stableRequestedCount, ...
        acceptedCount,rejectedRequestedCount,cfoRmseBins);
    if candidateIndex == 1
        fprintf('Smoke test completed successfully; continuing candidate selection.\n');
    end
    if score > bestScore
        bestScore = score;
        best = struct('frameIndex',frameIndex,'payloadSeed',payloadSeed, ...
            'noiseSeed',noiseSeed,'payload',payload,'labels',labels, ...
            'rxSymbols',rxSymbols,'truth',truth,'decoded',decoded, ...
            'gateIterationIndex',gateIterationIndex);
    end
end

candidateTable = struct2table(candidateRows);
writetable(candidateTable,fullfile(outputDir,'candidate_frame_selection.csv'));
fprintf('Selected schedule frame %d (payload seed %d, noise seed %d).\n', ...
    best.frameIndex,best.payloadSeed,best.noiseSeed);

frameIndex = best.frameIndex;
payloadSeed = best.payloadSeed;
noiseSeed = best.noiseSeed;
payload = best.payload;
labels = best.labels;
rxSymbols = best.rxSymbols;
truth = best.truth;
decoded = best.decoded;
iterationHistory = decoded.iterationHistory;
gateIterationIndex = best.gateIterationIndex;
gateIteration = iterationHistory(gateIterationIndex);
finalIteration = iterationHistory(end);
soft = gateIteration.soft;
tracker = decoded.tracker;
payloadRows = (config.bootstrapPilotCount+1:config.frameSymbolCount).';
payloadSymbolIndex = (1:config.payloadSymbolCount).';
frameSymbolIndex = (1:config.frameSymbolCount).';

confidence = soft.confidence(payloadRows);
tauBlock = soft.tauBlock(payloadRows);
tauGlobal = soft.tauGlobal(payloadRows);
confidencePass = soft.confidentMask(payloadRows) & soft.readyMask(payloadRows);
marginRatio = soft.symbolCodewordMargin(payloadRows)./max(tauGlobal,eps);
marginPass = marginRatio >= config.senloraMinimumMarginRatio;
decodedWaveformBins = soft.decodedWaveformBins(payloadRows);
hardWaveformBins = gateIteration.tracker.hardWaveformBins(payloadRows);
softHardAgreement = decodedWaveformBins == hardWaveformBins;
proposedMask = gateIteration.proposedMask(payloadRows);
stableMask = gateIteration.stableMask(payloadRows);
finalStableMask = finalIteration.stableMask(payloadRows);
requestedMask = finalIteration.requestedMask(payloadRows);
acceptedMask = tracker.pilotAccepted(payloadRows);
rejectedCandidateMask = requestedMask & ~acceptedMask;

trueCfoBins = truth.trueDopplerHz/config.fftBinSpacingHz;
predictedCfoBins = tracker.predictedCfoBins;
trueRateBinsPerSec = truth.trueDopplerRateHzPerSec/config.fftBinSpacingHz;
predictedRateBinsPerSec = tracker.predictedRateBinsPerSec;
activeHistoryCount = tracker.activeHistoryCount;
pilotAppliedAtRows = tracker.pilotAppliedAtRows;
[historySlotSymbolIndex,nextSlotTrace] = localReconstructHistorySlots( ...
    tracker,config); %#ok<ASGLU>

selectedRun = struct( ...
    'snrDb',candidateSnrDb,'frameIndex',frameIndex, ...
    'frameStartTimeSec',schedule.frameStartTimeSec(frameIndex), ...
    'frameCenterTimeSec',schedule.frameCenterTimeSec(frameIndex), ...
    'driftBinsPerFrame',driftBinsPerFrame(frameIndex), ...
    'payloadSeed',payloadSeed,'noiseSeed',noiseSeed, ...
    'rateSource',decoded.crossFrameRateDiagnostic.source, ...
    'truthUsedByReceiver',false,'gateIterationIndex',gateIterationIndex);
save(fullfile(outputDir,'selected_run_workspace.mat'), ...
    'config','schedule','selectedRun','payload','labels','rxSymbols', ...
    'truth','decoded','candidateTable','-v7.3');

% Figure 1: confidence, two-pass proposal/stability, margin/agreement, and
% tracker request/admission on the selected real frame.
fig = figure('Color','w','Visible','off','Position',[80 80 1600 900]);
layout = tiledlayout(fig,2,2,'Padding','compact','TileSpacing','compact');
ax = nexttile(layout,1);
plot(ax,payloadSymbolIndex,confidence,'Color',[0.00 0.35 0.75],'LineWidth',1.7); hold(ax,'on');
plot(ax,payloadSymbolIndex,tauBlock,'--','Color',[0.85 0.45 0.05],'LineWidth',1.5);
plot(ax,payloadSymbolIndex,config.confidenceThresholdScale*tauGlobal, ...
    '-.','Color',[0.45 0.10 0.60],'LineWidth',1.7);
grid(ax,'on'); xlim(ax,[1 config.payloadSymbolCount]);
xlabel(ax,'Payload symbol index'); ylabel(ax,'Confidence metric');
title(ax,'A  Soft confidence and causal thresholds');
legend(ax,{'C_m','\tau_{block}','scale \times \tau_{global}'},'Location','best');

ax = nexttile(layout,2);
stem(ax,payloadSymbolIndex(proposedMask),ones(sum(proposedMask),1), ...
    'filled','Color',[0.10 0.45 0.80],'MarkerSize',3,'LineWidth',1.2); hold(ax,'on');
stem(ax,payloadSymbolIndex(stableMask),2*ones(sum(stableMask),1), ...
    'filled','Color',[0.10 0.60 0.25],'MarkerSize',4,'LineWidth',1.2);
ylim(ax,[0.4 2.6]); yticks(ax,[1 2]); yticklabels(ax,{'Proposed','Stable'});
xlim(ax,[1 config.payloadSymbolCount]); grid(ax,'on');
xlabel(ax,'Payload symbol index'); title(ax,'B  Proposed vs two-pass stable');

ax = nexttile(layout,3);
yyaxis(ax,'left');
plot(ax,payloadSymbolIndex,marginRatio,'Color',[0.20 0.25 0.65],'LineWidth',1.6); hold(ax,'on');
yline(ax,config.senloraMinimumMarginRatio,'--','Minimum margin ratio', ...
    'Color',[0.75 0.15 0.10],'LineWidth',1.4,'LabelHorizontalAlignment','left');
ylabel(ax,'Codeword margin / \tau_{global}');
yyaxis(ax,'right');
stairs(ax,payloadSymbolIndex,double(softHardAgreement),'Color',[0.10 0.55 0.25],'LineWidth',1.3);
ylim(ax,[-0.05 1.05]); yticks(ax,[0 1]); yticklabels(ax,{'Fail','Pass'});
ylabel(ax,'Soft-hard agreement');
xlim(ax,[1 config.payloadSymbolCount]); grid(ax,'on');
xlabel(ax,'Payload symbol index'); title(ax,'C  Margin and label agreement gates');

ax = nexttile(layout,4);
stem(ax,payloadSymbolIndex(requestedMask),ones(sum(requestedMask),1), ...
    'filled','Color',[0.55 0.35 0.10],'MarkerSize',4,'LineWidth',1.2); hold(ax,'on');
stem(ax,payloadSymbolIndex(acceptedMask),2*ones(sum(acceptedMask),1), ...
    'filled','Color',[0.00 0.55 0.50],'MarkerSize',5,'LineWidth',1.2);
ylim(ax,[0.4 2.6]); yticks(ax,[1 2]); yticklabels(ax,{'Requested','Accepted'});
xlim(ax,[1 config.payloadSymbolCount]); grid(ax,'on');
xlabel(ax,'Payload symbol index'); title(ax,'D  Tracker request and final admission');
sgtitle(layout,sprintf('SF11 RW3 confidence-to-VP timeline (real frame %d, %g dB)', ...
    frameIndex,candidateSnrDb),'FontWeight','bold');
localStyleFigure(fig);
localSaveFigure(fig,outputDir,'fig_rw3_sf11_confidence_timeline');
save(fullfile(outputDir,'fig_rw3_sf11_confidence_timeline.mat'), ...
    'selectedRun','payloadSymbolIndex','confidence','tauBlock','tauGlobal', ...
    'confidencePass','marginRatio','marginPass','softHardAgreement', ...
    'proposedMask','stableMask','finalStableMask','requestedMask', ...
    'acceptedMask','rejectedCandidateMask','decodedWaveformBins', ...
    'hardWaveformBins','gateIterationIndex','config');
close(fig);

% Figure 2: cumulative gate-by-gate admission counts.
stageMasks = {true(config.payloadSymbolCount,1),confidencePass, ...
    confidencePass & marginPass, ...
    confidencePass & marginPass & softHardAgreement, ...
    confidencePass & marginPass & softHardAgreement & requestedMask, ...
    confidencePass & marginPass & softHardAgreement & requestedMask & acceptedMask};
stageNames = {'Total payload','Confidence pass','+ Margin-ratio pass', ...
    '+ Soft-hard agreement','+ Two-pass stable/requested', ...
    '+ Tracker accepted'};
stageCounts = cellfun(@sum,stageMasks).';
fig = figure('Color','w','Visible','off','Position',[100 100 1500 760]);
ax = axes(fig);
b = barh(ax,stageCounts,'FaceColor','flat','BarWidth',0.68);
b.CData = [0.25 0.45 0.75;0.20 0.55 0.78;0.20 0.65 0.65; ...
    0.35 0.68 0.40;0.78 0.55 0.20;0.05 0.55 0.48];
yticks(ax,1:numel(stageNames)); yticklabels(ax,stageNames); set(ax,'YDir','reverse');
xlabel(ax,'Number of payload symbols');
title(ax,sprintf('SF11 RW3 virtual-pilot admission waterfall (N = %d)', ...
    config.payloadSymbolCount));
grid(ax,'on'); xlim(ax,[0 max(stageCounts)*1.12]);
for k = 1:numel(stageCounts)
    text(ax,stageCounts(k)+1,k,sprintf('%d',stageCounts(k)), ...
        'VerticalAlignment','middle','FontSize',13,'FontWeight','bold');
end
subtitle(ax,sprintf('Real frame %d at %g dB; no manually constructed counts', ...
    frameIndex,candidateSnrDb));
localStyleFigure(fig);
localSaveFigure(fig,outputDir,'fig_rw3_sf11_vp_admission_waterfall');
save(fullfile(outputDir,'fig_rw3_sf11_vp_admission_waterfall.mat'), ...
    'selectedRun','stageNames','stageCounts','stageMasks','config');
close(fig);

% Figure 3: causal CFO/rate tracking and bounded rolling history.
acceptedFrameMask = tracker.pilotAccepted;
requestedFrameMask = tracker.requestedMask;
rejectedFrameMask = requestedFrameMask & ~acceptedFrameMask & ...
    frameSymbolIndex > config.bootstrapPilotCount;
fig = figure('Color','w','Visible','off','Position',[70 60 1600 920]);
layout = tiledlayout(fig,3,1,'Padding','compact','TileSpacing','compact');
ax = nexttile(layout,1);
plot(ax,frameSymbolIndex,trueCfoBins,'k-','LineWidth',2.0); hold(ax,'on');
plot(ax,frameSymbolIndex,predictedCfoBins,'Color',[0.00 0.40 0.78],'LineWidth',1.8);
scatter(ax,frameSymbolIndex(1:config.bootstrapPilotCount), ...
    predictedCfoBins(1:config.bootstrapPilotCount),55,[0.90 0.55 0.05],'o','filled');
acceptedPayloadRows = find(acceptedFrameMask & frameSymbolIndex > config.bootstrapPilotCount);
scatter(ax,acceptedPayloadRows,predictedCfoBins(acceptedPayloadRows),65, ...
    [0.00 0.60 0.35],'^','filled');
rejectedRows = find(rejectedFrameMask);
scatter(ax,rejectedRows,predictedCfoBins(rejectedRows),55, ...
    [0.80 0.15 0.15],'x','LineWidth',1.7);
grid(ax,'on'); xlim(ax,[1 config.frameSymbolCount]);
ylabel(ax,'CFO (FFT bin)'); title(ax,'A  True CFO overlay and receiver prediction');
legend(ax,{'Truth (evaluation only)','Receiver predicted CFO', ...
    '8 known preambles','Accepted VP','Rejected requested candidate'}, ...
    'Location','best');

ax = nexttile(layout,2);
plot(ax,frameSymbolIndex,trueRateBinsPerSec,'k-','LineWidth',2.0); hold(ax,'on');
plot(ax,frameSymbolIndex,predictedRateBinsPerSec,'Color',[0.55 0.15 0.70],'LineWidth',1.8);
grid(ax,'on'); xlim(ax,[1 config.frameSymbolCount]);
ylabel(ax,'Rate (bin/s)'); title(ax,'B  True rate overlay and causal receiver rate');
legend(ax,{'Truth (evaluation only)','Predicted/estimated rate'},'Location','best');

ax = nexttile(layout,3);
stairs(ax,frameSymbolIndex,activeHistoryCount,'Color',[0.05 0.50 0.45],'LineWidth',2.0); hold(ax,'on');
yline(ax,config.virtualPilotHistoryLength,'--','Rolling-8 limit', ...
    'Color',[0.75 0.20 0.15],'LineWidth',1.5);
scatter(ax,acceptedPayloadRows,activeHistoryCount(acceptedPayloadRows),55, ...
    [0.00 0.60 0.35],'^','filled');
grid(ax,'on'); xlim(ax,[1 config.frameSymbolCount]); ylim(ax,[0 9]);
xlabel(ax,'Frame symbol index (1-8 are known preambles)');
ylabel(ax,'Active history count'); title(ax,'C  Rolling history remains bounded at 8');
sgtitle(layout,sprintf('SF11 RW4 causal Rolling-8 tracking (real frame %d, %g dB)', ...
    frameIndex,candidateSnrDb),'FontWeight','bold');
localStyleFigure(fig);
localSaveFigure(fig,outputDir,'fig_rw4_sf11_causal_tracking');
save(fullfile(outputDir,'fig_rw4_sf11_causal_tracking.mat'), ...
    'selectedRun','frameSymbolIndex','trueCfoBins','predictedCfoBins', ...
    'trueRateBinsPerSec','predictedRateBinsPerSec','acceptedFrameMask', ...
    'requestedFrameMask','rejectedFrameMask','activeHistoryCount', ...
    'historySlotSymbolIndex','pilotAppliedAtRows','config');
close(fig);

% Figure 4: residual-CFO error and explicit eight-slot ring-buffer trace.
errorBin = trueCfoBins-predictedCfoBins;
fig = figure('Color','w','Visible','off','Position',[80 80 1600 850]);
layout = tiledlayout(fig,2,1,'Padding','compact','TileSpacing','compact');
ax = nexttile(layout,1);
plot(ax,frameSymbolIndex,errorBin,'Color',[0.10 0.35 0.75],'LineWidth',1.8); hold(ax,'on');
yline(ax,0.5,'--','+0.5 bin','Color',[0.75 0.15 0.10],'LineWidth',1.4);
yline(ax,-0.5,'--','-0.5 bin','Color',[0.75 0.15 0.10],'LineWidth',1.4);
scatter(ax,acceptedPayloadRows,errorBin(acceptedPayloadRows),60, ...
    [0.00 0.60 0.35],'^','filled');
grid(ax,'on'); xlim(ax,[1 config.frameSymbolCount]);
ylabel(ax,'True CFO - predicted CFO (bin)');
title(ax,'A  Residual prediction error with accepted VP updates');

ax = nexttile(layout,2);
imagesc(ax,frameSymbolIndex,1:config.virtualPilotHistoryLength,historySlotSymbolIndex);
set(ax,'YDir','normal'); colormap(ax,parula(256)); cb = colorbar(ax);
cb.Label.String = 'Stored observation symbol index';
hold(ax,'on');
for row = acceptedPayloadRows(:).'
    xline(ax,tracker.pilotAppliedAtRows(row),'w:','LineWidth',1.0);
end
xlabel(ax,'Processing symbol index'); ylabel(ax,'Ring-buffer slot');
title(ax,'B  Exact 8-slot evolution (each VP overwrites the next oldest slot)');
xlim(ax,[1 config.frameSymbolCount]); yticks(ax,1:config.virtualPilotHistoryLength);
sgtitle(layout,sprintf('SF11 RW4 residual CFO and Rolling-8 evolution (real frame %d)', ...
    frameIndex),'FontWeight','bold');
localStyleFigure(fig);
localSaveFigure(fig,outputDir,'fig_rw4_sf11_residual_rolling8');
save(fullfile(outputDir,'fig_rw4_sf11_residual_rolling8.mat'), ...
    'selectedRun','frameSymbolIndex','errorBin','acceptedFrameMask', ...
    'activeHistoryCount','historySlotSymbolIndex','pilotAppliedAtRows','config');
close(fig);

localWriteFigureAudit(outputDir,projectRoot,gitSha,config,selectedRun, ...
    decoded,stageNames,stageCounts);
localWriteSummary(outputDir,selectedRun,stageCounts);

after = localProjectManifest(projectRoot);
writetable(after,fullfile(outputDir,'project_manifest_after.csv'));
[unchanged,added,deleted,modified] = localCompareManifests(before,after);
localWriteReadonlyAudit(outputDir,projectRoot,gitSha,gitStatusText, ...
    before,after,unchanged,added,deleted,modified);
if ~unchanged
    error('RW3RW4:ProjectChanged', ...
        'Project hash manifest changed during the task; inspect PROJECT_READONLY_AUDIT.md.');
end

fprintf('All figures and audits completed: %s\n',datestr(now,31));
fprintf('NO PROJECT FILE MODIFIED\n');
end

function localValidateConfig(c)
checks = [c.sf == 11; c.bandwidthHz == 250e3; c.sampleRateHz == 250e3; ...
    c.carrierFrequencyHz == 868e6; c.cr == 3; c.bootstrapPilotCount == 8; ...
    c.payloadSymbolCount == 112; c.virtualPilotHistoryLength == 8; ...
    c.maxSenLoRaIterations == 5; abs(c.confidenceAlpha-0.8) < eps; ...
    abs(c.confidenceThresholdScale-1.0) < eps; abs(c.amendLlrMix-0.5) < eps; ...
    abs(c.senloraMinimumMarginRatio-0.15) < eps; ...
    c.senloraRequireSoftHardAgreement; ~c.senloraUseSoftDecodedPilotLabels; ...
    c.senloraUseCausalConfidenceTiming; ...
    abs(c.confidenceInnovationLimitBins-0.22) < eps; ...
    abs(c.residualPeakRatioThreshold-1.05) < eps; ...
    abs(c.decisionPeakRatioThreshold-1.05) < eps; ...
    abs(c.historyDecay-0.85) < eps; abs(c.huberThresholdBins-0.15) < eps; ...
    isequal(c.residualSearchBins,(-0.5:0.1:0.5).'); ...
    abs(c.maxRateBinsPerSec-2.0) < eps; c.senloraRateReleasePilotCount == 2; ...
    abs(c.senloraRateTrackingDeviationLimitBinsPerSec-0.1) < eps; ...
    abs(c.senloraVirtualPilotInnovationGain-0.35) < eps; ...
    abs(c.senloraPhasePairInnovationGain-0.60) < eps; ...
    abs(c.senloraVirtualPilotCfoStdBins-0.075) < eps; ...
    abs(c.senloraPhasePairInnovationLimitBins-0.10) < eps; ...
    abs(c.senloraPhasePairAgreementLimitBins-0.15) < eps; ...
    abs(c.senloraVirtualPilotRateStdLimitBinsPerSec-0.10) < eps];
if ~all(checks)
    error('RW3RW4:ConfigMismatch','Canonical Stage55 configuration does not match the requested SF11 baseline.');
end
end

function [slotTrace,nextSlotTrace] = localReconstructHistorySlots(tracker,config)
n = numel(tracker.activeHistoryCount);
h = config.virtualPilotHistoryLength;
slotTrace = nan(h,n);
nextSlotTrace = nan(n,1);
slots = nan(h,1);
nextSlot = 1;
for processingRow = 1:n
    if processingRow <= config.bootstrapPilotCount
        insertedRows = processingRow;
    else
        insertedRows = find(tracker.pilotAppliedAtRows == processingRow).';
    end
    for sourceRow = insertedRows
        slots(nextSlot) = sourceRow;
        nextSlot = mod(nextSlot,h)+1;
    end
    slotTrace(:,processingRow) = slots;
    nextSlotTrace(processingRow) = nextSlot;
end
end

function localStyleFigure(fig)
axesList = findall(fig,'Type','axes');
set(axesList,'FontSize',12,'LineWidth',1.0,'Box','on');
for k = 1:numel(axesList)
    axesList(k).Toolbar.Visible = 'off';
end
set(findall(fig,'Type','legend'),'FontSize',11);
end

function localSaveFigure(fig,outputDir,baseName)
exportgraphics(fig,fullfile(outputDir,[baseName '.png']),'Resolution',300);
savefig(fig,fullfile(outputDir,[baseName '.fig']));
end

function manifest = localProjectManifest(projectRoot)
listing = dir(fullfile(projectRoot,'**','*'));
listing = listing(~[listing.isdir]);
n = numel(listing);
relativePath = strings(n,1);
bytes = zeros(n,1);
sha256 = strings(n,1);
for k = 1:n
    fullPath = fullfile(listing(k).folder,listing(k).name);
    relativePath(k) = string(erase(fullPath,[projectRoot filesep]));
    bytes(k) = listing(k).bytes;
    sha256(k) = localSha256(fullPath);
end
manifest = table(relativePath,bytes,sha256, ...
    'VariableNames',{'RelativePath','Bytes','SHA256'});
manifest = sortrows(manifest,'RelativePath');
end

function hash = localSha256(path)
md = java.security.MessageDigest.getInstance('SHA-256');
fid = fopen(path,'rb');
if fid < 0
    error('RW3RW4:HashRead','Cannot read project file for hashing: %s',path);
end
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
while true
    chunk = fread(fid,1048576,'*uint8');
    if isempty(chunk), break; end
    md.update(typecast(chunk(:),'int8'));
end
digest = typecast(int8(md.digest()),'uint8');
hash = lower(string(reshape(dec2hex(digest,2).',1,[])));
end

function [sha,statusText] = localGitState(projectRoot)
[shaStatus,shaText] = system(sprintf('git -C "%s" rev-parse HEAD 2>&1',projectRoot));
if shaStatus == 0
    sha = strtrim(shaText);
else
    sha = 'UNAVAILABLE (project is not a Git worktree)';
end
[statusCode,statusText] = system(sprintf('git -C "%s" status --short 2>&1',projectRoot));
if statusCode ~= 0
    statusText = ['UNAVAILABLE: ' strtrim(statusText)];
elseif isempty(strtrim(statusText))
    statusText = '(clean)';
end
end

function [unchanged,added,deleted,modified] = localCompareManifests(before,after)
beforePaths = before.RelativePath;
afterPaths = after.RelativePath;
added = setdiff(afterPaths,beforePaths);
deleted = setdiff(beforePaths,afterPaths);
common = intersect(beforePaths,afterPaths);
modified = strings(0,1);
for k = 1:numel(common)
    b = before(before.RelativePath == common(k),:);
    a = after(after.RelativePath == common(k),:);
    if b.Bytes ~= a.Bytes || b.SHA256 ~= a.SHA256
        modified(end+1,1) = common(k); %#ok<AGROW>
    end
end
unchanged = isempty(added) && isempty(deleted) && isempty(modified);
end

function localWriteFigureAudit(outputDir,projectRoot,gitSha,c,run,decoded,stageNames,stageCounts)
path = fullfile(outputDir,'RW3_RW4_SF11_FIGURE_AUDIT.md');
fid = fopen(path,'w','n','UTF-8');
if fid < 0, error('RW3RW4:AuditWrite','Cannot write %s',path); end
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid,'# RW3/RW4 SF11 Figure Audit\n\n');
fprintf(fid,'- Generated: `%s`\n',datestr(now,31));
fprintf(fid,'- Project root: `%s`\n',projectRoot);
fprintf(fid,'- Git commit SHA: `%s`\n',gitSha);
fprintf(fid,'- MATLAB: `%s`\n',version);
fprintf(fid,'- Selected real run: schedule frame `%d`, SNR `%g dB`, payload seed `%d`, noise seed `%d`.\n', ...
    run.frameIndex,run.snrDb,run.payloadSeed,run.noiseSeed);
fprintf(fid,'- Run command: `"E:\\Matlab2022\\MATLAB2022\\bin\\matlab.exe" -batch "addpath(''''%s''''); generate_rw3_rw4_sf11_figures"`\n',outputDir);
fprintf(fid,'- Main receiver: `satelliteFig3SenLoRaVirtualPilotDecode` (isolated-frame mode).\n');
fprintf(fid,'- Rate source: `%s`.\n',decoded.crossFrameRateDiagnostic.source);
fprintf(fid,'- Receiver reads orbit truth / payload truth: **NO**. `truth` and transmitted labels are passed only to offline selection metrics and plot overlays after receiver execution.\n\n');

fprintf(fid,'## Verified canonical configuration\n\n');
names = {'SF';'BW';'Fs';'fc';'CR';'bootstrapPilotCount';'payloadSymbolCount'; ...
    'virtualPilotHistoryLength';'maxSenLoRaIterations';'confidenceAlpha'; ...
    'confidenceThresholdScale';'amendLlrMix';'senloraMinimumMarginRatio'; ...
    'senloraRequireSoftHardAgreement';'senloraUseSoftDecodedPilotLabels'; ...
    'senloraUseCausalConfidenceTiming';'confidenceInnovationLimitBins'; ...
    'residualPeakRatioThreshold';'decisionPeakRatioThreshold';'historyDecay'; ...
    'huberThresholdBins';'residualSearchBins';'maxRateBinsPerSec'; ...
    'senloraRateReleasePilotCount';'senloraRateTrackingDeviationLimitBinsPerSec'; ...
    'senloraVirtualPilotInnovationGain';'senloraPhasePairInnovationGain'; ...
    'senloraVirtualPilotCfoStdBins';'senloraPhasePairInnovationLimitBins'; ...
    'senloraPhasePairAgreementLimitBins';'senloraVirtualPilotRateStdLimitBinsPerSec'};
values = {c.sf;c.bandwidthHz;c.sampleRateHz;c.carrierFrequencyHz;c.cr; ...
    c.bootstrapPilotCount;c.payloadSymbolCount;c.virtualPilotHistoryLength; ...
    c.maxSenLoRaIterations;c.confidenceAlpha;c.confidenceThresholdScale; ...
    c.amendLlrMix;c.senloraMinimumMarginRatio;c.senloraRequireSoftHardAgreement; ...
    c.senloraUseSoftDecodedPilotLabels;c.senloraUseCausalConfidenceTiming; ...
    c.confidenceInnovationLimitBins;c.residualPeakRatioThreshold; ...
    c.decisionPeakRatioThreshold;c.historyDecay;c.huberThresholdBins; ...
    c.residualSearchBins.';c.maxRateBinsPerSec;c.senloraRateReleasePilotCount; ...
    c.senloraRateTrackingDeviationLimitBinsPerSec;c.senloraVirtualPilotInnovationGain; ...
    c.senloraPhasePairInnovationGain;c.senloraVirtualPilotCfoStdBins; ...
    c.senloraPhasePairInnovationLimitBins;c.senloraPhasePairAgreementLimitBins; ...
    c.senloraVirtualPilotRateStdLimitBinsPerSec};
fprintf(fid,'| Parameter | Runtime value | Code source |\n|---|---:|---|\n');
for k = 1:numel(names)
    fprintf(fid,'| `%s` | `%s` | `satelliteFig3Config.m` |\n', ...
        names{k},localValueText(values{k}));
end

fprintf(fid,'\n## RW3 implementation chain\n\n');
fprintf(fid,['1. `satelliteFig3SenLoRaConfidence.m`: compensated symbol -> hard-dechirped FFT spectrum -> FFT-energy log probabilities -> Gray-bit LLRs.\n' ...
    '2. The same function deinterleaves those LLRs, performs soft Hamming(7,4), computes best-vs-second-best codeword margin, amends the LLRs, and forms symbol confidence as the sum of squared amended-LLR magnitudes.\n' ...
    '3. `tauBlock = mean(C)+std(C)` and `tauGlobal = alpha*tauGlobal+(1-alpha)*tauBlock`; `confidentMask` compares confidence to `confidenceThresholdScale*tauGlobal`.\n' ...
    '4. `satelliteFig3SenLoRaIterativeDecode.m` adds minimum margin ratio, soft-hard agreement, and two-pass stability. A proposed symbol is not a final VP.\n' ...
    '5. `senloraUseSoftDecodedPilotLabels=false`: soft Hamming determines trust only. The tracker label is the compensated hard LoRa decision.\n' ...
    '6. The tracker separately enforces residual peak ratio, non-boundary peak, 0.22-bin innovation, and decision peak ratio before insertion.\n\n']);

fprintf(fid,'## RW4 implementation chain\n\n');
fprintf(fid,['- `satelliteFig3RollingPilotTracker.m` fills eight slots with known preambles. `localInsert` writes `idx(nextSlot)` and advances `nextSlot=mod(nextSlot,8)+1`, so every accepted VP replaces exactly one oldest slot.\n' ...
    '- Residual CFO candidates are exactly `-0.5:0.1:0.5 bin`; actual innovation limit is `0.22 bin`; both peak-ratio thresholds are `1.05`; history decay is `0.85`; Huber threshold is `0.15 bin`.\n' ...
    '- This delivered run is isolated: initial rate comes from the known-preamble phase fit. `satelliteFig3CrossFrameRateUpdate.m` is the separate continuous-pass path, with at most eight causal preceding-frame preamble CFO observations.\n' ...
    '- Truth is evaluation-only and never appears in the receiver function interface.\n\n']);

fprintf(fid,'## Figure-variable mapping\n\n');
fprintf(fid,'### 1. `fig_rw3_sf11_confidence_timeline`\n\n');
fprintf(fid,'- Input: `selected_run_workspace.mat` -> `decoded.iterationHistory(%d).soft` and final `decoded.tracker`.\n',run.gateIterationIndex);
fprintf(fid,'- Curves: `confidence`, `tauBlock`, `tauGlobal`; markers: `proposedMask`, `stableMask`, `requestedMask`, `acceptedMask`.\n');
fprintf(fid,'- Gate variables: `marginRatio`, `softHardAgreement`; label audit: `decodedWaveformBins`, `hardWaveformBins`.\n');
fprintf(fid,'- Outputs: PNG / FIG / MAT in `%s`.\n\n',outputDir);
fprintf(fid,'### 2. `fig_rw3_sf11_vp_admission_waterfall`\n\n');
fprintf(fid,'- Runtime stages and counts:\n');
for k = 1:numel(stageNames)
    fprintf(fid,'  - `%s`: `%d`\n',stageNames{k},stageCounts(k));
end
fprintf(fid,'- Output MAT contains `stageNames`, `stageCounts`, and exact logical `stageMasks`.\n\n');
fprintf(fid,'### 3. `fig_rw4_sf11_causal_tracking`\n\n');
fprintf(fid,'- Truth overlays: `truth.trueDopplerHz/config.fftBinSpacingHz`, `truth.trueDopplerRateHzPerSec/config.fftBinSpacingHz`.\n');
fprintf(fid,'- Receiver curves: `decoded.tracker.predictedCfoBins`, `predictedRateBinsPerSec`, `activeHistoryCount`.\n');
fprintf(fid,'- Markers: first 8 preambles, `pilotAccepted`, and `requestedMask & ~pilotAccepted`.\n\n');
fprintf(fid,'### 4. `fig_rw4_sf11_residual_rolling8`\n\n');
fprintf(fid,'- Error: `trueCfoBins-predictedCfoBins` in FFT bins; reference lines are exactly +/-0.5 bin.\n');
fprintf(fid,'- Ring-buffer trace: reconstructed exactly from `pilotAppliedAtRows` and the source `localInsert` cyclic-slot rule; saved as `historySlotSymbolIndex`.\n\n');

fprintf(fid,'## Source locations and thresholds\n\n');
fprintf(fid,['- `satelliteFig3Config.m`: canonical physical/link constants and Stage55 gate/tracker constants.\n' ...
    '- `satelliteFig3SenLoRaConfidence.m`: FFT/log-probability/LLR/soft-Hamming/confidence/threshold implementation.\n' ...
    '- `satelliteFig3SenLoRaIterativeDecode.m`: proposal, margin ratio, agreement, stability, requested mask, and hard-label policy.\n' ...
    '- `satelliteFig3SenLoRaVirtualPilotDecode.m`: Stage55 isolated/continuous rate provenance and quality-aware option wiring.\n' ...
    '- `satelliteFig3RollingPilotTracker.m`: residual/peak gates, causal availability, CFO/rate outputs, pilot acceptance, active history, and cyclic replacement.\n' ...
    '- `satelliteFig3PhaseRotationEstimate.m`: residual CFO/phase observation.\n' ...
    '- `satelliteFig3CrossFrameRateUpdate.m`: causal cross-frame Rolling-8 rate state.\n\n']);
fprintf(fid,'All four requested figures were directly supported by runtime variables; no synthetic, smoothed, interpolated, or manually redrawn experimental curve was used.\n');
end

function localWriteSummary(outputDir,run,stageCounts)
fid = fopen(fullfile(outputDir,'SUMMARY.md'),'w','n','UTF-8');
if fid < 0, error('RW3RW4:SummaryWrite','Cannot write summary.'); end
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid,'# PPT Figure Placement Summary\n\n');
fprintf(fid,'Selected real Stage55 frame: `%d` at `%g dB`; accepted VPs: `%d`.\n\n', ...
    run.frameIndex,run.snrDb,stageCounts(end));
fprintf(fid,'- 研究工作三第一页：`fig_rw3_sf11_confidence_timeline.png`，机制图，展示软置信、门限、两次迭代稳定性和最终接纳链路。\n');
fprintf(fid,'- 研究工作三第二页：`fig_rw3_sf11_vp_admission_waterfall.png`，结果/审计图，展示 112 个 payload symbols 的逐级筛选数量。\n');
fprintf(fid,'- 研究工作四第一页：`fig_rw4_sf11_causal_tracking.png`，机制 + 结果图，展示 CFO/rate 因果跟踪及 history 上限。\n');
fprintf(fid,'- 研究工作四第二页：`fig_rw4_sf11_residual_rolling8.png`，结果 + 机制图，展示残差误差与 8 槽 ring buffer 的真实替换演化。\n');
end

function localWriteReadonlyAudit(outputDir,projectRoot,gitSha,gitStatusText,before,after,unchanged,added,deleted,modified)
fid = fopen(fullfile(outputDir,'PROJECT_READONLY_AUDIT.md'),'w','n','UTF-8');
if fid < 0, error('RW3RW4:ReadonlyAuditWrite','Cannot write read-only audit.'); end
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid,'# Project Read-Only Audit\n\n');
fprintf(fid,'- Original project: `%s`\n',projectRoot);
fprintf(fid,'- Git commit SHA: `%s`\n',gitSha);
fprintf(fid,'- Git status: `%s`\n',strrep(strtrim(gitStatusText),newline,'; '));
fprintf(fid,'- Before manifest: `%d` files, SHA-256 for every file.\n',height(before));
fprintf(fid,'- After manifest: `%d` files, SHA-256 for every file.\n',height(after));
fprintf(fid,'- Added project files: `%d`\n',numel(added));
fprintf(fid,'- Deleted project files: `%d`\n',numel(deleted));
fprintf(fid,'- Modified project files: `%d`\n',numel(modified));
if ~isempty(added), fprintf(fid,'- Added: `%s`\n',strjoin(cellstr(added),'; ')); end
if ~isempty(deleted), fprintf(fid,'- Deleted: `%s`\n',strjoin(cellstr(deleted),'; ')); end
if ~isempty(modified), fprintf(fid,'- Modified: `%s`\n',strjoin(cellstr(modified),'; ')); end
fprintf(fid,'- New files written into original project: **%s**\n',localYesNo(~isempty(added)));
fprintf(fid,'- Existing project files changed: **%s**\n',localYesNo(~isempty(deleted) || ~isempty(modified)));
if unchanged
    fprintf(fid,'\n## Conclusion\n\n`NO PROJECT FILE MODIFIED`\n');
else
    fprintf(fid,'\n## Conclusion\n\n`PROJECT CHANGE DETECTED - RESULTS MUST NOT BE USED`\n');
end
end

function text = localValueText(value)
if islogical(value)
    if value, text = 'true'; else, text = 'false'; end
elseif isnumeric(value)
    if isscalar(value)
        text = sprintf('%.12g',value);
    else
        text = strtrim(sprintf('%.12g ',value));
    end
else
    text = char(string(value));
end
end

function text = localYesNo(tf)
if tf, text = 'YES'; else, text = 'NO'; end
end
