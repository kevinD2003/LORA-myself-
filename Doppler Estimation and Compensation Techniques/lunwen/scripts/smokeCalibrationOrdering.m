%SMOKECALIBRATIONORDERING Fast algorithm-ordering check before full curves.

projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(projectRoot, 'config'));
addpath(fullfile(projectRoot, 'src'));
limits = struct('batchPackets', 32, 'minimumPackets', 1000, ...
    'maximumPackets', 1000, 'minimumSymbolErrors', 0);
panels = table([7; 7; 12], ["case1"; "case2"; "case1"], ...
    'VariableNames', {'spreadingFactor', 'caseName'});
for panelIndex = 1:height(panels)
    spreadingFactor = panels.spreadingFactor(panelIndex);
    caseName = panels.caseName(panelIndex);
    if spreadingFactor == 7
        cfg = calibratedPaperSf7Config();
        snrDb = -6;
    else
        cfg = calibratedPaperSf12Config();
        snrDb = -21;
    end
    point = simulateSerPoint(cfg, caseName, "point", snrDb, limits);
    midamble = simulateSerPoint( ...
        cfg, caseName, "midamble_point", snrDb, limits);
    fprintf('SF=%d %s Point=%g Midamble=%g margin=%g\n', ...
        spreadingFactor, caseName, point.ser, midamble.ser, ...
        midamble.ser-point.ser);
end
