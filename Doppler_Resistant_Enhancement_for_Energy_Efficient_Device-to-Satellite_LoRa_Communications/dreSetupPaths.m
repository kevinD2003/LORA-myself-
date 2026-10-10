function root = dreSetupPaths(includeProject)
%DRESETUPPATHS Add only this reproduction and optional V4 dependencies.

if nargin < 1, includeProject = false; end
root = fileparts(mfilename('fullpath'));
addpath(root,fullfile(root,'config'),fullfile(root,'src'), ...
    fullfile(root,'scripts'),fullfile(root,'tests'));
if includeProject
    workspace = fullfile(fileparts(root),'Lora(eg)');
    v4 = fullfile(workspace,'comparison_experiments', ...
        'stage55_sf12_sf11_flow_v4_noldro');
    addpath(fullfile(v4,'config'));
    children = dir(fullfile(v4,'src'));
    for k = 1:numel(children)
        if children(k).isdir && ~startsWith(children(k).name,'.')
            addpath(fullfile(v4,'src',children(k).name));
        end
    end
end
end
