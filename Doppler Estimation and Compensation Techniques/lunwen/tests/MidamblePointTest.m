classdef MidamblePointTest < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addProjectPaths(testCase)
            import matlab.unittest.fixtures.PathFixture
            projectRoot = fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(PathFixture(fullfile(projectRoot, 'src')));
            testCase.applyFixture(PathFixture(fullfile(projectRoot, 'config')));
        end
    end

    methods (Test)
        function testEquation17ResidualUpdate(testCase)
            current = [100, -200];
            residual = [30, -40];
            updated = updateMidamblePointEstimate(current, residual);
            testCase.verifyEqual(updated, [130, -240]);
        end

        function testUncertaintyFusionGain(testCase)
            updated = updateMidamblePointEstimate(100, 40, 0.35);
            testCase.verifyEqual(updated, 114, 'AbsTol', 1e-12);
        end

        function testCase2PiecewiseConstantUpdates(testCase)
            cfg = paperSf12Config();
            trace = buildTrackingTrace(cfg, "case2");
            changedDataIndices = find(diff( ...
                trace.midamblePointEstimateHz) ~= 0) + 1;
            testCase.verifyEqual(changedDataIndices, ...
                [4 7 10 13 16 19 22]);
            testCase.verifyEqual(numel(unique( ...
                trace.pointEstimateHz)), 1);
        end
    end
end
