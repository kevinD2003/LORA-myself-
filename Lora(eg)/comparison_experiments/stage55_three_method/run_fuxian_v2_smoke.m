%RUN_FUXIAN_V2_SMOKE 四帧共同账本的Stage55/SF11-V2接线验证。

comparisonRoot = fileparts(mfilename('fullpath'));
sourceRoot = fuxianSourceRoot(comparisonRoot);
savedPath = path;
restorePath = onCleanup(@() path(savedPath));
addpath(sourceRoot,'-begin');
addpath(comparisonRoot,'-begin');

report = run_fuxian_stage55_three_method_replay( ...
    SnrGridDb=-21,PassCount=1,FramesPerVisibleSegment=2, ...
    OutputFolderName='smoke_sf11_receiver_v2', ...
    ProgressEveryFrames=Inf,PaperReceiverVersion="sf11_v2");
records = report.records;
methods = string(report.experiment.methodNames);
assert(height(records) == 12);
assert(report.experiment.sourceProfileFittedOrTuned);
assert(~report.experiment.stage55ResultTuned);
assert(report.options.PaperReceiverVersion == "sf11_v2");
for method = methods.'
    branch = sortrows(records(string(records.method) == method, :), ...
        {'snrDb','passIndex','segmentIndex','frameIndex'});
    assert(height(branch) == 4);
end
paper = records(strcmp(records.method,'Paper-Midamble-Point'),:);
assert(all(paper.explicitMidambleAcceptedCount == 2));
assert(all(records.symbolCount == 112));
assert(all(records.bitCount == 704));
fprintf('Stage55/SF11-V2共同账本冒烟通过：%s\n',report.resultDir);
