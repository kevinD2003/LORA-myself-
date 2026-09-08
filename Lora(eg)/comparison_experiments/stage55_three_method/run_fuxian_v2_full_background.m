function run_fuxian_v2_full_background()
%RUN_FUXIAN_V2_FULL_BACKGROUND 带日志和状态文件的长时正式入口。

comparisonRoot = fileparts(mfilename('fullpath'));
resultRoot = fullfile(comparisonRoot,'results','sf11_receiver_v2_run');
if ~isfolder(resultRoot)
    mkdir(resultRoot);
end
logPath = fullfile(resultRoot,'full_run.log');
statusPath = fullfile(resultRoot,'full_run_status.json');
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
    run(fullfile(comparisonRoot,'run_fuxian_v2_full.m'));
    status.state = "completed";
    status.completedAt = string(datetime('now','Format', ...
        'yyyy-MM-dd HH:mm:ss'));
    status.message = "Stage55/SF11-V2三方法正式重放和报告已完成。";
    localWriteStatus(statusPath,status);
    run(fullfile(comparisonRoot,'audit_fuxianduibi_v2.m'));
    status.message = "Stage55/SF11-V2正式重放、报告和审计已完成。";
    localWriteStatus(statusPath,status);
catch exception
    status.state = "failed";
    status.completedAt = string(datetime('now','Format', ...
        'yyyy-MM-dd HH:mm:ss'));
    status.message = string(exception.message);
    localWriteStatus(statusPath,status);
    fprintf('%s\n',getReport(exception,'extended','hyperlinks','off'));
    rethrow(exception);
end
end

function localWriteStatus(pathName,status)
fileId = fopen(pathName,'w');
assert(fileId >= 0,'无法写入V2状态文件。');
closeFile = onCleanup(@() fclose(fileId));
fprintf(fileId,'%s',jsonencode(status));
end
