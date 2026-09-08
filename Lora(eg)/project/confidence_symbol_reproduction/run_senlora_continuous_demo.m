%RUN_SENLORA_CONTINUOUS_DEMO Continuous SenLoRa confidence-symbol demo.
% CorrectFlag/ErrorFlag use known simulation truth. ConfidentFlag is the
% receiver-side paper criterion and does not require the transmitted bins.

clear; clc; close all;

cfg.sf = 7;
cfg.cr = 3;
cfg.alpha = 0.8;
cfg.probMode = "paper";
cfg.amendMode = "identity";
cfg.thresholdMode = "global";
cfg.preambleSymbols = 8;
cfg.preambleSnrDb = 20;
cfg.frameStartSample = 1;

rng(23);
numBlocks = 12;
blockSize = 4 + cfg.cr;
numSymbols = numBlocks * blockSize;
targetBins = zeros(numSymbols, 1);

for blockIdx = 1:numBlocks
    blockRange = (blockIdx - 1) * blockSize + (1:blockSize);
    dataNibbles = randi([0 15], cfg.sf, 1);
    targetBins(blockRange) = nibblesToDemoBins(dataNibbles, cfg);
end

symbolIndex = (1:numSymbols).';
symbolSnrDb = 15 + 3 * sin(2 * pi * (symbolIndex - 1) / 28);
forcedErrorIdx = [9 10 23 31 46 60 73 74 81].';
symbolSnrDb(forcedErrorIdx) = -8;

% A second LoRa chirp at a different bin emulates interference during fades.
numBins = 2 ^ cfg.sf;
interferenceBins = nan(numSymbols, 1);
interferenceSnrDb = -inf(numSymbols, 1);
for idx = forcedErrorIdx.'
    interferenceBins(idx) = mod(targetBins(idx) + 17 + idx, numBins);
    interferenceSnrDb(idx) = 10;
end

[rxSignal, signalMetadata] = synthesizeLoRaSignalSequence( ...
    targetBins, cfg, symbolSnrDb, interferenceBins, interferenceSnrDb);
[result, frontend] = detectLoRaSignalSequence( ...
    rxSignal, cfg, numSymbols, targetBins);

numCorrect = sum(result.correctFlag);
numError = sum(result.errorFlag);
numConfident = sum(result.confidentFlag);
numAcceptedCorrect = sum(result.acceptedCorrectFlag);
numFalseAccept = sum(result.falseAcceptFlag);
if numConfident > 0
    confidentPrecision = numAcceptedCorrect / numConfident;
else
    confidentPrecision = NaN;
end

fprintf("SenLoRa continuous confidence-symbol demo\n");
fprintf("SF=%d, CR=%d, symbols=%d, completed blocks=%d\n", ...
    cfg.sf, cfg.cr, numSymbols, result.numCompletedBlocks);
fprintf("Hard decisions: correct=%d, error=%d, SER=%.3f\n", ...
    numCorrect, numError, numError / numSymbols);
fprintf("Confidence decisions: accepted=%d, accepted-correct=%d, false-accept=%d\n", ...
    numConfident, numAcceptedCorrect, numFalseAccept);
fprintf("Accepted-symbol precision: %.3f\n", confidentPrecision);
fprintf("Injected error positions: %s\n", mat2str(forcedErrorIdx.'));
fprintf("Detected error positions: %s\n", mat2str(find(result.errorFlag).'));

resultsTable = table( ...
    result.symbolIndex, result.blockIndex, targetBins, result.detectedBins, ...
    result.correctFlag, result.errorFlag, result.truthFlag, ...
    result.confidenceReadyFlag, result.confidentFlag, ...
    result.receiverDecisionFlag, result.confidence, result.tauBlock, ...
    result.tauGlobal, result.acceptedCorrectFlag, result.falseAcceptFlag, ...
    'VariableNames', {'SymbolIndex', 'BlockIndex', 'TxBin', 'RxBin', ...
    'CorrectFlag', 'ErrorFlag', 'TruthFlag', 'ConfidenceReadyFlag', ...
    'ConfidentFlag', 'ReceiverDecisionFlag', 'Confidence', 'TauBlock', ...
    'TauGlobal', 'AcceptedCorrectFlag', 'FalseAcceptFlag'});

scriptFolder = fileparts(mfilename("fullpath"));
resultsFolder = fullfile(scriptFolder, "results");
if ~isfolder(resultsFolder)
    mkdir(resultsFolder);
end
writetable(resultsTable, fullfile(resultsFolder, "continuous_symbol_flags.csv"));
save(fullfile(resultsFolder, "continuous_symbol_results.mat"), ...
    "result", "resultsTable", "cfg", "targetBins", "symbolSnrDb", ...
    "rxSignal", "signalMetadata", "frontend");

figureHandle = figure("Name", "SenLoRa continuous symbol detection", ...
    "Color", "w", "Position", [120 40 1180 900]);
layout = tiledlayout(4, 1, "TileSpacing", "compact", "Padding", "compact");

nexttile;
sampleTimeInSymbols = (0:(numel(rxSignal) - 1)).' / (2 ^ cfg.sf);
plot(sampleTimeInSymbols, abs(rxSignal), "Color", [0.25 0.25 0.28], ...
    "LineWidth", 0.5);
hold on;
xline(cfg.preambleSymbols, "--", "Payload start", ...
    "Color", [0.82 0.12 0.12], "LineWidth", 1.2);
hold off;
grid on;
xlim([0 cfg.preambleSymbols + numSymbols]);
ylabel("|IQ|");
title("Received continuous LoRa baseband sequence");

nexttile;
stairs(symbolIndex, targetBins, "Color", [0.15 0.55 0.25], ...
    "LineWidth", 1.1, "DisplayName", "Transmitted bin");
hold on;
stairs(symbolIndex, result.detectedBins, "Color", [0.15 0.35 0.75], ...
    "LineWidth", 1.0, "DisplayName", "Detected bin");
scatter(symbolIndex(result.errorFlag), result.detectedBins(result.errorFlag), ...
    42, [0.82 0.12 0.12], "x", "LineWidth", 1.6, ...
    "DisplayName", "Hard-decision error");
hold off;
grid on;
xlim([1 numSymbols]);
ylabel("FFT bin");
title("Continuous hard symbol decisions");
legend("Location", "eastoutside");

nexttile;
plot(symbolIndex, result.confidence, "Color", [0.15 0.35 0.75], ...
    "LineWidth", 1.0, "DisplayName", "Symbol confidence");
hold on;
stairs(symbolIndex, result.tauGlobal, "--", "Color", [0.82 0.12 0.12], ...
    "LineWidth", 1.2, "DisplayName", "Global threshold");
scatter(symbolIndex(result.confidentFlag), ...
    result.confidence(result.confidentFlag), 28, [0.15 0.55 0.25], ...
    "filled", "DisplayName", "Selected as confident");
hold off;
grid on;
xlim([1 numSymbols]);
ylabel("sum |LLR|^2");
title("Paper confidence and adaptive threshold");
legend("Location", "eastoutside");

nexttile;
hold on;
scatter(symbolIndex(result.correctFlag), ...
    3 * ones(sum(result.correctFlag), 1), 20, [0.15 0.55 0.25], ...
    "filled", "DisplayName", "CorrectFlag");
scatter(symbolIndex(result.errorFlag), ...
    2 * ones(sum(result.errorFlag), 1), 42, [0.82 0.12 0.12], ...
    "x", "LineWidth", 1.5, "DisplayName", "ErrorFlag");
scatter(symbolIndex(result.confidentFlag), ...
    ones(sum(result.confidentFlag), 1), 24, [0.15 0.35 0.75], ...
    "s", "filled", "DisplayName", "ConfidentFlag");
hold off;
grid on;
xlim([1 numSymbols]);
ylim([0.5 3.5]);
yticks([1 2 3]);
yticklabels(["Confident", "Error", "Correct"]);
xlabel("Continuous symbol index");
title("Arrival-aligned flag bits");
legend("Location", "eastoutside");

title(layout, "SenLoRa detection from a continuous LoRa IQ sequence");
exportgraphics(figureHandle, ...
    fullfile(resultsFolder, "continuous_symbol_detection.png"), ...
    "Resolution", 180);

paperFigureFile = fullfile( ...
    resultsFolder, "paper_correspondence_confidence_detection.png");
plotSenLoRaPaperCorrespondence(result, frontend, cfg, paperFigureFile);

fprintf("Saved CSV, MAT, and PNG results to:\n%s\n", resultsFolder);
