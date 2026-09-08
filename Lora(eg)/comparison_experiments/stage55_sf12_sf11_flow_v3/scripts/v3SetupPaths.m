function root = v3SetupPaths()
%V3SETUPPATHS Add only V3 implementation paths, excluding frozen SF11 code.

root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'config'));
addpath(fullfile(root,'src','phy'));
addpath(fullfile(root,'src','coding'));
addpath(fullfile(root,'src','stage55'));
addpath(fullfile(root,'src','paper'));
addpath(fullfile(root,'src','statistics'));
addpath(fullfile(root,'scripts'));
end

