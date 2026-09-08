%REFINECALIBRATEDCURVEORDERING Increase trials where paper curves are close.

projectRoot = fileparts(fileparts(mfilename('fullpath')));
outputFolder = fullfile(projectRoot, 'results', 'calibrated', 'curves');
addpath(fullfile(projectRoot, 'config'));
addpath(fullfile(projectRoot, 'src'));
limits = struct('batchPackets', 32, 'minimumPackets', 5000, ...
    'maximumPackets', 5000, 'minimumSymbolErrors', 0);
panels = table([7; 7; 12], ["case1"; "case2"; "case1"], ...
    'VariableNames', {'spreadingFactor', 'caseName'});
copiedNames = ["ser", "ci95Low", "ci95High", "symbolErrors", ...
    "totalSymbols", "packets", "randomSeed", "fittedOrTuned"];

for panelIndex = 1:height(panels)
    spreadingFactor = panels.spreadingFactor(panelIndex);
    caseName = panels.caseName(panelIndex);
    if spreadingFactor == 7
        cfg = calibratedPaperSf7Config();
    else
        cfg = calibratedPaperSf12Config();
    end
    outputCsv = fullfile(outputFolder, ...
        caseName + "_sf" + spreadingFactor + "_calibrated.csv");
    data = readtable(outputCsv, 'TextType', 'string');
    for strategy = ["point", "midamble_point"]
        for snrDb = cfg.monteCarlo.snrDb
            result = simulateSerPoint( ...
                cfg, caseName, strategy, snrDb, limits);
            selected = data.strategy == strategy & data.snrDb == snrDb;
            assert(nnz(selected) == 1);
            resultTable = struct2table(result, 'AsArray', true);
            for variableName = copiedNames
                data.(variableName)(selected) = ...
                    resultTable.(variableName);
            end
            writetable(data, outputCsv);
            fprintf('SF=%d %s %s SNR=%g SER=%g\n', ...
                spreadingFactor, caseName, strategy, snrDb, result.ser);
        end
    end
    pointRows = sortrows(data(data.strategy == "point", :), 'snrDb');
    midambleRows = sortrows( ...
        data(data.strategy == "midamble_point", :), 'snrDb');
    orderingMargin = midambleRows.ser-pointRows.ser;
    assert(all(orderingMargin >= 0), ...
        'Paper ordering not resolved for SF=%d %s.', ...
        spreadingFactor, caseName);
end
fprintf('All close-curve panels satisfy Point <= Midamble-Point.\n');
