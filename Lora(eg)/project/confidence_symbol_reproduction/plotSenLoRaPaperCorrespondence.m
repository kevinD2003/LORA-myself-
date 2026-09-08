function figureHandle = plotSenLoRaPaperCorrespondence( ...
    result, frontend, cfg, outputFile)
%PLOTSENLORAPAPERCORRESPONDENCE Plot results aligned with Sec. 5 objects.
%
% Panels correspond to Fig. 6/Eq. (12), Eq. (13), the local/global
% threshold equations, and Algorithm 2's ConfdSym output.

arguments
    result struct
    frontend struct
    cfg struct
    outputFile (1,1) string = ""
end

if ~isfield(cfg, "probMode")
    cfg.probMode = "paper";
end

exampleIdx = find(result.acceptedCorrectFlag, 1, "first");
if isempty(exampleIdx)
    exampleIdx = find(result.confidentFlag, 1, "first");
end
if isempty(exampleIdx)
    exampleIdx = 1;
end

noisePower = estimateNoisePower(frontend.preambleFft);
exampleFft = frontend.payloadFft(exampleIdx, :);
logProbability = fftToBinLogProb(exampleFft, noisePower, cfg.probMode);
binProbability = exp(logProbability);
grayBits = loraGrayBits(cfg.sf);
bitLlr = binLogProbToLlr(logProbability, grayBits);
fftBins = 0:(2 ^ cfg.sf - 1);
symbolIndex = result.symbolIndex;

figureHandle = figure("Name", "SenLoRa paper correspondence", ...
    "Color", "w", "Position", [100 70 1280 820]);
layout = tiledlayout(2, 2, "TileSpacing", "compact", "Padding", "compact");

nexttile;
stem(fftBins, binProbability, "filled", "MarkerSize", 3, ...
    "Color", [0.20 0.42 0.78], "LineWidth", 0.8, ...
    "DisplayName", "P(Z[f])");
hold on;
xline(result.detectedBins(exampleIdx), "--", ...
    "Color", [0.82 0.12 0.12], "LineWidth", 1.2, ...
    "DisplayName", "Detected bin");
if ~isempty(result.referenceBins)
    xline(result.referenceBins(exampleIdx), ":", ...
        "Color", [0.15 0.55 0.25], "LineWidth", 1.5, ...
        "DisplayName", "True bin");
end
hold off;
grid on;
xlim([0 fftBins(end)]);
xlabel("FFT bin index f");
ylabel("Probability");
title(sprintf("(a) Fig. 6 / Eq. (12): P(Z[f]), symbol %d", exampleIdx));
legend("Location", "northeast");

nexttile;
bar(1:cfg.sf, bitLlr, 0.65, "FaceColor", [0.20 0.42 0.78]);
hold on;
yline(0, "k-");
hold off;
grid on;
xlim([0.5 cfg.sf + 0.5]);
xticks(1:cfg.sf);
xlabel("Gray-mapped bit index k");
ylabel("LLR_k(Z)");
title("(b) Eq. (13): bit-level soft information");

nexttile;
plot(symbolIndex, result.confidence, "Color", [0.20 0.42 0.78], ...
    "LineWidth", 1.0, "DisplayName", "sum |LLR'|^2");
hold on;
stairs(symbolIndex, result.tauBlock, ":", "Color", [0.20 0.20 0.22], ...
    "LineWidth", 1.1, "DisplayName", "Block threshold tau_b");
stairs(symbolIndex, result.tauGlobal, "--", "Color", [0.82 0.12 0.12], ...
    "LineWidth", 1.2, "DisplayName", "Global threshold tau_g");
scatter(symbolIndex(result.confidentFlag), ...
    result.confidence(result.confidentFlag), 24, [0.15 0.55 0.25], ...
    "filled", "DisplayName", "Confidence symbol");
hold off;
grid on;
xlim([1 symbolIndex(end)]);
xlabel("Continuous payload symbol index");
ylabel("Symbol confidence");
title("(c) Sec. 5.2: dynamic confidence threshold");
legend("Location", "best");

nexttile;
hold on;
scatter(symbolIndex(result.correctFlag), ...
    3 * ones(sum(result.correctFlag), 1), 18, [0.15 0.55 0.25], ...
    "filled", "DisplayName", "CorrectFlag (truth)");
scatter(symbolIndex(result.errorFlag), ...
    2 * ones(sum(result.errorFlag), 1), 40, [0.82 0.12 0.12], ...
    "x", "LineWidth", 1.5, "DisplayName", "ErrorFlag (truth)");
scatter(symbolIndex(result.confidentFlag), ...
    ones(sum(result.confidentFlag), 1), 24, [0.20 0.42 0.78], ...
    "s", "filled", "DisplayName", "ConfdSym (receiver)");
hold off;
grid on;
xlim([1 symbolIndex(end)]);
ylim([0.5 3.5]);
yticks([1 2 3]);
yticklabels({'ConfdSym', 'Error', 'Correct'});
xlabel("Continuous payload symbol index");
title("(d) Algorithm 2: arrival-aligned symbol flags");
legend("Location", "best");

title(layout, "SenLoRa Sec. 5 confidence-symbol detection reproduction");

if strlength(outputFile) > 0
    exportgraphics(figureHandle, outputFile, "Resolution", 180);
end

end
