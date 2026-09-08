function runAllReproductionBackground()
%RUNALLREPRODUCTIONBACKGROUND Logged wrapper for the full Monte Carlo run.

projectRoot = fileparts(fileparts(mfilename('fullpath')));
resultsFolder = fullfile(projectRoot, 'results');
if ~isfolder(resultsFolder)
    mkdir(resultsFolder);
end
logPath = fullfile(resultsFolder, 'full_run.log');
statusPath = fullfile(resultsFolder, 'full_run_status.json');
diary(logPath);
diary on;
closeDiary = onCleanup(@() diary('off'));

status.state = "running";
status.startedAt = string(datetime('now', 'Format', ...
    'yyyy-MM-dd HH:mm:ss'));
status.completedAt = "";
status.message = "";
writeStatus(statusPath, status);
try
    run(fullfile(projectRoot, 'scripts', 'runAllReproduction.m'));
    status.state = "completed";
    status.completedAt = string(datetime('now', 'Format', ...
        'yyyy-MM-dd HH:mm:ss'));
    status.message = "Full Case 1 and Case 2 reproduction completed.";
    writeStatus(statusPath, status);
catch exception
    status.state = "failed";
    status.completedAt = string(datetime('now', 'Format', ...
        'yyyy-MM-dd HH:mm:ss'));
    status.message = string(exception.message);
    writeStatus(statusPath, status);
    fprintf('%s\n', getReport(exception, 'extended', ...
        'hyperlinks', 'off'));
    rethrow(exception);
end
end

function writeStatus(statusPath, status)
fileId = fopen(statusPath, 'w');
if fileId < 0
    error('runAllReproductionBackground:CannotWriteStatus', ...
        'Cannot open %s.', statusPath);
end
closeFile = onCleanup(@() fclose(fileId));
fprintf(fileId, '%s', jsonencode(status));
end
