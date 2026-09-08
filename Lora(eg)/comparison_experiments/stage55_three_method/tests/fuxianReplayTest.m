classdef fuxianReplayTest < matlab.unittest.TestCase
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
        function testThreeMethodsShareOneLedger(testCase)
            source = localSmokeSource();
            huang = localLedger(source.records,'Huang-PREC-CP');
            senlora = localLedger(source.records,'Stage55-VP-quality');
            paper = localLedger(source.records,'Paper-Midamble-Point');
            testCase.verifyEqual(senlora,huang);
            testCase.verifyEqual(paper,huang);
        end

        function testCommonMetricCounts(testCase)
            source = localSmokeSource();
            testCase.verifyEqual(unique(source.records.symbolCount),112);
            testCase.verifyEqual(unique(source.records.bitCount),704);
            testCase.verifyEqual(height(source.records),12);
        end

        function testPaperMidambleCountAndIsolation(testCase)
            source = localSmokeSource();
            paper = source.records(strcmp(source.records.method, ...
                'Paper-Midamble-Point'),:);
            other = source.records(~strcmp(source.records.method, ...
                'Paper-Midamble-Point'),:);
            testCase.verifyEqual( ...
                unique(paper.explicitMidambleAcceptedCount),2);
            testCase.verifyEqual( ...
                unique(other.explicitMidambleAcceptedCount),0);
        end

        function testFrozenStage55Seeds(testCase)
            source = localSmokeSource();
            testCase.verifyEqual(source.options.PayloadSeedBase,2026551800);
            testCase.verifyEqual(source.options.NoiseSeedBase,2026551900);
            testCase.verifyEqual(source.options.SnrGridDb,-21);
        end
    end
end

function source = localSmokeSource()
comparisonRoot = fileparts(fileparts(mfilename('fullpath')));
source = load(fullfile(comparisonRoot,'results','smoke', ...
    'fuxian_three_method_replay.mat'));
end

function ledger = localLedger(records,method)
variables = {'snrDb','passIndex','segmentIndex','frameIndex', ...
    'payloadSeed','noiseSeed'};
ledger = sortrows(records(strcmp(records.method,method),variables), ...
    {'snrDb','passIndex','segmentIndex','frameIndex'});
end
