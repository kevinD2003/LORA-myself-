function runSf11ReproductionBackground()
%RUNSF11REPRODUCTIONBACKGROUND Logged wrapper for the SF=11 run.

projectRoot = fileparts(fileparts(mfilename('fullpath')));
resultsFolder = fullfile(projectRoot, 'results');
if ~isfolder(resultsFolder)
    mkdir(resultsFolder);
end
logPath = fullfile(resultsFolder, 'sf11_full_run.log');
statusPath = fullfile(resultsFolder, 'sf11_full_run_status.json');
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
        'runSf11Reproduction.m'));
    status.state = "completed";
    status.completedAt = string(datetime('now', 'Format', ...
        'yyyy-MM-dd HH:mm:ss'));
    status.message = "Full SF=11 Case 1 and Case 2 run completed.";
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
assert(fileId >= 0, 'Cannot write SF=11 status file.');
closeFile = onCleanup(@() fclose(fileId));
fprintf(fileId, '%s', jsonencode(status));
end
