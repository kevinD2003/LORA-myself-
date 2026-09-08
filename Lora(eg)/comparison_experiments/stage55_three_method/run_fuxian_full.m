%RUN_FUXIAN_FULL Full common-frame replay and final two-figure report.

comparisonRoot = fileparts(mfilename('fullpath'));
sourceRoot = fuxianSourceRoot(comparisonRoot);
savedPath = path;
restorePath = onCleanup(@() path(savedPath));
addpath(sourceRoot,'-begin');
addpath(comparisonRoot,'-begin');

replay = run_fuxian_stage55_three_method_replay();
report = build_fuxian_stage55_report( ...
    ReplayMatFile=replay.matFile,OutputFolderName='final', ...
    WindowDurationSec=10);
fprintf('Fuxian full comparison and report complete: %s\n', ...
    report.outputFolder);
