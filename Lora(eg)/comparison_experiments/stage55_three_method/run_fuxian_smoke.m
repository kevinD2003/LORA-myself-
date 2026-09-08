%RUN_FUXIAN_SMOKE Small common-ledger replay before the full experiment.

comparisonRoot = fileparts(mfilename('fullpath'));
sourceRoot = fuxianSourceRoot(comparisonRoot);
savedPath = path;
restorePath = onCleanup(@() path(savedPath));
addpath(sourceRoot,'-begin');
addpath(comparisonRoot,'-begin');

report = run_fuxian_stage55_three_method_replay( ...
    SnrGridDb=-21,PassCount=1,FramesPerVisibleSegment=2, ...
    OutputFolderName='smoke',ProgressEveryFrames=Inf);
records = report.records;
methods = string(report.experiment.methodNames);
assert(height(records) == 12);
for method = methods.'
    branch = sortrows(records(string(records.method) == method, :), ...
        {'snrDb','passIndex','segmentIndex','frameIndex'});
    assert(height(branch) == 4);
end
paper = records(strcmp(records.method,'Paper-Midamble-Point'),:);
assert(all(paper.explicitMidambleAcceptedCount == 2));
assert(all(records.symbolCount == 112));
assert(all(records.bitCount == 704));
fprintf('Fuxian smoke passed: %s\n',report.resultDir);
