function projectRoot = sf12SetupPaths()
%SF12SETUPPATHS Add only this isolated comparison project's code.

projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(projectRoot,'config'),fullfile(projectRoot,'src'), ...
    fullfile(projectRoot,'scripts'));
end
