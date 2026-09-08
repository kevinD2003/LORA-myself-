%AUDIT_FUXIANDUIBI Final requirement-level audit for this isolated project.

comparisonRoot = fileparts(mfilename('fullpath'));
sourceRoot = fuxianSourceRoot(comparisonRoot);
resultsRoot = fullfile(comparisonRoot,'results');
finalRoot = fullfile(resultsRoot,'final');
savedPath = path;
restorePath = onCleanup(@() path(savedPath));
addpath(sourceRoot,'-begin');
addpath(comparisonRoot,'-begin');

matlabFiles = dir(fullfile(comparisonRoot,'**','*.m'));
issueCount = 0;
for index = 1:numel(matlabFiles)
    filePath = fullfile(matlabFiles(index).folder,matlabFiles(index).name);
    issues = checkcode(filePath,'-struct');
    issueCount = issueCount+numel(issues);
end
assert(issueCount == 0,'Active Code Analyzer findings remain.');

tests = readtable(fullfile(resultsRoot,'unit_test_results.csv'), ...
    'TextType','string');
assert(height(tests) == 27);
assert(all(tests.Passed) && ~any(tests.Failed) && ...
    ~any(tests.Incomplete));

status = jsondecode(fileread(fullfile(resultsRoot, ...
    'full_run_status.json')));
assert(string(status.state) == "completed");
replay = load(fullfile(resultsRoot, ...
    'stage55_sf11_midamble_three_method_replay', ...
    'fuxian_three_method_replay.mat'));
report = load(fullfile(finalRoot, ...
    'sf11_stage55_three_method_report.mat'));
assert(height(replay.records) == 7632);
assert(~replay.experiment.fittedOrTuned);
assert(replay.experiment.midambleSpacing == 48);
assert(replay.experiment.midambleCount == 2);
assert(replay.config.frameSymbolCount == 122);
freshConfig = fuxianComparisonConfig();
strictConfig = fuxianComparisonConfig( ...
    MidambleSpacingMode="visible_rate_matched", ...
    IncludeTerminalMidamble=true);
assert(isequal(freshConfig.spacingSensitivity,[48 65 81]));
assert(freshConfig.trackingMidambleCount == 2);
assert(freshConfig.toaMidambleCount == 3);
assert(strictConfig.midambleSpacing == 81);
assert(strictConfig.trackingMidambleCount == 1);
assert(strictConfig.toaMidambleCount == 2);
factorial = load(fullfile(resultsRoot, ...
    'pilot_source_crossframe_factorial_smoke','factorial_result.mat'));
assert(height(factorial.records) == 16);
assert(numel(unique(factorial.records.method)) == 4);

methods = string(replay.experiment.methodNames);
ledgers = cell(numel(methods),1);
for index = 1:numel(methods)
    ledgers{index} = localLedger(replay.records,methods(index));
    assert(height(ledgers{index}) == 2544);
end
assert(isequal(ledgers{1},ledgers{2}) && ...
    isequal(ledgers{1},ledgers{3}));
paper = replay.records(strcmp(replay.records.method, ...
    'Paper-Midamble-Point'),:);
other = replay.records(~strcmp(replay.records.method, ...
    'Paper-Midamble-Point'),:);
assert(all(paper.explicitMidambleAcceptedCount == 2));
assert(all(other.explicitMidambleAcceptedCount == 0));

ordering = localHighRateOrdering(report.summary);
assert(all(ordering.senloraSer < ordering.paperSer));
assert(all(ordering.paperSer < ordering.huangSer));
assert(all(ordering.senloraBer < ordering.paperBer));
assert(all(ordering.paperBer < ordering.huangBer));
continuity = localContinuity(sourceRoot,report.summary);
assert(continuity.senloraMaxSer < 1e-3);
assert(continuity.senloraMaxBer < 1e-4);
assert(continuity.huangMaxSer < 3e-3);
assert(continuity.huangMaxBer < 2e-3);

pngFiles = dir(fullfile(finalRoot,'*.png'));
assert(numel(pngFiles) == 2);
assert(isfile(fullfile(finalRoot, ...
    'sf11_stage55_three_method_ser_trajectory.png')));
assert(isfile(fullfile(finalRoot, ...
    'sf11_stage55_three_method_ber_trajectory.png')));

audit = struct();
audit.state = "passed";
audit.matlabRelease = version('-release');
audit.codeAnalyzerFileCount = numel(matlabFiles);
audit.codeAnalyzerIssueCount = issueCount;
audit.unitTestCount = height(tests);
audit.unitTestsPassed = all(tests.Passed);
audit.physicalFrameCount = 2544;
audit.methodCount = 3;
audit.recordCount = height(replay.records);
audit.commonLedger = true;
audit.sf = replay.config.sf;
audit.bandwidthHz = replay.config.bandwidthHz;
audit.payloadDataBits = 704;
audit.payloadDataSymbols = 112;
audit.physicalFrameSymbols = replay.config.frameSymbolCount;
audit.midambleSpacing = replay.experiment.midambleSpacing;
audit.midambleCount = replay.experiment.midambleCount;
audit.fittedOrTuned = replay.experiment.fittedOrTuned;
audit.senloraBaselineMaxSerDelta = continuity.senloraMaxSer;
audit.senloraBaselineMaxBerDelta = continuity.senloraMaxBer;
audit.huangBaselineMaxSerDelta = continuity.huangMaxSer;
audit.huangBaselineMaxBerDelta = continuity.huangMaxBer;
audit.primaryPngCount = numel(pngFiles);
audit.midambleSpacingSensitivity = freshConfig.spacingSensitivity;
audit.paperAnchorSpacing = freshConfig.paperAnchorSpacing;
audit.fullPassRateMatchedSpacing = ...
    freshConfig.fullPassRateMatchedSpacing;
audit.visibleRateMatchedSpacing = ...
    freshConfig.visibleRateMatchedSpacing;
audit.legacyTrackingMidambleCount = ...
    freshConfig.trackingMidambleCount;
audit.legacyToaMidambleCount = freshConfig.toaMidambleCount;
audit.strictV3TrackingMidambleCount = ...
    strictConfig.trackingMidambleCount;
audit.strictV3ToaMidambleCount = strictConfig.toaMidambleCount;
audit.factorialSmokePassed = true;
audit.factorialMethodCount = 4;

auditFile = fullfile(resultsRoot,'audit.json');
fileId = fopen(auditFile,'w');
assert(fileId >= 0);
closeFile = onCleanup(@() fclose(fileId));
fprintf(fileId,'%s',jsonencode(audit));
fprintf('Fuxianduibi audit passed: %s\n',auditFile);

function ledger = localLedger(records,method)
variables = {'snrDb','passIndex','segmentIndex','frameIndex', ...
    'payloadSeed','noiseSeed'};
ledger = sortrows(records(string(records.method) == string(method), ...
    variables),{'snrDb','passIndex','segmentIndex','frameIndex'});
end

function values = localHighRateOrdering(summary)
rows = summary(strcmp(summary.region,'high_doppler_rate'),:);
snrGrid = unique(rows.snrDb);
fields = {'senloraSer','paperSer','huangSer', ...
    'senloraBer','paperBer','huangBer'};
for field = fields
    values.(field{1}) = zeros(numel(snrGrid),1);
end
for index = 1:numel(snrGrid)
    group = rows(rows.snrDb == snrGrid(index),:);
    values.senloraSer(index) = localValue(group, ...
        'Stage55-VP-quality','ser');
    values.paperSer(index) = localValue(group, ...
        'Paper-Midamble-Point','ser');
    values.huangSer(index) = localValue(group, ...
        'Huang-PREC-CP','ser');
    values.senloraBer(index) = localValue(group, ...
        'Stage55-VP-quality','deliveredBer');
    values.paperBer(index) = localValue(group, ...
        'Paper-Midamble-Point','deliveredBer');
    values.huangBer(index) = localValue(group, ...
        'Huang-PREC-CP','deliveredBer');
end
end

function value = localValue(tableIn,method,variable)
value = tableIn.(variable)(strcmp(tableIn.method,method));
end

function result = localContinuity(sourceRoot,newSummary)
old = load(fullfile(sourceRoot,'results', ...
    'stage55_huang_prec_cp_fair_comparison_20260812', ...
    'stage55_fresh_three_method_overall_report.mat'),'summary');
senlora = localDifference(old.summary,newSummary,'Stage55-VP-quality');
huang = localDifference(old.summary,newSummary,'Huang-PREC-CP');
result.senloraMaxSer = max(abs(senlora.oldSer-senlora.newSer));
result.senloraMaxBer = max(abs(senlora.oldBer-senlora.newBer));
result.huangMaxSer = max(abs(huang.oldSer-huang.newSer));
result.huangMaxBer = max(abs(huang.oldBer-huang.newBer));
end

function values = localDifference(oldSummary,newSummary,method)
oldRows = sortrows(oldSummary(strcmp(oldSummary.method,method),:), ...
    {'snrDb','region'});
newRows = sortrows(newSummary(strcmp(newSummary.method,method),:), ...
    {'snrDb','region'});
values.oldSer = oldRows.ser;
values.newSer = newRows.ser;
values.oldBer = oldRows.deliveredBer;
values.newBer = newRows.deliveredBer;
end
