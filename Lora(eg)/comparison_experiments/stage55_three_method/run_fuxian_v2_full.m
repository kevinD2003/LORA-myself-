%RUN_FUXIAN_V2_FULL Stage55主导的SF11-V2三方法正式重放与报告。

comparisonRoot = fileparts(mfilename('fullpath'));
sourceRoot = fuxianSourceRoot(comparisonRoot);
savedPath = path;
restorePath = onCleanup(@() path(savedPath));
addpath(sourceRoot,'-begin');
addpath(comparisonRoot,'-begin');

replay = run_fuxian_stage55_three_method_replay( ...
    OutputFolderName='stage55_sf11_midamble_v2_three_method_replay', ...
    PaperReceiverVersion="sf11_v2");
report = build_fuxian_stage55_report( ...
    ReplayMatFile=replay.matFile, ...
    OutputFolderName='final_sf11_receiver_v2', ...
    WindowDurationSec=10);
fprintf('Stage55/SF11-V2正式比较完成：%s\n',report.outputFolder);
