%RUN_PREDICTIVE_DOPPLER_BER_DEMO Correct-symbol-aided Doppler tracking.
% The phase-rotation grid follows PREC.m. Previously correct symbols update
% a causal least-squares CFO predictor and cumulative phase state.

clear; clc; close all;

cfg.sf = 7;
cfg.bootstrapPilotCount = 4; % Example only; any count >= 2 is supported.
cfg.historyLength = 8;
cfg.initialSearchOffsets = (-1:0.1:1).';
cfg.residualSearchOffsets = (-0.5:0.1:0.5).';

frameSymbolCount = 64;
sampleSnrDb = (-18:2:-6).';
minimumErrorCount = 60;
minimumBitCount = 3e4;
maximumBitCount = 3e5;
randomSeed = 71;
rng(randomSeed);

symbolTime = (0:(frameSymbolCount - 1)).';
trueCfoBins = 0.24 + 0.008 * symbolTime + ...
    8e-5 * symbolTime .^ 2;
dataRange = (cfg.bootstrapPilotCount + 1):frameSymbolCount;
bitsPerFrame = numel(dataRange) * cfg.sf;

methodNames = ["No compensation", "Static PREC", ...
    "Correct-symbol prediction", "Ideal compensation"];
numMethods = numel(methodNames);
bitErrors = zeros(numel(sampleSnrDb), numMethods);
simulatedBits = zeros(numel(sampleSnrDb), 1);
frameCounts = zeros(numel(sampleSnrDb), 1);

fprintf("Predictive Doppler BER demo\n");
fprintf("SF=%d, bootstrap pilots=%d, rotation step=%.1f bin\n", ...
    cfg.sf, cfg.bootstrapPilotCount, ...
    cfg.residualSearchOffsets(2) - cfg.residualSearchOffsets(1));

for snrIdx = 1:numel(sampleSnrDb)
    while simulatedBits(snrIdx) < maximumBitCount && ...
            (simulatedBits(snrIdx) < minimumBitCount || ...
            bitErrors(snrIdx, 3) < minimumErrorCount || ...
            bitErrors(snrIdx, 4) < minimumErrorCount)
        trueBins = randi([0 2 ^ cfg.sf - 1], frameSymbolCount, 1);
        rxSymbols = generateDopplerLoRaSymbols( ...
            trueBins, cfg.sf, trueCfoBins, sampleSnrDb(snrIdx));

        predictive = predictiveDopplerCompensate(rxSymbols, trueBins, cfg);
        noCompBins = hardDemodLoRaWithCfo( ...
            rxSymbols, cfg.sf, zeros(frameSymbolCount, 1));
        staticBins = hardDemodLoRaWithCfo( ...
            rxSymbols, cfg.sf, predictive.staticCfoEstimate);
        idealBins = hardDemodLoRaWithCfo( ...
            rxSymbols, cfg.sf, trueCfoBins);

        detectedSets = {noCompBins, staticBins, ...
            predictive.detectedBins, idealBins};
        for methodIdx = 1:numMethods
            bitErrors(snrIdx, methodIdx) = ...
                bitErrors(snrIdx, methodIdx) + countLoRaBitErrors( ...
                trueBins(dataRange), detectedSets{methodIdx}(dataRange), cfg.sf);
        end

        simulatedBits(snrIdx) = simulatedBits(snrIdx) + bitsPerFrame;
        frameCounts(snrIdx) = frameCounts(snrIdx) + 1;
    end

    fprintf("SNR=%5.1f dB, bits=%d, predictive errors=%d, ideal errors=%d\n", ...
        sampleSnrDb(snrIdx), simulatedBits(snrIdx), ...
        bitErrors(snrIdx, 3), bitErrors(snrIdx, 4));
end

ber = bitErrors ./ simulatedBits;
plotFloor = 0.5 ./ simulatedBits;
berForPlot = max(ber, plotFloor);
theorySnrDb = linspace(sampleSnrDb(1), sampleSnrDb(end), 31).';
theoryBer = theoreticalLoRaBerAwgn(cfg.sf, theorySnrDb);

scriptFolder = fileparts(mfilename("fullpath"));
resultsFolder = fullfile(scriptFolder, "results", "doppler_prediction");
if ~isfolder(resultsFolder)
    mkdir(resultsFolder);
end

resultsTable = table(sampleSnrDb, simulatedBits, frameCounts, ...
    ber(:, 1), ber(:, 2), ber(:, 3), ber(:, 4), ...
    'VariableNames', {'SampleSNRdB', 'SimulatedBits', 'Frames', ...
    'BER_NoCompensation', 'BER_StaticPREC', ...
    'BER_CorrectSymbolPrediction', 'BER_IdealCompensation'});
writetable(resultsTable, fullfile(resultsFolder, "predictive_doppler_ber.csv"));
save(fullfile(resultsFolder, "predictive_doppler_ber.mat"), ...
    "cfg", "sampleSnrDb", "ber", "bitErrors", "simulatedBits", ...
    "frameCounts", "theorySnrDb", "theoryBer", "trueCfoBins");

berFigure = figure("Name", "Correct-symbol Doppler BER", ...
    "Color", "w", "Position", [140 90 980 660]);
semilogy(theorySnrDb, theoryBer, "k--", "LineWidth", 1.6, ...
    "DisplayName", "AWGN theory, ideal CFO");
hold on;
semilogy(sampleSnrDb, berForPlot(:, 1), "x-", ...
    "Color", [0.82 0.12 0.12], "LineWidth", 1.2, ...
    "MarkerSize", 7, "DisplayName", methodNames(1));
semilogy(sampleSnrDb, berForPlot(:, 2), "s-", ...
    "Color", [0.90 0.52 0.10], "LineWidth", 1.2, ...
    "MarkerSize", 6, "DisplayName", methodNames(2));
semilogy(sampleSnrDb, berForPlot(:, 3), "o-", ...
    "Color", [0.15 0.38 0.78], "LineWidth", 1.5, ...
    "MarkerSize", 6, "DisplayName", methodNames(3));
semilogy(sampleSnrDb, berForPlot(:, 4), "d-", ...
    "Color", [0.10 0.58 0.30], "LineWidth", 1.2, ...
    "MarkerSize", 6, "DisplayName", methodNames(4));
yline(1e-4, ":", "10^{-4}", "Color", [0.35 0.35 0.38], ...
    "LineWidth", 1.1, "HandleVisibility", "off");
hold off;
grid on;
xlabel("Time-domain sample SNR (dB)");
ylabel("Gray-bit BER");
title(sprintf(['Cumulative Doppler compensation using correct symbols ' ...
    '(SF=%d, rotation step=0.1)'], cfg.sf));
legend("Location", "southwest");
ylim([1e-5 1]);
exportgraphics(berFigure, ...
    fullfile(resultsFolder, "predictive_doppler_ber.png"), ...
    "Resolution", 180);

% One-frame trace exposes the predict -> compensate -> residual-update loop.
rng(randomSeed + 1);
traceSnrDb = -8;
traceBins = randi([0 2 ^ cfg.sf - 1], frameSymbolCount, 1);
traceRx = generateDopplerLoRaSymbols( ...
    traceBins, cfg.sf, trueCfoBins, traceSnrDb);
trace = predictiveDopplerCompensate(traceRx, traceBins, cfg);

traceFigure = figure("Name", "Correct-symbol residual tracking", ...
    "Color", "w", "Position", [120 70 1080 760]);
layout = tiledlayout(3, 1, "TileSpacing", "compact", "Padding", "compact");

nexttile;
plot(1:frameSymbolCount, trueCfoBins, "k-", "LineWidth", 1.6, ...
    "DisplayName", "True Doppler CFO");
hold on;
plot(1:frameSymbolCount, trace.predictedCfo, "--", ...
    "Color", [0.15 0.38 0.78], "LineWidth", 1.3, ...
    "DisplayName", "Predicted CFO");
scatter(find(trace.pilotUpdateFlag), ...
    trace.measuredCfo(trace.pilotUpdateFlag), 28, [0.10 0.58 0.30], ...
    "filled", "DisplayName", "Correct-symbol update");
hold off;
grid on;
ylabel("Normalized CFO (bins)");
title("Causal prediction from previously correct symbols");
legend("Location", "northwest");

nexttile;
trueResidual = trueCfoBins - trace.predictedCfo;
plot(1:frameSymbolCount, trueResidual, "k-", "LineWidth", 1.1, ...
    "DisplayName", "True residual");
hold on;
scatter(find(trace.pilotUpdateFlag), ...
    trace.measuredResidual(trace.pilotUpdateFlag), ...
    26, [0.82 0.12 0.12], "filled", ...
    "DisplayName", "Rotation estimate");
yline(0, "k:", "HandleVisibility", "off");
hold off;
grid on;
ylabel("Residual CFO (bins)");
title("Residual found after each accepted correct symbol");
legend("Location", "best");

nexttile;
stairs(1:frameSymbolCount, double(trace.correctFlag), ...
    "Color", [0.10 0.58 0.30], "LineWidth", 1.2, ...
    "DisplayName", "Correct decision flag");
hold on;
stairs(1:frameSymbolCount, double(trace.pilotUpdateFlag) - 0.08, ...
    "Color", [0.15 0.38 0.78], "LineWidth", 1.2, ...
    "DisplayName", "Used as next-symbol pilot");
hold off;
grid on;
ylim([-0.2 1.2]);
yticks([0 1]);
yticklabels({'0', '1'});
xlabel("LoRa symbol index");
ylabel("Flag");
title("Correct-symbol arrival and predictor update flags");
legend("Location", "southwest");

title(layout, sprintf( ...
    "PREC residual prediction and cumulative phase correction, SNR=%g dB", ...
    traceSnrDb));
exportgraphics(traceFigure, ...
    fullfile(resultsFolder, "predictive_doppler_tracking.png"), ...
    "Resolution", 180);

fprintf("Saved BER and tracking results to:\n%s\n", resultsFolder);
