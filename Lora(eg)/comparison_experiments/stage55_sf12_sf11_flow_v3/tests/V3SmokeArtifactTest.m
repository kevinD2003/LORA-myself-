classdef V3SmokeArtifactTest < matlab.unittest.TestCase
    methods (Test)
        function completePassArtifactIsWiringOnlyAndPaired(testCase)
            config = sf12Sf11FlowConfig();
            path = fullfile(config.projectRoot,'results','validation', ...
                'v3_complete_pass_smoke_v4.mat');
            loaded = load(path,'summary');
            summary = loaded.summary;
            schedule = v3ContinuousPassSchedule(config);
            testCase.verifyTrue(summary.wiringOnly);
            testCase.verifyEqual(summary.parameterRevision,4);
            testCase.verifyEqual(summary.frameCount,schedule.frameCount);
            testCase.verifyEqual(summary.eligibleFrameCount,sum(schedule.metricEligible));
            records = summary.frameRecords;
            testCase.verifyEqual(height(records),3*summary.eligibleFrameCount);
            frames = unique(records.frameIndexColumn);
            for index = 1:numel(frames)
                rows = records.frameIndexColumn == frames(index);
                testCase.verifyEqual(numel(unique(records.fingerprintEnergy(rows))),1);
                testCase.verifyEqual(numel(unique(records.fingerprintReal(rows))),1);
                testCase.verifyEqual(numel(unique(records.fingerprintImag(rows))),1);
            end
            testCase.verifyTrue(any(records.region == "high-dynamic"));
            testCase.verifyTrue(any(records.region == "low-dynamic"));
        end
    end
end
