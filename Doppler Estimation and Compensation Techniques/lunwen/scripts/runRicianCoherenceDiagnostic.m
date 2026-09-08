%RUNRICIANCOHERENCEDIAGNOSTIC Compare packet- and symbol-coherent fading.

projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(projectRoot, 'config'));
addpath(fullfile(projectRoot, 'src'));
cfg = paperSf12Config();
packetResult = simulateNoDopplerCoherence( ...
    cfg, -21, 5056, "packet");
symbolResult = simulateNoDopplerCoherence( ...
    cfg, -21, 5056, "symbol");
diagnosticTable = struct2table([packetResult, symbolResult]);
outputCsv = fullfile(projectRoot, 'results', ...
    'rician_coherence_diagnostic.csv');
writetable(diagnosticTable, outputCsv);
disp(diagnosticTable);
fprintf('Wrote %s\n', outputCsv);
