%AUDITPUBLICATIONCONSISTENCY Write machine-readable paper consistency proof.

projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(projectRoot, 'config'));
addpath(fullfile(projectRoot, 'src'));

analysis = analyzePublicationConsistency(paperSf12Config());
assert(analysis.paperInternalConflictProved);

outputPath = fullfile(projectRoot, 'results', ...
    'publication_consistency.json');
fileId = fopen(outputPath, 'w');
assert(fileId >= 0);
closeFile = onCleanup(@() fclose(fileId));
fprintf(fileId, '%s', jsonencode(analysis));
fprintf('Publication consistency audit: %s\n', outputPath);
