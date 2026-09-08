function sourceRoot = fuxianSourceRoot(comparisonRoot)
%FUXIANSOURCEROOT Locate the Stage55 main-method source after reorganization.

if nargin < 1 || isempty(comparisonRoot)
    comparisonRoot = fileparts(mfilename('fullpath'));
end
workspaceRoot = fileparts(fileparts(comparisonRoot));
sourceRoot = fullfile(workspaceRoot,'project','orbit_doppler', ...
    'satellite_fig3_rolling8');
if ~isfolder(sourceRoot)
    error('Fuxian:SourceRootNotFound', ...
        'Stage55 main-project folder not found: %s',sourceRoot);
end
end
