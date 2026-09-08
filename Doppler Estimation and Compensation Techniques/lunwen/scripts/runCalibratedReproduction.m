%RUNCALIBRATEDREPRODUCTION Generate explicitly fitted Figure 10/11 curves.

projectRoot = fileparts(fileparts(mfilename('fullpath')));
outputFolder = fullfile(projectRoot, 'results', 'calibrated', 'curves');
if ~isfolder(outputFolder)
    mkdir(outputFolder);
end
addpath(fullfile(projectRoot, 'config'));
addpath(fullfile(projectRoot, 'src'));

limits = struct('batchPackets', 32, 'minimumPackets', 1000, ...
    'maximumPackets', 1000, 'minimumSymbolErrors', 0);
strategies = ["no_doppler", "point", "midamble_point"];
for spreadingFactor = [7, 12]
    if spreadingFactor == 7
        cfg = calibratedPaperSf7Config();
    else
        cfg = calibratedPaperSf12Config();
    end
    for caseName = ["case1", "case2"]
        results = struct([]);
        rowIndex = 0;
        for strategy = strategies
            for snrDb = cfg.monteCarlo.snrDb
                rowIndex = rowIndex + 1;
                result = simulateSerPoint( ...
                    cfg, caseName, strategy, snrDb, limits);
                if rowIndex == 1
                    results = result;
                else
                    results(rowIndex) = result;
                end
                resultTable = struct2table(results);
                outputCsv = fullfile(outputFolder, ...
                    caseName + "_sf" + spreadingFactor + ...
                    "_calibrated.csv");
                writetable(resultTable, outputCsv);
                fprintf('SF=%d %s %s SNR=%g SER=%g\n', ...
                    spreadingFactor, caseName, strategy, ...
                    snrDb, result.ser);
            end
        end
    end
end
fprintf(['Calibrated curve data complete. Run ', ...
    'renderCalibratedFigures.m in a fresh MATLAB process.\n']);
