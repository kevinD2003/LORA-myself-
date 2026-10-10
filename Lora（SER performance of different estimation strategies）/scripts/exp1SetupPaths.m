function paths = exp1SetupPaths()
%EXP1SETUPPATHS Add EXP1 first and its frozen parent as a read-only dependency.

projectRoot = fileparts(fileparts(mfilename('fullpath')));
parentRoot = fullfile(fileparts(projectRoot),'Lora(eg)', ...
    'comparison_experiments','stage55_sf12_sf11_flow_v4_noldro');
addpath(fullfile(projectRoot,'configs'));
addpath(fullfile(projectRoot,'src'));
addpath(fullfile(projectRoot,'scripts'));
addpath(fullfile(projectRoot,'tests'));
addpath(genpath(parentRoot),'-end');
paths = struct('projectRoot',projectRoot,'parentRoot',parentRoot, ...
    'resultsRoot',fullfile(projectRoot,'results'), ...
    'figuresRoot',fullfile(projectRoot,'figures'), ...
    'auditsRoot',fullfile(projectRoot,'audits'));
end
