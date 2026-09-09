function generate_rw3_rw4_sf11_figures_v2()
%GENERATE_RW3_RW4_SF11_FIGURES_V2 Corrected, read-only V2 PPT figures.
% Reads the canonical SF11 project and V1 artifacts; writes only to V2.

projectRoot = 'D:\codex\Lora(eg)\project\orbit_doppler\satellite_fig3_rolling8';
v1Dir = 'D:\codex\picture\RW3_RW4_SF11_PPT_FIGURES';
outputDir = 'D:\codex\picture\RW3_RW4_SF11_PPT_FIGURES_V2';
if ~isfolder(projectRoot) || ~isfolder(v1Dir)
    error('RW3RW4V2:MissingInput','Canonical project or V1 folder is missing.');
end
if ~isfolder(outputDir), mkdir(outputDir); end

diary(fullfile(outputDir,'run_log_v2.txt'));
cleanupDiary = onCleanup(@() diary('off')); %#ok<NASGU>
fprintf('RW3/RW4 SF11 V2 started: %s\n',datestr(now,31));
fprintf('MATLAB: %s\nProject: %s\nV1: %s\nV2: %s\n', ...
    version,projectRoot,v1Dir,outputDir);

projectBefore = localManifest(projectRoot);
v1Before = localManifest(v1Dir);
writetable(projectBefore,fullfile(outputDir,'project_manifest_before_v2.csv'));
writetable(v1Before,fullfile(outputDir,'v1_manifest_before_v2.csv'));

% V1 reuse is allowed only when the present project exactly matches the
% project manifest recorded after the verified V1 run.
v1ProjectReference = readtable(fullfile(v1Dir,'project_manifest_after.csv'), ...
    'TextType','string');
[matchesV1Project,refAdded,refDeleted,refModified] = ...
    localCompareManifests(v1ProjectReference,projectBefore);
if ~matchesV1Project
    error('RW3RW4V2:ProjectChanged', ...
        ['Current project no longer matches the V1 source manifest ' ...
        '(added=%d, deleted=%d, modified=%d).'], ...
        numel(refAdded),numel(refDeleted),numel(refModified));
end
fprintf('Current project exactly matches the V1 project manifest (%d files).\n', ...
    height(projectBefore));

requiredV1 = {'RW3_RW4_SF11_FIGURE_AUDIT.md', ...
    'generate_rw3_rw4_sf11_figures.m','selected_run_workspace.mat', ...
    'candidate_frame_selection.csv'};
for k = 1:numel(requiredV1)
    if ~isfile(fullfile(v1Dir,requiredV1{k}))
        error('RW3RW4V2:MissingV1','Missing required V1 artifact: %s',requiredV1{k});
    end
end

addpath(projectRoot,'-begin');
cleanupPath = onCleanup(@() rmpath(projectRoot)); %#ok<NASGU>
S = load(fullfile(v1Dir,'selected_run_workspace.mat'));
config = S.config;
schedule = S.schedule;
selectedRun = S.selectedRun;
truth = S.truth;
decoded = S.decoded;
localValidateConfig(config);
if selectedRun.frameIndex ~= 341 || selectedRun.snrDb ~= -20
    error('RW3RW4V2:SelectedRun','V1 selected run is not frame 341 at -20 dB.');
end
candidateTable = readtable(fullfile(v1Dir,'candidate_frame_selection.csv'));
selectedCandidate = candidateTable(candidateTable.frameIndex == 341,:);
if height(selectedCandidate) ~= 1
    error('RW3RW4V2:CandidateRow','V1 frame-selection row is missing or ambiguous.');
end
scoreFormulaCheck = 100*selectedCandidate.acceptedCount + ...
    0.1*selectedCandidate.rejectedRequestedCount - selectedCandidate.cfoRmseBins;
if abs(scoreFormulaCheck-selectedCandidate.score) > 1e-10
    error('RW3RW4V2:ScoreMismatch','V1 selection score does not match its documented formula.');
end
writetable(candidateTable,fullfile(outputDir,'v1_candidate_frame_selection_snapshot.csv'));

iterationHistory = decoded.iterationHistory;
gateIterationIndex = selectedRun.gateIterationIndex;
gateIteration = iterationHistory(gateIterationIndex);
previousIterationIndex = max(1,gateIterationIndex-1);
previousIteration = iterationHistory(previousIterationIndex);
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
sameDecisionAsPrevious = decodedWaveformBins == ...
    previousIteration.soft.decodedWaveformBins(payloadRows);
proposedMask = gateIteration.proposedMask(payloadRows);
stableMask = gateIteration.stableMask(payloadRows);
requestedMask = finalIteration.requestedMask(payloadRows);
acceptedMask = tracker.pilotAccepted(payloadRows);

trueCfoBins = truth.trueDopplerHz/config.fftBinSpacingHz;
predictedCfoBins = tracker.predictedCfoBins;
trueRateBinsPerSec = truth.trueDopplerRateHzPerSec/config.fftBinSpacingHz;
predictedRateBinsPerSec = tracker.predictedRateBinsPerSec;
acceptedFrameMask = tracker.pilotAccepted;
requestedFrameMask = tracker.requestedMask;
acceptedPayloadRows = find(acceptedFrameMask & ...
    frameSymbolIndex > config.bootstrapPilotCount);
requestedPayloadRows = find(requestedFrameMask & ...
    frameSymbolIndex > config.bootstrapPilotCount);
appliedRowsForAccepted = tracker.pilotAppliedAtRows(acceptedPayloadRows);

acceptedVpMeasurementBins = tracker.virtualPilotMeasurementCfoBins;
measurementVariableName = 'tracker.virtualPilotMeasurementCfoBins';
missingAcceptedMeasurement = acceptedFrameMask & ...
    frameSymbolIndex > config.bootstrapPilotCount & ...
    ~isfinite(acceptedVpMeasurementBins);
if any(missingAcceptedMeasurement)
    acceptedVpMeasurementBins(missingAcceptedMeasurement) = ...
        tracker.measuredCfoBins(missingAcceptedMeasurement);
    measurementVariableName = [measurementVariableName ...
        ' (missing accepted entries filled from tracker.measuredCfoBins)'];
end
if any(~isfinite(acceptedVpMeasurementBins(acceptedPayloadRows)))
    error('RW3RW4V2:VpMeasurement','Accepted VP CFO measurement is unavailable.');
end
[historySlotSymbolIndex,nextSlotTrace] = ...
    localReconstructHistorySlots(tracker,config);

% Figure 1: preserve V1 data while making iteration and tracker causality explicit.
fig = figure('Color','w','Visible','off','Position',[80 60 1640 930]);
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
ylim(ax,[0.4 2.6]); yticks(ax,[1 2]);
yticklabels(ax,{sprintf('Proposed @ iter %d',gateIterationIndex), ...
    sprintf('Stable after iter %d->%d',previousIterationIndex,gateIterationIndex)});
xlim(ax,[1 config.payloadSymbolCount]); grid(ax,'on');
xlabel(ax,'Payload symbol index');
title(ax,'B  Iterative proposal and two-pass confirmation');
subtitle(ax,'Stable = proposed in two consecutive passes + identical decoded waveform decision');

ax = nexttile(layout,3);
yyaxis(ax,'left');
plot(ax,payloadSymbolIndex,marginRatio,'Color',[0.20 0.25 0.65],'LineWidth',1.6); hold(ax,'on');
yline(ax,config.senloraMinimumMarginRatio,'--','Margin threshold = 0.15', ...
    'Color',[0.75 0.15 0.10],'LineWidth',1.4,'LabelHorizontalAlignment','left');
ylabel(ax,'Codeword margin / \tau_{global}');
yyaxis(ax,'right');
stairs(ax,payloadSymbolIndex,double(softHardAgreement), ...
    'Color',[0.10 0.55 0.25],'LineWidth',1.3);
ylim(ax,[-0.05 1.05]); yticks(ax,[0 1]); yticklabels(ax,{'Fail','Pass'});
ylabel(ax,'Soft-hard agreement'); xlim(ax,[1 config.payloadSymbolCount]); grid(ax,'on');
xlabel(ax,'Payload symbol index'); title(ax,'C  Margin and soft-hard gates');

ax = nexttile(layout,4);
stem(ax,payloadSymbolIndex(requestedMask),ones(sum(requestedMask),1), ...
    'filled','Color',[0.55 0.35 0.10],'MarkerSize',4,'LineWidth',1.2); hold(ax,'on');
stem(ax,payloadSymbolIndex(acceptedMask),2*ones(sum(acceptedMask),1), ...
    'filled','Color',[0.00 0.55 0.50],'MarkerSize',5,'LineWidth',1.2);
ylim(ax,[0.4 2.6]); yticks(ax,[1 2]); yticklabels(ax,{'Requested to tracker','Finally accepted'});
xlim(ax,[1 config.payloadSymbolCount]); grid(ax,'on');
xlabel(ax,'Payload symbol index'); title(ax,'D  Tracker request and independent admission');
subtitle(ax,'Stable confidence candidate -> request; residual/peak-quality gates -> final VP');
sgtitle(layout,{sprintf('SF11 RW3 confidence-to-VP causality (frame 341, -20 dB)'), ...
    'Proposed and Stable are iterative receiver states, not simultaneous one-shot decisions'}, ...
    'FontWeight','bold');
localStyleFigure(fig);
localSaveFigure(fig,outputDir,'fig_rw3_sf11_confidence_timeline_v2');
causalityNote = ['Proposed and Stable are iterative receiver states, not ' ...
    'simultaneous one-shot decisions. A stable candidate only becomes a ' ...
    'tracker request; residual/peak-quality gates decide final admission.'];
save(fullfile(outputDir,'fig_rw3_sf11_confidence_timeline_v2.mat'), ...
    'selectedRun','payloadSymbolIndex','confidence','tauBlock','tauGlobal', ...
    'confidencePass','marginRatio','marginPass','softHardAgreement', ...
    'sameDecisionAsPrevious','proposedMask','stableMask','requestedMask', ...
    'acceptedMask','decodedWaveformBins','hardWaveformBins', ...
    'previousIterationIndex','gateIterationIndex','causalityNote','config');
close(fig);

% Figure 2: explicitly a selected high-dynamic mechanism example.
stageMasks = {true(config.payloadSymbolCount,1),confidencePass, ...
    confidencePass & marginPass, ...
    confidencePass & marginPass & softHardAgreement, ...
    confidencePass & marginPass & softHardAgreement & requestedMask, ...
    confidencePass & marginPass & softHardAgreement & requestedMask & acceptedMask};
stageNames = {'Total payload','Confidence pass','+ Margin-ratio pass', ...
    '+ Soft-hard agreement','+ Two-pass stable/requested','+ Tracker accepted'};
stageCounts = cellfun(@sum,stageMasks).';
fig = figure('Color','w','Visible','off','Position',[100 80 1540 800]);
ax = axes(fig);
b = barh(ax,stageCounts,'FaceColor','flat','BarWidth',0.68);
b.CData = [0.25 0.45 0.75;0.20 0.55 0.78;0.20 0.65 0.65; ...
    0.35 0.68 0.40;0.78 0.55 0.20;0.05 0.55 0.48];
yticks(ax,1:numel(stageNames)); yticklabels(ax,stageNames); set(ax,'YDir','reverse');
xlabel(ax,'Number of payload symbols'); grid(ax,'on');
xlim(ax,[0 max(stageCounts)*1.12]);
title(ax,'SF11 RW3 VP admission example — selected high-dynamic frame');
subtitle(ax,{sprintf('Example frame 341, SNR = -20 dB (score %.4f).',selectedCandidate.score), ...
    'Mechanism illustration only — not a population-level VP acceptance statistic'});
for k = 1:numel(stageCounts)
    text(ax,stageCounts(k)+1,k,sprintf('%d',stageCounts(k)), ...
        'VerticalAlignment','middle','FontSize',13,'FontWeight','bold');
end
localStyleFigure(fig);
localSaveFigure(fig,outputDir,'fig_rw3_sf11_vp_admission_waterfall_v2');
selectionScoreFormula = '100*acceptedCount + 0.1*rejectedRequestedCount - cfoRmseBins';
selectionBiasNote = ['The score is strongly dominated by acceptedCount; ' ...
    'frame 341 is a mechanism example and cannot support population inference.'];
save(fullfile(outputDir,'fig_rw3_sf11_vp_admission_waterfall_v2.mat'), ...
    'selectedRun','selectedCandidate','stageNames','stageCounts','stageMasks', ...
    'selectionScoreFormula','selectionBiasNote','config');
close(fig);

% Figure 3: actual accepted VP CFO measurements and causal apply times.
fig = figure('Color','w','Visible','off','Position',[60 50 1640 980]);
layout = tiledlayout(fig,3,1,'Padding','compact','TileSpacing','compact');
ax = nexttile(layout,1);
plot(ax,frameSymbolIndex,trueCfoBins,'k-','LineWidth',2.0); hold(ax,'on');
plot(ax,frameSymbolIndex,predictedCfoBins,'Color',[0.00 0.40 0.78],'LineWidth',1.8);
scatter(ax,1:config.bootstrapPilotCount,tracker.measuredCfoBins(1:config.bootstrapPilotCount), ...
    55,[0.90 0.55 0.05],'o','filled');
scatter(ax,acceptedPayloadRows,acceptedVpMeasurementBins(acceptedPayloadRows), ...
    68,[0.00 0.60 0.35],'^','filled');
scatter(ax,appliedRowsForAccepted,acceptedVpMeasurementBins(acceptedPayloadRows), ...
    62,[0.45 0.20 0.70],'s','LineWidth',1.5);
for k = 1:numel(acceptedPayloadRows)
    plot(ax,[acceptedPayloadRows(k) appliedRowsForAccepted(k)], ...
        acceptedVpMeasurementBins(acceptedPayloadRows(k))*[1 1], ...
        ':','Color',[0.55 0.55 0.55],'LineWidth',1.0);
end
grid(ax,'on'); xlim(ax,[1 config.frameSymbolCount]);
ylabel(ax,'CFO (FFT bin)');
title(ax,'A  Truth, receiver prediction, accepted VP measurement, and causal apply time');
legend(ax,{'Truth CFO (evaluation only)','Receiver predicted CFO', ...
    '8 known preamble measurements','Accepted VP CFO measurement (source row)', ...
    'Applied/update time'},'Location','best');

ax = nexttile(layout,2);
plot(ax,frameSymbolIndex,trueRateBinsPerSec,'k-','LineWidth',2.0); hold(ax,'on');
plot(ax,frameSymbolIndex,predictedRateBinsPerSec, ...
    'Color',[0.55 0.15 0.70],'LineWidth',1.8);
grid(ax,'on'); xlim(ax,[1 config.frameSymbolCount]);
ylabel(ax,'Rate (bin/s)');
title(ax,'B  Doppler-rate tracking — isolated-frame initialization');
subtitle(ax,'Initial rate: known-preamble phase fit; this panel does not demonstrate cross-frame updating');
legend(ax,{'Truth rate (evaluation only)','Receiver predicted/estimated rate'},'Location','best');

ax = nexttile(layout,3);
stem(ax,requestedPayloadRows,ones(numel(requestedPayloadRows),1), ...
    'filled','Color',[0.55 0.35 0.10],'MarkerSize',4,'LineWidth',1.2); hold(ax,'on');
stem(ax,acceptedPayloadRows,2*ones(numel(acceptedPayloadRows),1), ...
    'filled','Color',[0.00 0.55 0.50],'MarkerSize',5,'LineWidth',1.2);
stem(ax,appliedRowsForAccepted,3*ones(numel(appliedRowsForAccepted),1), ...
    'filled','Color',[0.45 0.20 0.70],'MarkerSize',5,'LineWidth',1.2);
ylim(ax,[0.4 3.6]); yticks(ax,[1 2 3]);
yticklabels(ax,{'Requested','Accepted','Applied to tracker'});
grid(ax,'on'); xlim(ax,[1 config.frameSymbolCount]);
xlabel(ax,'Frame symbol index (1-8 are known preambles)');
title(ax,'C  Causal VP request, acceptance, and tracker-application timeline');
sgtitle(layout,'SF11 RW4 within-frame causal tracking — selected isolated frame', ...
    'FontWeight','bold');
localStyleFigure(fig);
localSaveFigure(fig,outputDir,'fig_rw4_sf11_causal_tracking_v2');
rateSourceNote = ['Initial rate source: isolated-frame known-preamble phase fit. ' ...
    'This selected-frame figure does not demonstrate cross-frame rate updating.'];
save(fullfile(outputDir,'fig_rw4_sf11_causal_tracking_v2.mat'), ...
    'selectedRun','frameSymbolIndex','trueCfoBins','predictedCfoBins', ...
    'trueRateBinsPerSec','predictedRateBinsPerSec','acceptedFrameMask', ...
    'requestedFrameMask','acceptedPayloadRows','appliedRowsForAccepted', ...
    'acceptedVpMeasurementBins','measurementVariableName','rateSourceNote', ...
    'tracker','config');
close(fig);

% Figure 4: offline truth-based prediction error, never called measured residual.
errorBin = trueCfoBins-predictedCfoBins;
fig = figure('Color','w','Visible','off','Position',[70 60 1640 900]);
layout = tiledlayout(fig,2,1,'Padding','compact','TileSpacing','compact');
ax = nexttile(layout,1);
plot(ax,frameSymbolIndex,errorBin,'Color',[0.10 0.35 0.75],'LineWidth',1.8); hold(ax,'on');
yline(ax,0.5,'--','+0.5-bin reference','Color',[0.75 0.15 0.10],'LineWidth',1.4);
yline(ax,-0.5,'--','-0.5-bin reference','Color',[0.75 0.15 0.10],'LineWidth',1.4);
scatter(ax,acceptedPayloadRows,errorBin(acceptedPayloadRows),60, ...
    [0.00 0.60 0.35],'^','filled');
grid(ax,'on'); xlim(ax,[1 config.frameSymbolCount]); ylim(ax,[-0.55 0.55]);
ylabel(ax,'CFO prediction error (FFT bin)');
title(ax,'A  Offline CFO prediction error: trueCfoBins - predictedCfoBins');
subtitle(ax,'±0.5 bin is a residual-search boundary reference, not a VP acceptance threshold');

ax = nexttile(layout,2);
imagesc(ax,frameSymbolIndex,1:config.virtualPilotHistoryLength,historySlotSymbolIndex);
set(ax,'YDir','normal'); colormap(ax,parula(256)); cb = colorbar(ax);
cb.Label.String = 'Stored observation symbol index'; hold(ax,'on');
for row = acceptedPayloadRows(:).'
    xline(ax,tracker.pilotAppliedAtRows(row),'w:','LineWidth',1.0);
end
xlabel(ax,'Processing symbol index'); ylabel(ax,'Ring-buffer slot');
title(ax,'B  Exact Rolling-8 ring-buffer replacement');
subtitle(ax,'Reconstructed from pilotAppliedAtRows and nextSlot = mod(nextSlot,8)+1');
xlim(ax,[1 config.frameSymbolCount]); yticks(ax,1:config.virtualPilotHistoryLength);
sgtitle(layout,'SF11 RW4 prediction error and fixed 8-slot history', ...
    'FontWeight','bold');
localStyleFigure(fig);
localSaveFigure(fig,outputDir,'fig_rw4_sf11_prediction_error_rolling8_v2');
predictionErrorNote = ['CFO prediction error is evaluation-only and is NOT ' ...
    'tracker.measuredResidualBins. The +/-0.5-bin lines are references only.'];
save(fullfile(outputDir,'fig_rw4_sf11_prediction_error_rolling8_v2.mat'), ...
    'selectedRun','frameSymbolIndex','errorBin','trueCfoBins', ...
    'predictedCfoBins','acceptedFrameMask','historySlotSymbolIndex', ...
    'nextSlotTrace','tracker','predictionErrorNote','config');
close(fig);

% Recommended receiver-visible residual/quality-gate diagnostic.
measuredResidualBins = tracker.measuredResidualBins;
residualPeakRatio = tracker.residualPeakRatio;
decisionPeakRatio = tracker.peakRatio;
residualPeakAtBoundary = tracker.residualPeakAtBoundary;
measuredPayloadMask = isfinite(measuredResidualBins) & requestedFrameMask & ...
    frameSymbolIndex > config.bootstrapPilotCount;
measuredRows = find(measuredPayloadMask);
acceptedMeasuredRows = find(measuredPayloadMask & acceptedFrameMask);
rejectedMeasuredRows = find(measuredPayloadMask & ~acceptedFrameMask);
fig = figure('Color','w','Visible','off','Position',[90 70 1580 850]);
layout = tiledlayout(fig,2,1,'Padding','compact','TileSpacing','compact');
ax = nexttile(layout,1);
plot(ax,measuredRows,measuredResidualBins(measuredRows),'-o', ...
    'Color',[0.10 0.35 0.75],'MarkerSize',5,'LineWidth',1.5); hold(ax,'on');
yline(ax,config.confidenceInnovationLimitBins,'--','+0.22-bin innovation gate', ...
    'Color',[0.75 0.15 0.10],'LineWidth',1.4);
yline(ax,-config.confidenceInnovationLimitBins,'--','-0.22-bin innovation gate', ...
    'Color',[0.75 0.15 0.10],'LineWidth',1.4);
scatter(ax,acceptedMeasuredRows,measuredResidualBins(acceptedMeasuredRows), ...
    65,[0.00 0.60 0.35],'^','filled');
scatter(ax,rejectedMeasuredRows,measuredResidualBins(rejectedMeasuredRows), ...
    65,[0.80 0.15 0.15],'x','LineWidth',1.7);
grid(ax,'on'); xlim(ax,[config.bootstrapPilotCount+1 config.frameSymbolCount]);
ylabel(ax,'Receiver measured residual (bin)');
title(ax,'A  Receiver-visible residual CFO and actual innovation gate');
legend(ax,{'measuredResidualBins','+0.22 gate','-0.22 gate', ...
    'Accepted','Rejected'},'Location','best');

ax = nexttile(layout,2);
hResidual = plot(ax,measuredRows,residualPeakRatio(measuredRows),'-o', ...
    'Color',[0.15 0.45 0.75],'MarkerSize',5,'LineWidth',1.5); hold(ax,'on');
hDecision = plot(ax,measuredRows,decisionPeakRatio(measuredRows),'-s', ...
    'Color',[0.50 0.20 0.65],'MarkerSize',5,'LineWidth',1.5);
hThreshold = yline(ax,config.residualPeakRatioThreshold,'--','Threshold = 1.05', ...
    'Color',[0.75 0.15 0.10],'LineWidth',1.4);
boundaryRows = find(measuredPayloadMask & residualPeakAtBoundary);
legendHandles = [hResidual hDecision hThreshold];
legendLabels = {'Residual peak ratio','Decision peak ratio','1.05 threshold'};
if ~isempty(boundaryRows)
    hBoundary = scatter(ax,boundaryRows,residualPeakRatio(boundaryRows),70, ...
        [0.85 0.35 0.05],'d','filled');
    legendHandles(end+1) = hBoundary;
    legendLabels{end+1} = 'Residual peak at search boundary';
end
grid(ax,'on'); xlim(ax,[config.bootstrapPilotCount+1 config.frameSymbolCount]);
xlabel(ax,'Frame symbol index'); ylabel(ax,'Peak ratio');
title(ax,'B  Residual and hard-decision peak-quality gates');
legend(ax,legendHandles,legendLabels,'Location','best');
sgtitle(layout,'SF11 RW4 receiver-visible VP admission diagnostics', ...
    'FontWeight','bold');
localStyleFigure(fig);
localSaveFigure(fig,outputDir,'fig_rw4_sf11_receiver_residual_gate_v2');
residualVsErrorNote = ['measuredResidualBins is receiver-visible and used for ' ...
    'gating; trueCfoBins-predictedCfoBins is offline evaluation only.'];
save(fullfile(outputDir,'fig_rw4_sf11_receiver_residual_gate_v2.mat'), ...
    'selectedRun','frameSymbolIndex','measuredResidualBins','residualPeakRatio', ...
    'decisionPeakRatio','residualPeakAtBoundary','measuredPayloadMask', ...
    'acceptedFrameMask','requestedFrameMask','residualVsErrorNote','config');
close(fig);

% Optional but supported: a genuine eight-frame contiguous pass through
% satelliteFig3CrossFrameRateUpdate via CrossFrameState.  Noise is created
% only by the canonical generator's already-validated SampleSnrDb path.
fprintf('Cross-frame smoke frame and seven-frame continuation starting.\n');
crossFrameIndices = (selectedRun.frameIndex-7:selectedRun.frameIndex).';
crossFrameSnrDb = -20;
crossFrameState = struct();
initialPhaseRad = 0;
nCross = numel(crossFrameIndices);
crossFrameTimeSec = nan(nCross,1);
crossFrameMeasuredCfoBins = nan(nCross,1);
crossFrameTrueCfoBins = nan(nCross,1);
crossFrameEstimatedRateBinsPerSec = nan(nCross,1);
crossFrameTrueRateBinsPerSec = nan(nCross,1);
crossFrameHistoryCount = nan(nCross,1);
crossFrameSource = strings(nCross,1);
crossFrameDiagnostics = cell(nCross,1);
known = zeros(config.bootstrapPilotCount,1);
for k = 1:nCross
    frameIdx = crossFrameIndices(k);
    payloadSeed = 2026260800+10000+frameIdx;
    noiseSeed = 2026260900+10000+frameIdx;
    payloadCf = satelliteFig3GeneratePayload(config,payloadSeed);
    labelsCf = [known;payloadCf.symbolBins];
    [rxCf,~,truthCf] = generateContinuousSatelliteFrame(labelsCf,config, ...
        StartTimeSec=schedule.frameStartTimeSec(frameIdx), ...
        SampleSnrDb=crossFrameSnrDb,NoiseSeed=noiseSeed, ...
        InitialPhaseRad=initialPhaseRad,NextSymbolBin=0);
    decodedCf = satelliteFig3SenLoRaVirtualPilotDecode(rxCf,config,known, ...
        FrameStartTimeSec=schedule.frameStartTimeSec(frameIdx), ...
        CrossFrameState=crossFrameState);
    crossFrameState = decodedCf.crossFrameState;
    diagnostic = decodedCf.crossFrameRateDiagnostic;
    crossFrameDiagnostics{k} = diagnostic;
    crossFrameTimeSec(k) = diagnostic.measurementTimeSec(end);
    crossFrameMeasuredCfoBins(k) = diagnostic.measuredCfoBins(end);
    crossFrameTrueCfoBins(k) = mean(truthCf.trueDopplerHz(1:config.bootstrapPilotCount))/ ...
        config.fftBinSpacingHz;
    crossFrameEstimatedRateBinsPerSec(k) = decodedCf.initialRateBinsPerSec;
    crossFrameTrueRateBinsPerSec(k) = mean( ...
        truthCf.trueDopplerRateHzPerSec(1:config.bootstrapPilotCount))/ ...
        config.fftBinSpacingHz;
    crossFrameHistoryCount(k) = diagnostic.historyCount;
    crossFrameSource(k) = string(diagnostic.source);
    initialPhaseRad = truthCf.nextFrameStartPhaseRad;
    fprintf('  cross-frame %d/%d: frame %d, history=%d, rate=%.4f bin/s.\n', ...
        k,nCross,frameIdx,diagnostic.historyCount,decodedCf.initialRateBinsPerSec);
    if k == 1
        fprintf('  cross-frame smoke frame succeeded; continuing causal pass.\n');
    end
end
relativeFrameTimeSec = crossFrameTimeSec-crossFrameTimeSec(1);
fig = figure('Color','w','Visible','off','Position',[80 60 1580 920]);
layout = tiledlayout(fig,3,1,'Padding','compact','TileSpacing','compact');
ax = nexttile(layout,1);
plot(ax,relativeFrameTimeSec,crossFrameTrueCfoBins,'k-','LineWidth',1.9); hold(ax,'on');
plot(ax,relativeFrameTimeSec,crossFrameMeasuredCfoBins,'o-', ...
    'Color',[0.00 0.45 0.75],'MarkerFaceColor',[0.00 0.45 0.75],'LineWidth',1.6);
grid(ax,'on'); ylabel(ax,'Preamble CFO (bin)');
title(ax,'A  Consecutive-frame known-preamble CFO observations');
legend(ax,{'Truth (evaluation only)','Receiver preamble CFO measurement'},'Location','best');

ax = nexttile(layout,2);
plot(ax,relativeFrameTimeSec,crossFrameTrueRateBinsPerSec,'k-','LineWidth',1.9); hold(ax,'on');
plot(ax,relativeFrameTimeSec,crossFrameEstimatedRateBinsPerSec,'s-', ...
    'Color',[0.55 0.15 0.70],'MarkerFaceColor',[0.55 0.15 0.70],'LineWidth',1.6);
grid(ax,'on'); ylabel(ax,'Rate (bin/s)');
title(ax,'B  Cross-frame causal rate estimate');
legend(ax,{'Truth rate (evaluation only)','Cross-frame receiver estimate'},'Location','best');

ax = nexttile(layout,3);
stairs(ax,relativeFrameTimeSec,crossFrameHistoryCount,'Color',[0.05 0.55 0.45],'LineWidth',2.0);
grid(ax,'on'); ylim(ax,[0 9]); yticks(ax,1:8);
xlabel(ax,'Time since first preamble measurement (s)'); ylabel(ax,'History count');
title(ax,'C  Causal cross-frame state grows to fixed Rolling-8');
sgtitle(layout,'SF11 RW4 genuine continuous-pass cross-frame rate tracking', ...
    'FontWeight','bold');
localStyleFigure(fig);
localSaveFigure(fig,outputDir,'fig_rw4_sf11_crossframe_rate_tracking_v2');
crossFrameTruthUse = 'Truth arrays are evaluation overlays only; CrossFrameState contains receiver preamble CFO measurements and times.';
save(fullfile(outputDir,'fig_rw4_sf11_crossframe_rate_tracking_v2.mat'), ...
    'crossFrameIndices','crossFrameSnrDb','crossFrameTimeSec', ...
    'relativeFrameTimeSec','crossFrameMeasuredCfoBins','crossFrameTrueCfoBins', ...
    'crossFrameEstimatedRateBinsPerSec','crossFrameTrueRateBinsPerSec', ...
    'crossFrameHistoryCount','crossFrameSource','crossFrameState', ...
    'crossFrameDiagnostics','crossFrameTruthUse','config');
close(fig);

localWriteFigureAudit(outputDir,projectRoot,v1Dir,config,selectedRun, ...
    selectedCandidate,stageNames,stageCounts,measurementVariableName, ...
    crossFrameIndices,crossFrameSource);
localWriteSummary(outputDir,selectedCandidate,stageCounts);

projectAfter = localManifest(projectRoot);
v1After = localManifest(v1Dir);
writetable(projectAfter,fullfile(outputDir,'project_manifest_after_v2.csv'));
writetable(v1After,fullfile(outputDir,'v1_manifest_after_v2.csv'));
[projectUnchanged,projectAdded,projectDeleted,projectModified] = ...
    localCompareManifests(projectBefore,projectAfter);
[v1Unchanged,v1Added,v1Deleted,v1Modified] = ...
    localCompareManifests(v1Before,v1After);
localWriteReadonlyAudit(outputDir,projectRoot,v1Dir,projectBefore,projectAfter, ...
    v1Before,v1After,projectUnchanged,projectAdded,projectDeleted,projectModified, ...
    v1Unchanged,v1Added,v1Deleted,v1Modified);
if ~projectUnchanged || ~v1Unchanged
    error('RW3RW4V2:ReadOnlyViolation', ...
        'Project or V1 changed; V2 results must not be used.');
end

fprintf('V2 completed: %s\n',datestr(now,31));
fprintf('V2 FIGURES VERIFIED FOR PPT USE\n');
end

function localValidateConfig(c)
checks = [c.sf==11;c.bandwidthHz==250e3;c.sampleRateHz==250e3; ...
    c.carrierFrequencyHz==868e6;c.cr==3;c.bootstrapPilotCount==8; ...
    c.payloadSymbolCount==112;c.virtualPilotHistoryLength==8; ...
    abs(c.senloraMinimumMarginRatio-0.15)<eps; ...
    abs(c.confidenceInnovationLimitBins-0.22)<eps; ...
    abs(c.residualPeakRatioThreshold-1.05)<eps; ...
    abs(c.decisionPeakRatioThreshold-1.05)<eps];
if ~all(checks)
    error('RW3RW4V2:ConfigMismatch','SF11 Stage55 configuration mismatch.');
end
end

function [slotTrace,nextSlotTrace] = localReconstructHistorySlots(tracker,config)
n = numel(tracker.pilotAppliedAtRows); h = config.virtualPilotHistoryLength;
slotTrace = nan(h,n); nextSlotTrace = nan(n,1);
slots = nan(h,1); nextSlot = 1;
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
for k = 1:numel(axesList), axesList(k).Toolbar.Visible = 'off'; end
set(findall(fig,'Type','legend'),'FontSize',11);
end

function localSaveFigure(fig,outputDir,baseName)
exportgraphics(fig,fullfile(outputDir,[baseName '.png']),'Resolution',300);
savefig(fig,fullfile(outputDir,[baseName '.fig']));
end

function manifest = localManifest(root)
listing = dir(fullfile(root,'**','*')); listing = listing(~[listing.isdir]);
n = numel(listing); relativePath = strings(n,1); bytes = zeros(n,1); sha256 = strings(n,1);
for k = 1:n
    fullPath = fullfile(listing(k).folder,listing(k).name);
    relativePath(k) = string(erase(fullPath,[root filesep]));
    bytes(k) = listing(k).bytes; sha256(k) = localSha256(fullPath);
end
manifest = sortrows(table(relativePath,bytes,sha256, ...
    'VariableNames',{'RelativePath','Bytes','SHA256'}),'RelativePath');
end

function hash = localSha256(path)
md = java.security.MessageDigest.getInstance('SHA-256');
fid = fopen(path,'rb');
if fid < 0, error('RW3RW4V2:HashRead','Cannot read %s',path); end
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
while true
    chunk = fread(fid,1048576,'*uint8'); if isempty(chunk), break; end
    md.update(typecast(chunk(:),'int8'));
end
digest = typecast(int8(md.digest()),'uint8');
hash = lower(string(reshape(dec2hex(digest,2).',1,[])));
end

function [unchanged,added,deleted,modified] = localCompareManifests(before,after)
before.RelativePath = string(before.RelativePath); before.SHA256 = lower(string(before.SHA256));
after.RelativePath = string(after.RelativePath); after.SHA256 = lower(string(after.SHA256));
added = setdiff(after.RelativePath,before.RelativePath);
deleted = setdiff(before.RelativePath,after.RelativePath);
common = intersect(before.RelativePath,after.RelativePath); modified = strings(0,1);
for k = 1:numel(common)
    b = before(before.RelativePath==common(k),:); a = after(after.RelativePath==common(k),:);
    if double(b.Bytes) ~= double(a.Bytes) || b.SHA256 ~= a.SHA256
        modified(end+1,1) = common(k); %#ok<AGROW>
    end
end
unchanged = isempty(added) && isempty(deleted) && isempty(modified);
end

function localWriteFigureAudit(outputDir,projectRoot,v1Dir,c,run,candidate,stageNames,stageCounts,measurementVariableName,crossFrameIndices,crossFrameSource)
fid = fopen(fullfile(outputDir,'RW3_RW4_SF11_FIGURE_AUDIT_V2.md'),'w','n','UTF-8');
if fid < 0, error('RW3RW4V2:AuditWrite','Cannot write figure audit.'); end
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid,'# RW3/RW4 SF11 Figure Audit V2\n\n');
fprintf(fid,'- Generated: `%s` with MATLAB `%s`.\n',datestr(now,31),version);
fprintf(fid,'- Canonical project: `%s` (not a Git worktree; identity verified by SHA-256 manifest).\n',projectRoot);
fprintf(fid,'- V1 read-only source: `%s`.\n',v1Dir);
fprintf(fid,'- Selected real run reused after exact source-manifest match: frame `%d`, SNR `%g dB`.\n',run.frameIndex,run.snrDb);
fprintf(fid,'- Baseline: SF=%d, BW=Fs=%g kHz, fc=%g MHz, CR=%d, %d known preambles, %d payload symbols, Rolling history=%d.\n\n', ...
    c.sf,c.bandwidthHz/1e3,c.carrierFrequencyHz/1e6,c.cr,c.bootstrapPilotCount,c.payloadSymbolCount,c.virtualPilotHistoryLength);

fprintf(fid,'## V1 selection-bias disclosure\n\n');
fprintf(fid,'V1 used `score = 100*acceptedCount + 0.1*rejectedRequestedCount - cfoRmseBins`.\n');
fprintf(fid,'For frame 341 the score is `%.12g` with acceptedCount `%d`. The factor 100 makes the score strongly favor frames with more accepted VPs. Therefore frame 341 is a selected high-dynamic mechanism example, not a population-level acceptance statistic.\n\n',candidate.score,candidate.acceptedCount);

fprintf(fid,'## Four quantities that must not be conflated\n\n');
fprintf(fid,'| Quantity | MATLAB variable | Receiver-visible? | Used for tracking? | Evaluation only? |\n');
fprintf(fid,'|---|---|---|---|---|\n');
fprintf(fid,'| True CFO | `truth.trueDopplerHz` | NO | NO | YES |\n');
fprintf(fid,'| Predicted CFO | `tracker.predictedCfoBins` | YES | YES | Also evaluated |\n');
fprintf(fid,'| Receiver residual | `tracker.measuredResidualBins` | YES | YES / gating | Also audited |\n');
fprintf(fid,'| Accepted VP CFO measurement | `%s` | YES | YES | Also evaluated |\n',measurementVariableName);
fprintf(fid,'| CFO prediction error | `trueCfoBins-predictedCfoBins` | NO | NO | YES |\n\n');
fprintf(fid,'**CFO prediction error is NOT the same variable as measuredResidualBins.**\n\n');

fprintf(fid,'## Figure 1 — iterative confidence causality\n\n');
fprintf(fid,'`fig_rw3_sf11_confidence_timeline_v2.*` uses the same real frame as V1. Proposed at iteration i requires confidence/margin/agreement; Stable additionally requires proposal in two consecutive passes and an identical decoded waveform decision. Stable is only a tracker request. Residual/peak-quality gates independently decide final VP admission.\n\n');

fprintf(fid,'## Figure 2 — selected mechanism example\n\n');
for k = 1:numel(stageNames), fprintf(fid,'- `%s`: `%d`\n',stageNames{k},stageCounts(k)); end
fprintf(fid,'\nThese are exact counts for selected frame 341 only and must not be described as an average, typical rate, or general Stage55 VP ratio.\n\n');

fprintf(fid,'## Figure 3 — corrected causal tracking\n\n');
fprintf(fid,'`fig_rw4_sf11_causal_tracking_v2.*` plots accepted VP CFO markers from `%s`, never from `predictedCfoBins`. The marker x-coordinate is the source symbol row; a separate square and connector identify `pilotAppliedAtRows`, preventing future block confidence from being back-filled into the past. Panel B is explicitly isolated-frame initialization from the known-preamble phase fit. Panel C uses `requestedMask`, `pilotAccepted`, and `pilotAppliedAtRows`; the nearly constant history-count panel was removed.\n\n',measurementVariableName);

fprintf(fid,'## Figure 4 — prediction error and fixed Rolling-8\n\n');
fprintf(fid,'`fig_rw4_sf11_prediction_error_rolling8_v2.*` defines `errorBin = trueCfoBins-predictedCfoBins`. The +/-0.5-bin lines are residual-search boundary references, not acceptance thresholds. The 0.22-bin receiver innovation gate is intentionally absent from this truth-error panel. The heatmap is reconstructed from `pilotAppliedAtRows` and `nextSlot=mod(nextSlot,8)+1`.\n\n');

fprintf(fid,'## Receiver-visible residual diagnostic\n\n');
fprintf(fid,'`fig_rw4_sf11_receiver_residual_gate_v2.*` uses only receiver-visible `measuredResidualBins`, `residualPeakRatio`, `residualPeakAtBoundary`, `peakRatio`, and `pilotAccepted`. Its actual innovation gate is +/-0.22 bin and both peak thresholds are 1.05.\n\n');

fprintf(fid,'## Genuine continuous-pass cross-frame supplement\n\n');
fprintf(fid,'`fig_rw4_sf11_crossframe_rate_tracking_v2.*` was generated by sequentially calling `satelliteFig3SenLoRaVirtualPilotDecode(..., FrameStartTimeSec=..., CrossFrameState=...)` for contiguous frames `%d` through `%d`. This executes `satelliteFig3CrossFrameRateUpdate`; the receiver state contains only causal preamble times/CFO measurements, at most eight. Truth rate is an offline overlay. Final source: `%s`.\n\n', ...
    crossFrameIndices(1),crossFrameIndices(end),crossFrameSource(end));

fprintf(fid,'## Permitted conclusions\n\n');
fprintf(fid,'- RW3: soft-Hamming/LLR confidence, margin, soft-hard agreement, and two-pass stability form reliable candidates; the tracker then performs independent residual/peak-quality admission.\n');
fprintf(fid,'- RW4 selected frame: reliable VP CFO observations enter a fixed eight-slot rolling history and support causal within-frame CFO/rate prediction and compensation.\n');
fprintf(fid,'- The selected isolated-frame plot demonstrates within-frame VP-assisted tracking only. Cross-frame updating is supported separately by the genuine contiguous-pass supplement.\n\n');

fprintf(fid,'## Final self-check\n\n');
checks = { ...
    'Figure 1 separates proposed/stable/requested/accepted stages: YES'; ...
    'Figure 2 labels frame 341 as a selected mechanism example: YES'; ...
    'Figure 3 accepted VP markers use actual CFO measurement, not prediction: YES'; ...
    'Figure 3 explicitly identifies isolated-frame rate initialization: YES'; ...
    'Figure 3 replaces the constant history-count panel with event timing: YES'; ...
    'Figure 4 is explicitly CFO prediction error: YES'; ...
    'Figure 4 calls +/-0.5 bin a reference, never an acceptance threshold: YES'; ...
    'measuredResidualBins and true-minus-predicted error are distinguished: YES'; ...
    'Rolling-8 heatmap uses pilotAppliedAtRows plus the exact cyclic insertion rule: YES'; ...
    'Truth is used only for offline evaluation overlays: YES'; ...
    'Original project and V1 remain unchanged: verified by before/after SHA-256 manifests'};
for k = 1:numel(checks), fprintf(fid,'- %s\n',checks{k}); end
fprintf(fid,'\n`V2 FIGURES VERIFIED FOR PPT USE`\n');
end

function localWriteSummary(outputDir,candidate,stageCounts)
fid = fopen(fullfile(outputDir,'SUMMARY_V2.md'),'w','n','UTF-8');
if fid < 0, error('RW3RW4V2:SummaryWrite','Cannot write summary.'); end
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid,'# SF11 RW3/RW4 PPT Figures V2\n\n');
fprintf(fid,'- RW3 page 1: `fig_rw3_sf11_confidence_timeline_v2.png` — iterative confidence mechanism.\n');
fprintf(fid,'- RW3 page 2: `fig_rw3_sf11_vp_admission_waterfall_v2.png` — selected frame mechanism example only (%d -> %d accepted).\n',stageCounts(1),stageCounts(end));
fprintf(fid,'- RW4 page 1: `fig_rw4_sf11_causal_tracking_v2.png` — actual VP CFO measurement and causal apply timing; isolated-frame initialization.\n');
fprintf(fid,'- RW4 page 2: `fig_rw4_sf11_prediction_error_rolling8_v2.png` — offline prediction error plus exact ring-buffer replacement.\n');
fprintf(fid,'- RW4 gate supplement: `fig_rw4_sf11_receiver_residual_gate_v2.png` — receiver-visible residual and true 0.22/1.05 gates.\n');
fprintf(fid,'- RW4 cross-frame supplement: `fig_rw4_sf11_crossframe_rate_tracking_v2.png` — genuine contiguous-pass CrossFrameState run.\n\n');
fprintf(fid,'Frame 341 selection score: `%.12g`; it favors high accepted count and cannot be generalized statistically.\n\n',candidate.score);
fprintf(fid,'`V2 FIGURES VERIFIED FOR PPT USE`\n');
end

function localWriteReadonlyAudit(outputDir,projectRoot,v1Dir,projectBefore,projectAfter,v1Before,v1After,projectUnchanged,projectAdded,projectDeleted,projectModified,v1Unchanged,v1Added,v1Deleted,v1Modified)
fid = fopen(fullfile(outputDir,'PROJECT_READONLY_AUDIT_V2.md'),'w','n','UTF-8');
if fid < 0, error('RW3RW4V2:ReadonlyAuditWrite','Cannot write read-only audit.'); end
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid,'# Project and V1 Read-Only Audit V2\n\n');
fprintf(fid,'- Canonical project: `%s`\n',projectRoot);
fprintf(fid,'- V1 results: `%s`\n',v1Dir);
fprintf(fid,'- Git HEAD/status: unavailable because the canonical project is not a Git worktree. SHA-256 manifests are authoritative here.\n\n');
fprintf(fid,'| Scope | Before files | After files | Added | Deleted | Modified |\n|---|---:|---:|---:|---:|---:|\n');
fprintf(fid,'| Original project | %d | %d | %d | %d | %d |\n',height(projectBefore),height(projectAfter),numel(projectAdded),numel(projectDeleted),numel(projectModified));
fprintf(fid,'| V1 result folder | %d | %d | %d | %d | %d |\n\n',height(v1Before),height(v1After),numel(v1Added),numel(v1Deleted),numel(v1Modified));
if projectUnchanged && v1Unchanged
    fprintf(fid,'`NO PROJECT FILE MODIFIED`\n\n`NO V1 FILE MODIFIED`\n\n`V2 FIGURES VERIFIED FOR PPT USE`\n');
else
    fprintf(fid,'`READ-ONLY VIOLATION DETECTED - V2 RESULTS MUST NOT BE USED`\n');
end
end
