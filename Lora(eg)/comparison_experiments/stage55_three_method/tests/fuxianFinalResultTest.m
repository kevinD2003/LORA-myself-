classdef fuxianFinalResultTest < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addProjectPaths(testCase)
            import matlab.unittest.fixtures.PathFixture
            comparisonRoot = fileparts(fileparts(mfilename('fullpath')));
            sourceRoot = fuxianSourceRoot(comparisonRoot);
            testCase.applyFixture(PathFixture(sourceRoot));
            testCase.applyFixture(PathFixture(comparisonRoot));
        end
    end

    methods (Test)
        function testCompleteCommonLedger(testCase)
            source = localFinalSource();
            testCase.verifyEqual(height(source.records),7632);
            testCase.verifyEqual( ...
                groupcounts(string(source.records.method)), ...
                [2544;2544;2544]);
            huang = localLedger(source.records,'Huang-PREC-CP');
            senlora = localLedger(source.records,'Stage55-VP-quality');
            paper = localLedger(source.records,'Paper-Midamble-Point');
            testCase.verifyEqual(senlora,huang);
            testCase.verifyEqual(paper,huang);
        end

        function testExplicitPilotIsolation(testCase)
            source = localFinalSource();
            paper = source.records(strcmp(source.records.method, ...
                'Paper-Midamble-Point'),:);
            other = source.records(~strcmp(source.records.method, ...
                'Paper-Midamble-Point'),:);
            testCase.verifyEqual(unique( ...
                paper.explicitMidambleAcceptedCount),2);
            testCase.verifyEqual(unique( ...
                other.explicitMidambleAcceptedCount),0);
        end

        function testHighRateMetricsAreComplete(testCase)
            source = localFinalSource();
            rows = source.summary(strcmp(source.summary.region, ...
                'high_doppler_rate'),:);
            ordered = localMethodMatrix(rows);
            metrics = [ordered.senloraSer ordered.paperSer ...
                ordered.huangSer ordered.senloraBer ...
                ordered.paperBer ordered.huangBer];
            testCase.verifyTrue(all(isfinite(metrics),'all'));
            testCase.verifyGreaterThanOrEqual( ...
                metrics,zeros(size(metrics)));
            testCase.verifyLessThanOrEqual(metrics,ones(size(metrics)));
        end

        function testFrozenBaselineContinuity(testCase)
            differences = localBaselineDifferences();
            testCase.verifyLessThan( ...
                differences.senloraMaxSer,1e-3);
            testCase.verifyLessThan( ...
                differences.senloraMaxBer,1e-4);
            testCase.verifyLessThan( ...
                differences.huangMaxSer,3e-3);
            testCase.verifyLessThan( ...
                differences.huangMaxBer,2e-3);
        end

        function testOnlyTwoPrimaryFigures(testCase)
            source = localFinalSource();
            testCase.verifyEqual(height(source.figureManifest),2);
            testCase.verifyTrue(all(isfile(string( ...
                source.figureManifest.pngFile))));
        end
    end
end

function source = localFinalSource()
comparisonRoot = fileparts(fileparts(mfilename('fullpath')));
reportFile = fullfile(comparisonRoot,'results','final', ...
    'sf11_stage55_three_method_report.mat');
replayFile = fullfile(comparisonRoot,'results', ...
    'stage55_sf11_midamble_three_method_replay', ...
    'fuxian_three_method_replay.mat');
source = load(reportFile);
replay = load(replayFile,'records');
source.records = replay.records;
end

function ledger = localLedger(records,method)
variables = {'snrDb','passIndex','segmentIndex','frameIndex', ...
    'payloadSeed','noiseSeed'};
ledger = sortrows(records(strcmp(records.method,method),variables), ...
    {'snrDb','passIndex','segmentIndex','frameIndex'});
end

function result = localMethodMatrix(rows)
snrGrid = unique(rows.snrDb);
result.senloraSer = zeros(numel(snrGrid),1);
result.paperSer = zeros(numel(snrGrid),1);
result.huangSer = zeros(numel(snrGrid),1);
result.senloraBer = zeros(numel(snrGrid),1);
result.paperBer = zeros(numel(snrGrid),1);
result.huangBer = zeros(numel(snrGrid),1);
for index = 1:numel(snrGrid)
    selected = rows.snrDb == snrGrid(index);
    group = rows(selected,:);
    result.senloraSer(index) = group.ser(strcmp( ...
        group.method,'Stage55-VP-quality'));
    result.paperSer(index) = group.ser(strcmp( ...
        group.method,'Paper-Midamble-Point'));
    result.huangSer(index) = group.ser(strcmp( ...
        group.method,'Huang-PREC-CP'));
    result.senloraBer(index) = group.deliveredBer(strcmp( ...
        group.method,'Stage55-VP-quality'));
    result.paperBer(index) = group.deliveredBer(strcmp( ...
        group.method,'Paper-Midamble-Point'));
    result.huangBer(index) = group.deliveredBer(strcmp( ...
        group.method,'Huang-PREC-CP'));
end
end

function differences = localBaselineDifferences()
comparisonRoot = fileparts(fileparts(mfilename('fullpath')));
sourceRoot = fuxianSourceRoot(comparisonRoot);
old = load(fullfile(sourceRoot,'results', ...
    'stage55_huang_prec_cp_fair_comparison_20260812', ...
    'stage55_fresh_three_method_overall_report.mat'),'summary');
new = load(fullfile(comparisonRoot,'results','final', ...
    'sf11_stage55_three_method_report.mat'),'summary');
senlora = localDifference(old.summary,new.summary, ...
    'Stage55-VP-quality');
huang = localDifference(old.summary,new.summary,'Huang-PREC-CP');
differences.senloraMaxSer = max(abs(senlora.oldSer-senlora.newSer));
differences.senloraMaxBer = max(abs(senlora.oldBer-senlora.newBer));
differences.huangMaxSer = max(abs(huang.oldSer-huang.newSer));
differences.huangMaxBer = max(abs(huang.oldBer-huang.newBer));
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
