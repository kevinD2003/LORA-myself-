function folder = strictPaperSetup()
%STRICTPAPERSETUP Load this independent experiment and existing PHY helpers.
folder = fileparts(mfilename('fullpath'));
parent = fileparts(folder);
addpath(parent);
dreSetupPaths(false);
addpath(folder);
end
