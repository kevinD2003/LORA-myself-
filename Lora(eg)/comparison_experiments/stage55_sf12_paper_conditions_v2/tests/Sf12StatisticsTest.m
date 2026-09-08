classdef Sf12StatisticsTest < matlab.unittest.TestCase
    methods (TestMethodSetup)
        function setup(testCase)
            root = fileparts(fileparts(mfilename('fullpath')));
            addpath(fullfile(root,'src'));
            testCase.addTeardown(@()rmpath(fullfile(root,'src')));
        end
    end
    methods (Test)
        function wilsonContainsObservedRate(testCase)
            interval = sf12WilsonInterval(1500,5000*23);
            rate = 1500/(5000*23);
            testCase.verifyLessThanOrEqual(interval(1),rate);
            testCase.verifyGreaterThanOrEqual(interval(2),rate);
        end
        function zeroCountIsFinite(testCase)
            interval = sf12WilsonInterval(0,115000);
            testCase.verifyEqual(interval(1),0);
            testCase.verifyGreaterThan(interval(2),0);
        end
    end
end
