function run_fuxian_full_background()
%RUN_FUXIAN_FULL_BACKGROUND Logged wrapper for the long comparison.

comparisonRoot = fileparts(mfilename('fullpath'));
resultsFolder = fullfile(comparisonRoot,'results');
logPath = fullfile(resultsFolder,'full_run.log');
statusPath = fullfile(resultsFolder,'full_run_status.json');
diary(logPath);
diary on;
closeDiary = onCleanup(@() diary('off'));

status.state = "running";
status.startedAt = string(datetime('now','Format', ...
    'yyyy-MM-dd HH:mm:ss'));
status.completedAt = "";
status.message = "";
localWriteStatus(statusPath,status);
try
    run(fullfile(comparisonRoot,'run_fuxian_full.m'));
    status.state = "completed";
    status.completedAt = string(datetime('now','Format', ...
        'yyyy-MM-dd HH:mm:ss'));
    status.message = "Full three-method replay and BER/SER report completed.";
    localWriteStatus(statusPath,status);
catch exception
    status.state = "failed";
    status.completedAt = string(datetime('now','Format', ...
        'yyyy-MM-dd HH:mm:ss'));
    status.message = string(exception.message);
    localWriteStatus(statusPath,status);
    fprintf('%s\n',getReport(exception,'extended', ...
        'hyperlinks','off'));
    rethrow(exception);
end
end

function localWriteStatus(pathName,status)
fileId = fopen(pathName,'w');
assert(fileId >= 0,'Cannot write comparison status file.');
closeFile = onCleanup(@() fclose(fileId));
fprintf(fileId,'%s',jsonencode(status));
end
