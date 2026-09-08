%RUNCALIBRATEDSF11SIMULATION 生成SF11校准接收机的正式原始计数。

projectRoot = fileparts(fileparts(mfilename('fullpath')));
outputFolder = fullfile(projectRoot, 'results', 'calibrated_sf11', 'curves');
if ~isfolder(outputFolder)
    mkdir(outputFolder);
end
addpath(fullfile(projectRoot, 'config'));
addpath(fullfile(projectRoot, 'src'));
cfg = calibratedPaperSf11Config();
limits = struct('batchPackets', 32, 'minimumPackets', 5000, ...
    'maximumPackets', 5000, 'minimumSymbolErrors', 0);
strategies = ["no_doppler", "point", "midamble_point"];

for caseName = ["case1", "case2"]
    results = struct([]);
    rowIndex = 0;
    outputCsv = fullfile(outputFolder, ...
        caseName + "_sf11_calibrated.csv");
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
            writetable(struct2table(results), outputCsv);
            fprintf('SF11 %s %s SNR=%g SER=%g\n', ...
                caseName, strategy, snrDb, result.ser);
        end
    end
end
fprintf('SF11校准仿真完成，请在新MATLAB进程中运行审计和绘图脚本。\n');
