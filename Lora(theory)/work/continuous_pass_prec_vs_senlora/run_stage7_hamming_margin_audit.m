function report = run_stage7_hamming_margin_audit()
%RUN_STAGE7_HAMMING_MARGIN_AUDIT Audit anchor-recompensation reliability.
%   Pass one nominates only quarantined, early-block anchors.  They are used
%   to re-compensate the frame; then pass two accepts a candidate only when
%   its decoded label survives that independent re-check.  The transmitted
%   label is used here solely to report audit statistics, never by receiver
%   functions.  This stage deliberately does not alter the BER receiver.

root = fileparts(mfilename('fullpath'));
modelPath = fullfile(root,'results','stage4_confidence_gate','confidence_gate_model.mat');
if ~isfile(modelPath)
    error('SatelliteFig3:MissingConfidenceModel','Run stage 4 before stage 7.');
end
loaded = load(modelPath,'model'); model = loaded.model;
resultDir = fullfile(root,'results','stage7_hamming_margin');
if ~isfolder(resultDir), mkdir(resultDir); end
config = satelliteFig3Config(); [window,~] = satelliteFig3VisibilityWindow(config);
% Low-SNR points are included as a safety audit.  They may retain
% quarantined candidates, but never get a relaxed promotion criterion.
snrGrid = [-24;-22;-18;-16;-14];
trainFrames = 12; validationFrames = 8;
train = localCollect(snrGrid,trainFrames,1107000,config,window,model);
threshold = localCalibrate(train,snrGrid);
validation = localCollect(snrGrid,validationFrames,1207000,config,window,model);
summary = localSummarize(validation,snrGrid,threshold,validationFrames);

writetable(train,fullfile(resultDir,'margin_training_samples.csv'));
writetable(validation,fullfile(resultDir,'margin_validation_samples.csv'));
writetable(summary,fullfile(resultDir,'margin_validation_summary.csv'));
save(fullfile(resultDir,'hamming_margin_audit.mat'),'train','validation','summary','threshold','config');

fig = figure('Visible','off','Color','w','Position',[80 80 1350 720]);
tiledlayout(2,2,'TileSpacing','compact','Padding','compact');
plotSnr = [-24;-22];
for k = 1:numel(plotSnr)
    snrDb = plotSnr(k);
    thresholdIndex = find(snrGrid == snrDb,1);
    rows = validation(validation.snrDb == snrDb,:);
    nexttile;
    scatter(rows.symbolIndex(rows.correct),rows.margin(rows.correct),24,[0.1 0.55 0.2],'filled'); hold on
    scatter(rows.symbolIndex(~rows.correct),rows.margin(~rows.correct),34,[0.85 0.2 0.15],'x','LineWidth',1.2);
    yline(threshold(thresholdIndex),'k--','Promote threshold','LineWidth',1.2);
    grid on; xlabel('Payload symbol index'); ylabel('Soft-Hamming margin');
    title(sprintf('%g dB: quarantined-anchor recheck',snrDb));
    legend('Correct (audit only)','Wrong (audit only)','Threshold','Location','best');
end
nexttile([1 2]);
bar(summary.snrDb,[summary.candidateCount,summary.acceptedCount,summary.falseAcceptedCount],'grouped');
grid on; xlabel('SNR (dB)'); ylabel('Candidate count across validation frames');
legend('Stable recheck candidates','Promoted by margin','Wrong promoted','Location','northwest');
title('Independent validation: margin promotion is measured, not fitted');
exportgraphics(fig,fullfile(resultDir,'hamming_margin_anchor_recheck.png'),'Resolution',180);
savefig(fig,fullfile(resultDir,'hamming_margin_anchor_recheck.fig')); close(fig);

report = struct('resultDir',resultDir,'threshold',threshold,'summary',summary);
fprintf('Stage 7 Hamming-margin audit: %s\n',resultDir);
end

function samples = localCollect(snrGrid,nFrames,seedBase,config,window,model)
empty = table(zeros(0,1),zeros(0,1),zeros(0,1),zeros(0,1), ...
    false(0,1),false(0,1),false(0,1),false(0,1), ...
    'VariableNames',{'snrDb','frame','symbolIndex','margin','correct','stable','anchorUsed','candidate'});
samples = empty;
for s = 1:numel(snrGrid)
    for frame = 1:nFrames
        seed = seedBase + 1000*s + frame;
        payload = satelliteFig3GeneratePayload(config,seed);
        bins = [zeros(config.bootstrapPilotCount,1);payload.symbolBins];
        rx = generateContinuousSatelliteFrame(bins,config, ...
            StartTimeSec=window.deltaTimeInSec,SampleSnrDb=snrGrid(s),NoiseSeed=seed+500000);
        firstTracker = satelliteFig3RollingPilotTracker(rx,config,zeros(config.bootstrapPilotCount,1));
        firstSoft = satelliteFig3SenLoRaConfidence(firstTracker.compensatedSymbols,config);
        tier = satelliteFig3TwoTierPilotDecision(firstTracker,firstSoft,config,model,snrGrid(s));
        % Only the first two block representatives can be trusted anchors.
        anchorMask = tier.provisionalMask;
        anchorMask(config.bootstrapPilotCount+2*(4+config.cr)+1:end) = false;
        secondTracker = satelliteFig3RollingPilotTracker(rx,config,zeros(config.bootstrapPilotCount,1), ...
            AcceptedMask=anchorMask,DecisionWaveformBins=firstSoft.decodedWaveformBins);
        secondSoft = satelliteFig3SenLoRaConfidence(secondTracker.compensatedSymbols,config);
        secondTier = satelliteFig3TwoTierPilotDecision(secondTracker,secondSoft,config,model,snrGrid(s));
        payloadRows = secondTier.features.payloadRows;
        stable = firstSoft.decodedWaveformBins(payloadRows) == secondSoft.decodedWaveformBins(payloadRows);
        candidate = secondTier.provisionalPayload & stable;
        n = numel(payloadRows);
        block = table(repmat(snrGrid(s),n,1),repmat(frame,n,1),payloadRows, ...
            secondTier.features.codewordMargin, ...
            secondSoft.decodedWaveformBins(payloadRows) == bins(payloadRows), ...
            stable,anchorMask(payloadRows),candidate, ...
            'VariableNames',empty.Properties.VariableNames);
        samples = [samples; block]; %#ok<AGROW>
    end
end
end

function threshold = localCalibrate(samples,snrGrid)
threshold = zeros(numel(snrGrid),1);
for k = 1:numel(snrGrid)
    rows = samples(samples.snrDb == snrGrid(k) & samples.candidate,:);
    if isempty(rows)
        threshold(k) = Inf; % No evidence permits no state update.
        continue
    end
    wrong = rows.margin(~rows.correct);
    if isempty(wrong)
        threshold(k) = prctile(rows.margin,20);
    else
        threshold(k) = max(wrong) + 10*eps(max(abs(wrong))+1);
    end
end
end

function summary = localSummarize(samples,snrGrid,threshold,nFrames)
summary = table(nan(numel(snrGrid),1),zeros(numel(snrGrid),1),zeros(numel(snrGrid),1), ...
    zeros(numel(snrGrid),1),nan(numel(snrGrid),1),nan(numel(snrGrid),1), ...
    'VariableNames',{'snrDb','candidateCount','acceptedCount','falseAcceptedCount','precision','acceptedPerFrame'});
for k = 1:numel(snrGrid)
    rows = samples(samples.snrDb == snrGrid(k),:);
    selected = rows.candidate & rows.margin >= threshold(k);
    accepted = sum(selected); falseAccepted = sum(selected & ~rows.correct);
    summary.snrDb(k) = snrGrid(k);
    summary.candidateCount(k) = sum(rows.candidate);
    summary.acceptedCount(k) = accepted;
    summary.falseAcceptedCount(k) = falseAccepted;
    if accepted > 0, summary.precision(k) = 1-falseAccepted/accepted; end
    summary.acceptedPerFrame(k) = accepted/nFrames;
end
end
