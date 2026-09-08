classdef stage55FairHuangPrecComparisonTest < matlab.unittest.TestCase
    %STAGE55FAIRHUANGPRECCOMPARISONTEST Frozen fair-comparison gates.

    methods (Test, TestTags = {'Integration','ResultGate'})
        function testSharedFrameLedger(testCase)
            [stage55,huang] = localFreshSources();
            actual = localHuangLedger(huang.records);
            expected = localExpectedLedger(stage55);

            testCase.verifyEqual(huang.config,stage55.config);
            testCase.verifyEqual(huang.schedule,stage55.schedule);
            testCase.verifyEqual(huang.segments,stage55.segments);
            testCase.verifyEqual(huang.options.SnrGridDb, ...
                stage55.options.SnrGridDb);
            testCase.verifyEqual(huang.options.PassCount, ...
                stage55.options.PassCount);
            testCase.verifyEqual(actual,expected);
        end

        function testSenLoRaMetricsAreUnchanged(testCase)
            [oldMetrics,newMetrics] = localStage55Metrics();

            testCase.verifyEqual(newMetrics,oldMetrics,AbsTol=0);
        end

        function testFrozenComparisonIsCompleteAndTraceable(testCase)
            [huang,senlora] = localFairSummaryRows();

            groupVariables = {'snrDb','region'};
            testCase.verifyEqual(height(huang),4);
            testCase.verifyEqual( ...
                senlora(:,groupVariables),huang(:,groupVariables));
            testCase.verifyEqual(senlora.frameCount,huang.frameCount);
            testCase.verifyEqual(senlora.symbolCount,huang.symbolCount);
            testCase.verifyEqual(senlora.bitCount,huang.bitCount);
            testCase.verifyEqual( ...
                senlora.independentPassCount,huang.independentPassCount);
            testCase.verifyTrue(all(strcmp( ...
                huang.method,'Huang-PREC-CP')));
            testCase.verifyTrue(all(strcmp( ...
                senlora.method,'Stage55-VP-quality')));

            probabilities = [huang.ser huang.hardBer ...
                huang.deliveredBer;senlora.ser senlora.hardBer ...
                senlora.deliveredBer];
            testCase.verifyTrue(all(isfinite(probabilities),'all'));
            testCase.verifyGreaterThanOrEqual( ...
                probabilities,zeros(size(probabilities)));
            testCase.verifyLessThanOrEqual( ...
                probabilities,ones(size(probabilities)));

            cfoRmseBins = [huang.cfoRmseBins;senlora.cfoRmseBins];
            testCase.verifyTrue(all(isfinite(cfoRmseBins)));
            testCase.verifyGreaterThanOrEqual( ...
                cfoRmseBins,zeros(size(cfoRmseBins)));
        end
    end
end

function [stage55,huang] = localFreshSources()
root = fileparts(mfilename('fullpath'));
folder = fullfile(root,'results', ...
    'stage55_vp_quality_fresh_rerun_20260812');
stage55 = load(fullfile(folder,'stage55_vp_mechanism_ablation.mat'));
huang = load(fullfile(folder,'stage55_fresh_huang_prec_cp_records.mat'));
end

function ledger = localHuangLedger(records)
ledger = sortrows(records(:,{'snrDb','passIndex','segmentIndex', ...
    'frameIndex','payloadSeed','noiseSeed'}), ...
    {'snrDb','passIndex','segmentIndex','frameIndex'});
end

function ledger = localExpectedLedger(stage55)
records = stage55.records(strcmp(stage55.records.mode,'NoVP'),:);
[found,snrIndex] = ismember(records.snrDb,stage55.options.SnrGridDb);
assert(all(found),'Stage55 ledger contains an unexpected SNR.');
payloadSeed = stage55.options.PayloadSeedBase+1000000*snrIndex+ ...
    10000*records.passIndex+records.frameIndex;
noiseSeed = stage55.options.NoiseSeedBase+1000000*snrIndex+ ...
    10000*records.passIndex+records.frameIndex;
ledger = table(records.snrDb,records.passIndex,records.segmentIndex, ...
    records.frameIndex,payloadSeed,noiseSeed, ...
    'VariableNames',{'snrDb','passIndex','segmentIndex','frameIndex', ...
    'payloadSeed','noiseSeed'});
ledger = sortrows(ledger, ...
    {'snrDb','passIndex','segmentIndex','frameIndex'});
end

function [oldMetrics,newMetrics] = localStage55Metrics()
root = fileparts(mfilename('fullpath'));
fileName = 'stage55_fresh_three_method_overall_report.mat';
old = load(fullfile(root,'results', ...
    'stage55_vp_quality_fresh_overall_report_20260812',fileName),'summary');
new = load(fullfile(root,'results', ...
    'stage55_huang_prec_cp_fair_comparison_20260812',fileName),'summary');
oldMetrics = localMetricMatrix(old.summary);
newMetrics = localMetricMatrix(new.summary);
end

function values = localMetricMatrix(summary)
selected = strcmp(summary.method,'Stage55-NoVP') | ...
    strcmp(summary.method,'Stage55-VP-quality');
rows = sortrows(summary(selected,:),{'method','snrDb','region'});
names = {'ser','hardBer','deliveredBer','deliveredPer','cfoRmseBins', ...
    'meanAcceptedVirtualPilots','falseAcceptedVirtualPilots', ...
    'packetGoodputBps'};
values = rows{:,names};
end

function [huang,senlora] = localFairSummaryRows()
root = fileparts(mfilename('fullpath'));
data = load(fullfile(root,'results', ...
    'stage55_huang_prec_cp_fair_comparison_20260812', ...
    'stage55_fresh_three_method_overall_report.mat'),'summary');
huang = sortrows(data.summary(strcmp( ...
    data.summary.method,'Huang-PREC-CP'),:),{'snrDb','region'});
senlora = sortrows(data.summary(strcmp( ...
    data.summary.method,'Stage55-VP-quality'),:),{'snrDb','region'});
end
