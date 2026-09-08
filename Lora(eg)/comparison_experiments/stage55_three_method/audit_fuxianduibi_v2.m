%AUDIT_FUXIANDUIBI_V2 审计Stage55主导的SF11-V2正式公平比较。

comparisonRoot = fileparts(mfilename('fullpath'));
resultRoot = fullfile(comparisonRoot,'results');
runRoot = fullfile(resultRoot,'sf11_receiver_v2_run');
replayRoot = fullfile(resultRoot, ...
    'stage55_sf11_midamble_v2_three_method_replay');
reportRoot = fullfile(resultRoot,'final_sf11_receiver_v2');

status = jsondecode(fileread(fullfile(runRoot,'full_run_status.json')));
assert(string(status.state) == "completed");
replay = load(fullfile(replayRoot,'fuxian_three_method_replay.mat'));
report = load(fullfile(reportRoot,'sf11_stage55_three_method_report.mat'));
legacy = load(fullfile(resultRoot, ...
    'stage55_sf11_midamble_three_method_replay', ...
    'fuxian_three_method_replay.mat'));

assert(height(replay.records) == 7632);
assert(replay.config.sf == 11);
assert(replay.config.bandwidthHz == 250e3);
assert(replay.config.frameSymbolCount == 122);
assert(replay.experiment.midambleSpacing == 48);
assert(replay.experiment.midambleCount == 2);
assert(replay.experiment.paperReceiverVersion == "sf11_v2");
assert(replay.experiment.sourceProfileFittedOrTuned);
assert(~replay.experiment.stage55ResultTuned);
assert(replay.experiment.fittedOrTuned);

methods = string(replay.experiment.methodNames);
ledgers = cell(numel(methods),1);
for methodIndex = 1:numel(methods)
    ledgers{methodIndex} = localLedger( ...
        replay.records,methods(methodIndex));
    assert(height(ledgers{methodIndex}) == 2544);
end
assert(isequal(ledgers{1},ledgers{2}) && ...
    isequal(ledgers{1},ledgers{3}));

paper = replay.records(strcmp(replay.records.method, ...
    'Paper-Midamble-Point'),:);
other = replay.records(~strcmp(replay.records.method, ...
    'Paper-Midamble-Point'),:);
assert(all(paper.explicitMidambleAcceptedCount == 2));
assert(all(other.explicitMidambleAcceptedCount == 0));

unchangedMethods = ["Huang-PREC-CP", "Stage55-VP-quality"];
maximumCfoSseDelta = 0;
for method = unchangedMethods
    [exactMatch,cfoSseDelta] = localMethodMetricsMatch( ...
        legacy.records,replay.records,method);
    assert(exactMatch, ...
        'V2不应改变Stage55或Huang分支。');
    maximumCfoSseDelta = max(maximumCfoSseDelta,cfoSseDelta);
end
assert(maximumCfoSseDelta <= 1e-10, ...
    'CFO平方和的浮点重算差超过容差。');

assert(height(report.summary) == 12);
assert(isfile(fullfile(reportRoot, ...
    'sf11_stage55_three_method_ser_trajectory.png')));
assert(isfile(fullfile(reportRoot, ...
    'sf11_stage55_three_method_ber_trajectory.png')));

audit = struct();
audit.state = "passed";
audit.stage55IsPrimary = true;
audit.paperReceiverVersion = "sf11_v2";
audit.sourceProfileFittedOrTuned = true;
audit.stage55ResultTuned = false;
audit.commonPhysicalLedger = true;
audit.physicalFrameCount = 2544;
audit.recordCount = height(replay.records);
audit.methodCount = numel(methods);
audit.sf = replay.config.sf;
audit.bandwidthHz = replay.config.bandwidthHz;
audit.payloadDataBits = 704;
audit.payloadDataSymbols = 112;
audit.physicalFrameSymbols = 122;
audit.midambleSpacing = 48;
audit.midambleCount = 2;
audit.stage55AndHuangUnchanged = true;
audit.maximumStage55HuangCfoSseDelta = maximumCfoSseDelta;
audit.cfoSseComparisonTolerance = 1e-10;
audit.primaryFigureCount = 2;
audit.performanceOrderingIsObservationOnly = true;
fileId = fopen(fullfile(runRoot,'audit.json'),'w');
assert(fileId >= 0,'无法写入V2审计文件。');
closeFile = onCleanup(@() fclose(fileId));
fprintf(fileId,'%s',jsonencode(audit));
fprintf('Stage55/SF11-V2正式审计通过。\n');

function ledger = localLedger(records,method)
variables = {'snrDb','passIndex','segmentIndex','frameIndex', ...
    'payloadSeed','noiseSeed'};
ledger = sortrows(records(string(records.method) == method,variables), ...
    {'snrDb','passIndex','segmentIndex','frameIndex'});
end

function [exactMatch,cfoSseDelta] = localMethodMetricsMatch( ...
    oldRecords,newRecords,method)
exactVariables = {'snrDb','passIndex','segmentIndex','frameIndex', ...
    'payloadSeed','noiseSeed','symbolCount','symbolErrors','bitCount', ...
    'hardBitErrors','deliveredBitErrors','deliveredFrameError', ...
    'cfoSampleCount','acceptedVirtualPilots', ...
    'falseAcceptedVirtualPilots','estimatedFrameCfoBins'};
oldRows = sortrows(oldRecords(string(oldRecords.method) == method,:), ...
    {'snrDb','passIndex','segmentIndex','frameIndex'});
newRows = sortrows(newRecords(string(newRecords.method) == method,:), ...
    {'snrDb','passIndex','segmentIndex','frameIndex'});
exactMatch = isequaln(oldRows(:,exactVariables), ...
    newRows(:,exactVariables));
cfoSseDelta = max(abs(oldRows.cfoSseBins-newRows.cfoSseBins));
end
