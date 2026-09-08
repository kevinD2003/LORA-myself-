function plotSerResults( ...
    inputCsv, outputPng, figureTitle, cfg, allowFitted)
%PLOTSERRESULTS Create a Figure 10/11-style three-curve panel.

arguments
    inputCsv (1,1) string
    outputPng (1,1) string
    figureTitle (1,1) string
    cfg (1,1) struct
    allowFitted (1,1) logical = false
end

data = readtable(inputCsv, 'TextType', 'string');
if any(data.fittedOrTuned) && ~allowFitted
    error('plotSerResults:FittedData', ...
        'Refusing to plot results marked as fitted or tuned.');
end
strategies = ["no_doppler", "point", "midamble_point"];
labels = [string(cfg.plot.noDopplerLabel), ...
    "Point estimation", "Midamble-Point estimation"];
colors = [0.35 0.35 0.35; 0 0.4470 0.7410; 0.3010 0.7450 0.9330];
lineStyles = ["-", "--", "-."];
markers = ["none", "o", "x"];

fig = figure('Visible', 'off', 'Color', 'w', ...
    'Position', [100 100 860 620]);
cleanupFigure = onCleanup(@() close(fig));
axesHandle = axes(fig);
hold(axesHandle, 'on');
plotHandles = gobjects(1, numel(strategies));
for index = 1:numel(strategies)
    selected = data.strategy == strategies(index);
    snrDb = data.snrDb(selected);
    ser = data.ser(selected);
    totalSymbols = data.totalSymbols(selected);
    [snrDb, order] = sort(snrDb);
    ser = ser(order);
    totalSymbols = totalSymbols(order);
    displaySer = max(ser, 0.5./totalSymbols);
    plotHandles(index) = semilogy(axesHandle, snrDb, displaySer, ...
        'LineStyle', lineStyles(index), ...
        'Marker', markers(index), ...
        'Color', colors(index, :), ...
        'LineWidth', 1.6, 'MarkerSize', 7);
end
grid(axesHandle, 'on');
axesHandle.YScale = 'log';
axesHandle.YMinorGrid = 'on';
xlim(axesHandle, cfg.plot.xLimitsDb);
ylim(axesHandle, cfg.plot.yLimits);
xticks(axesHandle, cfg.plot.xLimitsDb(1):cfg.plot.xLimitsDb(2));
xlabel(axesHandle, 'SNR [dB]');
ylabel(axesHandle, 'SER');
title(axesHandle, figureTitle);
legend(axesHandle, plotHandles, labels, ...
    'Location', 'southwest', 'Interpreter', 'none');
set(axesHandle, 'FontName', 'Times New Roman', 'FontSize', 11);
outputFolder = fileparts(outputPng);
if ~isfolder(outputFolder)
    mkdir(outputFolder);
end
exportgraphics(fig, outputPng, 'Resolution', 200);
[~, baseName] = fileparts(outputPng);
savefig(fig, fullfile(outputFolder, baseName + ".fig"));
end
