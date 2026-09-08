classdef fuxianFactorialTest < matlab.unittest.TestCase
    methods (Test)
        function testFourFactorialBranchesShareLedger(testCase)
            source = localSource();
            methods = unique(source.records.method,'stable');
            testCase.verifyEqual(methods,source.methods);
            ledgers = cell(numel(methods),1);
            for index = 1:numel(methods)
                selected = source.records.method == methods(index);
                ledgers{index} = source.records(selected, ...
                    {'snrDb','passIndex','segmentIndex','frameIndex', ...
                    'payloadSeed','noiseSeed'});
            end
            testCase.verifyEqual(ledgers{1},ledgers{2});
            testCase.verifyEqual(ledgers{1},ledgers{3});
            testCase.verifyEqual(ledgers{1},ledgers{4});
        end

        function testFactorsAreOrthogonal(testCase)
            source = localSource();
            records = source.records;
            isolated = contains(records.method,"isolated");
            crossframe = contains(records.method,"crossframe");
            midamble = startsWith(records.method,"Midamble");
            vp = startsWith(records.method,"VP");
            testCase.verifyFalse(any(records.usesCrossFrameState(isolated)));
            testCase.verifyTrue(all(records.usesCrossFrameState(crossframe)));
            testCase.verifyTrue(all(records.usesExplicitMidambles(midamble)));
            testCase.verifyFalse(any(records.usesExplicitMidambles(vp)));
        end

        function testRateMatchedEquationTwentyConfiguration(testCase)
            source = localSource();
            experiment = source.experiment;
            testCase.verifyEqual(experiment.midambleSpacing,81);
            testCase.verifyEqual(experiment.trackingMidambleCount,1);
            testCase.verifyEqual(experiment.toaMidambleCount,2);
            testCase.verifyTrue(experiment.includeTerminalMidamble);
            testCase.verifyEqual(experiment.physicalConfig.frameSymbolCount,122);
        end

        function testSmokeMetricsComeFromRawCounts(testCase)
            source = localSource();
            records = source.records;
            ser = records.symbolErrors./records.symbolCount;
            ber = records.deliveredBitErrors./records.bitCount;
            testCase.verifyGreaterThanOrEqual(ser,0);
            testCase.verifyLessThanOrEqual(ser,1);
            testCase.verifyGreaterThanOrEqual(ber,0);
            testCase.verifyLessThanOrEqual(ber,1);
        end
    end
end

function source = localSource()
comparisonRoot = fileparts(fileparts(mfilename('fullpath')));
source = load(fullfile(comparisonRoot,'results', ...
    'pilot_source_crossframe_factorial_smoke','factorial_result.mat'));
end
