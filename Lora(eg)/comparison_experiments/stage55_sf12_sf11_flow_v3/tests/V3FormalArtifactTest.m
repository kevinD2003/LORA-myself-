classdef V3FormalArtifactTest < matlab.unittest.TestCase
    methods (Test)
        function formalGridAndStoppingPolicyHold(testCase)
            config = sf12Sf11FlowConfig();
            loaded = load(fullfile(config.projectRoot,'results','formal', ...
                'v3_formal_comparison_v2.mat'),'formal');
            formal = loaded.formal;
            testCase.verifyEqual(formal.preregistered.snrDb,-30:-21);
            testCase.verifyEqual(numel(formal.points),10);
            for index = 1:10
                point = formal.points{index};
                testCase.verifyGreaterThanOrEqual(point.completedPasses,5);
                testCase.verifyLessThanOrEqual(point.completedPasses,20);
                testCase.verifyNotEqual(point.stoppingReason,'incomplete');
                testCase.verifyEqual(height(point.records), ...
                    point.completedPasses*81*3);
                testCase.verifyEqual(unique(point.records.snrDbColumn),-31+index);
                testCase.verifyEqual(numel(point.passDiagnostics),point.completedPasses);
                for pass = 1:point.completedPasses
                    testCase.verifySize( ...
                        point.passDiagnostics(pass).symbolCfoSquaredErrorSum,[3 2 112]);
                    testCase.verifySize( ...
                        point.passDiagnostics(pass).symbolCfoObservationCount,[3 2]);
                end
            end
        end
        function everyFormalFrameIsPairedAndRawCounted(testCase)
            config = sf12Sf11FlowConfig();
            loaded = load(fullfile(config.projectRoot,'results','formal', ...
                'v3_formal_comparison_v2.mat'),'formal');
            for pointIndex = 1:10
                records = loaded.formal.points{pointIndex}.records;
                keys = unique(records(:,{'passIndexColumn','frameIndexColumn'}),'rows');
                for keyIndex = 1:height(keys)
                    rows = records.passIndexColumn == keys.passIndexColumn(keyIndex) & ...
                        records.frameIndexColumn == keys.frameIndexColumn(keyIndex);
                    testCase.verifyEqual(sum(rows),3);
                    testCase.verifyEqual(numel(unique(records.payloadSeed(rows))),1);
                    testCase.verifyEqual(numel(unique(records.noiseSeed(rows))),1);
                    testCase.verifyEqual(numel(unique(records.channelSeed(rows))),1);
                    testCase.verifyEqual(numel(unique(records.fingerprintEnergy(rows))),1);
                end
                testCase.verifyTrue(all(records.symbolErrors <= records.symbolCount));
                testCase.verifyTrue(all(records.hardBitErrors <= records.hardBitCount));
                testCase.verifyTrue(all(records.softBitErrors <= records.softBitCount));
            end
        end
    end
end
