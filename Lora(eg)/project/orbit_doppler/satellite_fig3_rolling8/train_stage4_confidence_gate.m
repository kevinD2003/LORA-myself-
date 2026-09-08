function model = train_stage4_confidence_gate()
%TRAIN_STAGE4_CONFIDENCE_GATE Cross-validated conservative pilot gate.
%   Truth exists only here, to label simulated candidates.  The deployed
%   gate uses the saved logistic model and receiver-visible features only.

root = fileparts(mfilename('fullpath'));
resultDir = fullfile(root,'results','stage4_confidence_gate');
if ~isfolder(resultDir), mkdir(resultDir); end
config = satelliteFig3Config();
[window,~] = satelliteFig3VisibilityWindow(config);
snrGrid = (-24:2:-14).';
trainingFrames = 12;
validationFrames = 8;
[xTrain,yTrain,snrTrain] = localCollect(config,window.deltaTimeInSec, ...
    snrGrid,trainingFrames,810000);
model = localFitLogistic(xTrain,yTrain);
model.snrGridDb = snrGrid;
model.featureNames = {'log_hard_peak_ratio','log_confidence_over_tau', ...
    'log_residual_peak_ratio','residual_not_boundary','soft_hard_agree'};
model.targetPrecisionLower95 = 0.98;

probabilityTrain = localPredict(model,xTrain);
threshold = zeros(numel(snrGrid),1);
for k = 1:numel(snrGrid)
    rows = snrTrain == snrGrid(k);
    threshold(k) = localSelectThreshold(probabilityTrain(rows),yTrain(rows), ...
        model.targetPrecisionLower95);
end
model.posteriorThreshold = threshold;
[xVal,yVal,snrVal] = localCollect(config,window.deltaTimeInSec, ...
    snrGrid,validationFrames,910000);
probabilityVal = localPredict(model,xVal);
summary = localEvaluate(probabilityVal,yVal,snrVal,snrGrid,threshold,validationFrames);
model.validationSummary = summary;
model.trainingCount = numel(yTrain);
model.validationCount = numel(yVal);
save(fullfile(resultDir,'confidence_gate_model.mat'),'model');

fig = figure('Visible','off','Color','w','Position',[100 100 1250 700]);
subplot(2,1,1)
plot(snrGrid,threshold,'o-','LineWidth',1.5); grid on; ylim([0.5 1]);
xlabel('Sample SNR (dB)'); ylabel('Required posterior reliability');
title('Cross-validated confidence-gate threshold (no BER fitting)');
subplot(2,1,2)
yyaxis left
bar(snrGrid,summary.acceptedPerFrame,0.7); ylabel('Accepted candidates / frame');
yyaxis right
plot(snrGrid,summary.precisionLower95,'o-','LineWidth',1.5); hold on
yline(model.targetPrecisionLower95,'k--','Target'); ylim([0.8 1.01]);
ylabel('Precision lower 95% bound'); grid on
xlabel('Sample SNR (dB)');
legend('Accepted candidates / frame','Validation precision lower bound','Location','best');
exportgraphics(fig,fullfile(resultDir,'confidence_gate_validation.png'),'Resolution',180);
savefig(fig,fullfile(resultDir,'confidence_gate_validation.fig')); close(fig);

validationTable = table(snrGrid,summary.candidateCount,summary.acceptedCount, ...
    summary.correctAcceptedCount,summary.falseAcceptedCount, ...
    summary.acceptedPerFrame,summary.precision,summary.precisionLower95, ...
    threshold,'VariableNames',{'snr_db','candidate_count','accepted_count', ...
    'correct_accepted','false_accepted','accepted_per_frame','precision', ...
    'precision_lower95','posterior_threshold'});
writetable(validationTable,fullfile(resultDir,'confidence_gate_validation.csv'));
fprintf('Stage 4 confidence model: %s\\n',resultDir);
end

function [x,y,snrColumn] = localCollect(config,startTime,snrGrid,frameCount,seedBase)
x = zeros(0,5); y = false(0,1); snrColumn = zeros(0,1);
for snrIdx = 1:numel(snrGrid)
    for frame = 1:frameCount
        payload = satelliteFig3GeneratePayload(config,seedBase+1000*snrIdx+frame);
        bins = [zeros(config.bootstrapPilotCount,1);payload.symbolBins];
        rx = generateContinuousSatelliteFrame(bins,config, ...
            StartTimeSec=startTime,SampleSnrDb=snrGrid(snrIdx), ...
            NoiseSeed=seedBase+500000+1000*snrIdx+frame);
        % Calibrate under the conservative receiver state available before
        % any payload virtual pilot is trusted.  Truth is used only after
        % detection to label correctness; it never improves compensation.
        bootstrapTracker = satelliteFig3RollingPilotTracker(rx,config, ...
            zeros(config.bootstrapPilotCount,1));
        soft = satelliteFig3SenLoRaConfidence( ...
            bootstrapTracker.compensatedSymbols,config);
        feature = satelliteFig3PilotConfidenceFeatures( ...
            bootstrapTracker,soft,config);
        rows = feature.candidateMask;
        selectedPayload = feature.payloadRows(rows);
        x = [x; feature.matrix(rows,:)]; %#ok<AGROW>
        y = [y; soft.decodedWaveformBins(selectedPayload) == bins(selectedPayload)]; %#ok<AGROW>
        snrColumn = [snrColumn; repmat(snrGrid(snrIdx),sum(rows),1)]; %#ok<AGROW>
    end
end
end

function model = localFitLogistic(x,y)
mu = mean(x,1); sigma = std(x,0,1); sigma(sigma < 1e-9) = 1;
z = (x-mu)./sigma;
design = [ones(size(z,1),1),z];
beta = zeros(size(design,2),1);
lambda = 1e-3;
for iteration = 1:100
    p = localSigmoid(design*beta);
    weight = max(p.*(1-p),1e-8);
    gradient = design.'*(p-double(y)) + lambda*[0;beta(2:end)];
    hessian = design.'*(design.*weight) + lambda*diag([0;ones(numel(beta)-1,1)]);
    step = hessian\gradient;
    beta = beta-step;
    if norm(step) < 1e-8, break; end
end
model = struct('mu',mu,'sigma',sigma,'beta',beta,'lambda',lambda);
end

function probability = localPredict(model,x)
z = (x-model.mu)./model.sigma;
probability = localSigmoid([ones(size(z,1),1),z]*model.beta);
end

function threshold = localSelectThreshold(probability,correct,targetLower95)
candidate = unique([0.5;probability]);
candidate = sort(candidate,'ascend');
threshold = 1;
for idx = 1:numel(candidate)
    accepted = probability >= candidate(idx);
    count = sum(accepted);
    if count < 8, continue; end
    lower = localWilsonLower(sum(correct(accepted)),count);
    if lower >= targetLower95
        threshold = candidate(idx);
        return
    end
end
end

function summary = localEvaluate(probability,correct,snrColumn,snrGrid,threshold,frameCount)
n = numel(snrGrid);
candidateCount = zeros(n,1); acceptedCount = zeros(n,1); correctCount = zeros(n,1);
for k = 1:n
    rows = snrColumn == snrGrid(k);
    accepted = rows & probability >= threshold(k);
    candidateCount(k) = sum(rows);
    acceptedCount(k) = sum(accepted);
    correctCount(k) = sum(correct(accepted));
end
precision = correctCount./max(acceptedCount,1);
lower = zeros(n,1);
for k = 1:n, lower(k) = localWilsonLower(correctCount(k),acceptedCount(k)); end
summary = struct('candidateCount',candidateCount,'acceptedCount',acceptedCount, ...
    'correctAcceptedCount',correctCount,'falseAcceptedCount',acceptedCount-correctCount, ...
    'acceptedPerFrame',acceptedCount/frameCount,'precision',precision, ...
    'precisionLower95',lower);
end

function lower = localWilsonLower(success,count)
if count == 0, lower = 0; return; end
z = 1.95996398454005;
p = success/count;
lower = (p+z^2/(2*count)-z*sqrt(p*(1-p)/count+z^2/(4*count^2)))/(1+z^2/count);
end

function value = localSigmoid(x)
value = zeros(size(x));
positive = x >= 0;
value(positive) = 1./(1+exp(-x(positive)));
ex = exp(x(~positive));
value(~positive) = ex./(1+ex);
end
