function runAuthorFigureReproductionBackground()
%RUNAUTHORFIGUREREPRODUCTIONBACKGROUND Logged author-source full run.

projectRoot = fileparts(fileparts(mfilename('fullpath')));
resultsFolder = fullfile(projectRoot, 'results');
if ~isfolder(resultsFolder)
    mkdir(resultsFolder);
end
logPath = fullfile(resultsFolder, 'author_source_full_run.log');
statusPath = fullfile(resultsFolder, ...
    'author_source_full_run_status.json');
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
        'runAuthorFigureReproduction.m'));
    status.state = "completed";
    status.completedAt = string(datetime('now', 'Format', ...
        'yyyy-MM-dd HH:mm:ss'));
    status.message = "Author-source SF7/SF12 run completed.";
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
assert(fileId >= 0, 'Cannot write author-source status file.');
closeFile = onCleanup(@() fclose(fileId));
fprintf(fileId, '%s', jsonencode(status));
end
