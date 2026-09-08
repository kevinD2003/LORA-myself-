%REPRODUCECASE2SF12 Full Figure 11 right-panel Midamble-Point experiment.

projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(projectRoot, 'config'));
addpath(fullfile(projectRoot, 'src'));
cfg = paperSf12Config();
limits = monteCarloLimits(cfg, "full");
runReproductionCase(cfg, "case2", cfg.monteCarlo.snrDb, ...
    limits, fullfile(projectRoot, 'results'), "");
