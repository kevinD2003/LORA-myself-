function folder = setupReferenceSoftPhy
%SETUPREFERENCESOFTPHY Isolated standard-soft option; frozen receivers unchanged.
folder=fileparts(mfilename('fullpath'));
addpath(folder,fullfile(fileparts(folder),'reference_phy_v6'));setupReferencePhyV6;
end
