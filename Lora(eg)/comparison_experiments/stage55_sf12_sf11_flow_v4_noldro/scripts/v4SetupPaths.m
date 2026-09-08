function root = v4SetupPaths()
%V4SETUPPATHS Add only V4 implementation paths, excluding frozen SF11 code.

root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'config'));
addpath(fullfile(root,'src','phy'));
addpath(fullfile(root,'src','coding'));
addpath(fullfile(root,'src','stage55'));
addpath(fullfile(root,'src','paper'));
addpath(fullfile(root,'src','statistics'));
addpath(fullfile(root,'src','infrastructure'));
paperAnchor = fullfile(root,'src','paper_anchor');
if isfolder(paperAnchor), addpath(paperAnchor); end
addpath(fullfile(root,'scripts'));
addpath(fullfile(root,'tests'));
end
