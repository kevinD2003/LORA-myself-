%RUNSMOKEREPRODUCTION Small Case 1/2 run before the full experiment.

projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(projectRoot, 'config'));
addpath(fullfile(projectRoot, 'src'));
cfg = paperSf12Config();
limits = monteCarloLimits(cfg, "smoke");
resultsFolder = fullfile(projectRoot, 'results');

startTime = tic;
runReproductionCase(cfg, "case1", cfg.smoke.snrDb, ...
    limits, resultsFolder, "_smoke");
runReproductionCase(cfg, "case2", cfg.smoke.snrDb, ...
    limits, resultsFolder, "_smoke");
fprintf('Smoke reproduction completed in %.1f s.\n', toc(startTime));
