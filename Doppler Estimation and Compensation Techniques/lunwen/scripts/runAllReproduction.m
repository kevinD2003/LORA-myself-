%RUNALLREPRODUCTION Full Figure 10/11 SF=12 three-curve reproduction.

projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(projectRoot, 'config'));
addpath(fullfile(projectRoot, 'src'));
cfg = paperSf12Config();
limits = monteCarloLimits(cfg, "full");
resultsFolder = fullfile(projectRoot, 'results');

startTime = tic;
runReproductionCase(cfg, "case1", cfg.monteCarlo.snrDb, ...
    limits, resultsFolder, "");
runReproductionCase(cfg, "case2", cfg.monteCarlo.snrDb, ...
    limits, resultsFolder, "");
fprintf('Full reproduction completed in %.1f s.\n', toc(startTime));
