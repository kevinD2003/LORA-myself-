function runSf7ReproductionBackground()
%RUNSF7REPRODUCTIONBACKGROUND Logged wrapper for the full SF=7 run.

projectRoot = fileparts(fileparts(mfilename('fullpath')));
resultsFolder = fullfile(projectRoot, 'results');
if ~isfolder(resultsFolder)
    mkdir(resultsFolder);
end
logPath = fullfile(resultsFolder, 'sf7_full_run.log');
statusPath = fullfile(resultsFolder, 'sf7_full_run_status.json');
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
    run(fullfile(projectRoot, 'scripts', ...
        'runSf7Reproduction.m'));
    status.state = "completed";
    status.completedAt = string(datetime('now', 'Format', ...
        'yyyy-MM-dd HH:mm:ss'));
    status.message = "Full SF=7 Case 1 and Case 2 run completed.";
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
assert(fileId >= 0, 'Cannot write SF=7 status file.');
closeFile = onCleanup(@() fclose(fileId));
fprintf(fileId, '%s', jsonencode(status));
end
