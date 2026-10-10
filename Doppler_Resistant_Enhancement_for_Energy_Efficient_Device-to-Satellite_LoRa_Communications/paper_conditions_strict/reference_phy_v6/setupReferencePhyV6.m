function folder = setupReferencePhyV6()
%SETUPREFERENCEPHYV6 Keep the frozen v5 source and caches unmodified.
folder=fileparts(mfilename('fullpath'));
addpath(fileparts(folder));strictPaperSetup();addpath(folder);
end
