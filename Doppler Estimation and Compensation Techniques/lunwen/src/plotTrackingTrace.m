function plotTrackingTrace(trace, outputPng)
%PLOTTRACKINGTRACE Plot true, Point and staircase Midamble-Point estimates.

arguments
    trace (1,1) struct
    outputPng (1,1) string
end

if trace.caseName == "case1"
    caseLabel = "Case 1";
else
    caseLabel = "Case 2";
end
fig = figure('Visible', 'off', 'Color', 'w', ...
    'Position', [100 100 900 560]);
cleanupFigure = onCleanup(@() close(fig));
axesHandle = axes(fig);
plot(axesHandle, trace.dataTimeS, trace.trueDopplerHz, ...
    '-', 'LineWidth', 1.8, 'Color', [0.8500 0.3250 0.0980]);
hold(axesHandle, 'on');
plot(axesHandle, trace.dataTimeS, trace.pointEstimateHz, ...
    '--', 'LineWidth', 1.5, 'Color', [0 0.4470 0.7410]);
stairs(axesHandle, trace.dataTimeS, trace.midamblePointEstimateHz, ...
    '-x', 'LineWidth', 1.5, 'Color', [0.3010 0.7450 0.9330]);
grid(axesHandle, 'on');
xlabel(axesHandle, 'Time within frame [s]');
ylabel(axesHandle, 'Doppler shift [Hz]');
title(axesHandle, caseLabel + " - SF = " + ...
    string(trace.spreadingFactor) + " tracking diagnostic");
legend(axesHandle, ["True Doppler", "Point estimate", ...
    "Midamble-Point estimate"], 'Location', 'best');
outputFolder = fileparts(outputPng);
if ~isfolder(outputFolder)
    mkdir(outputFolder);
end
exportgraphics(fig, outputPng, 'Resolution', 200);
[~, baseName] = fileparts(outputPng);
savefig(fig, fullfile(outputFolder, baseName + ".fig"));
end
