%SEARCHCALIBRATIONROBUSTNESS Refine K using a second random seed.

projectRoot = fileparts(fileparts(mfilename('fullpath')));
outputFolder = fullfile(projectRoot, 'results', 'calibrated', 'search');
addpath(fullfile(projectRoot, 'config'));
addpath(fullfile(projectRoot, 'src'));
limits = struct('batchPackets', 32, 'minimumPackets', 1000, ...
    'maximumPackets', 1000, 'minimumSymbolErrors', 0);
rows = table();
for kDb = [12.25, 12.5, 12.75]
    cfg = calibratedPaperSf7Config();
    cfg.channel.ricianKDb = kDb;
    for caseName = ["case1", "case2"]
        for strategy = ["no_doppler", "point", "midamble_point"]
            result = simulateSerPoint(cfg, caseName, strategy, -6, limits);
            rows = [rows; table(kDb, caseName, strategy, result.ser, ...
                result.symbolErrors, result.totalSymbols, true, ...
                'VariableNames', {'ricianKDb', 'caseName', 'strategy', ...
                'ser', 'symbolErrors', 'totalSymbols', ...
                'fittedOrTuned'})]; %#ok<AGROW>
            fprintf('K=%.2f %s %s SER=%g\n', ...
                kDb, caseName, strategy, result.ser);
        end
    end
end
writetable(rows, fullfile(outputFolder, ...
    'calibration_robustness_search.csv'));
