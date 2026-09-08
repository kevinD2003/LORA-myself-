%REPRODUCECASE1SF12 Full Figure 10 right-panel Midamble-Point experiment.

projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(projectRoot, 'config'));
addpath(fullfile(projectRoot, 'src'));
cfg = paperSf12Config();
limits = monteCarloLimits(cfg, "full");
runReproductionCase(cfg, "case1", cfg.monteCarlo.snrDb, ...
    limits, fullfile(projectRoot, 'results'), "");
