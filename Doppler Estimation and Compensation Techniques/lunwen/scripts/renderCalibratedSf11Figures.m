%RENDERCALIBRATEDSF11FIGURES 绘制通过审计的SF11校准曲线。

projectRoot = fileparts(fileparts(mfilename('fullpath')));
curveFolder = fullfile(projectRoot, 'results', 'calibrated_sf11', 'curves');
addpath(fullfile(projectRoot, 'config'));
addpath(fullfile(projectRoot, 'src'));
cfg = calibratedPaperSf11Config();

for caseName = ["case1", "case2"]
    inputCsv = fullfile(curveFolder, ...
        caseName + "_sf11_calibrated.csv");
    outputPng = fullfile(curveFolder, ...
        caseName + "_sf11_calibrated.png");
    plotSerResults(inputCsv, outputPng, ...
        "SF11 calibrated receiver - " + caseName, cfg, true);
end
combineCaseFigureFiles( ...
    fullfile(curveFolder, 'case1_sf11_calibrated.png'), ...
    fullfile(curveFolder, 'case2_sf11_calibrated.png'), ...
    fullfile(curveFolder, 'sf11_calibrated_case1_case2.png'));
fprintf('SF11校准图已生成。\n');
