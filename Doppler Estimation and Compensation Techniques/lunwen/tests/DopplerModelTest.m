classdef DopplerModelTest < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addProjectPaths(testCase)
            import matlab.unittest.fixtures.PathFixture
            projectRoot = fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(PathFixture(fullfile(projectRoot, 'src')));
            testCase.applyFixture(PathFixture(fullfile(projectRoot, 'config')));
        end
    end

    methods (Test)
        function testReferenceLandmarks(testCase)
            cfg = paperSf12Config();
            values = dopplerLandmarks(cfg);
            testCase.verifyEqual(values.visibilityHalfTimeS, ...
                366.02875203898, 'AbsTol', 1e-8);
            testCase.verifyEqual(values.fdAtMinus366Hz, ...
                20226.569967122337, 'AbsTol', 1e-6);
            testCase.verifyEqual(values.fdAtZeroHz, 0, 'AbsTol', 1e-12);
            testCase.verifyEqual(values.rateAtZeroHzS, ...
                -279.089832510045, 'AbsTol', 1e-5);
        end

        function testOddSymmetry(testCase)
            cfg = paperSf12Config();
            timeS = [1, 50, 183, 300];
            positive = circularOrbitDoppler(timeS, cfg);
            negative = circularOrbitDoppler(-timeS, cfg);
            testCase.verifyEqual(negative, -positive, 'AbsTol', 1e-9);
        end
    end
end
