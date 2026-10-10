classdef Exp1StatisticsTest < matlab.unittest.TestCase
    methods(Test)
        function zeroErrorUsesPacketUpperBound(testCase)
            [estimate,ci] = exp1BootstrapCI(zeros(10,1),100,1234);
            testCase.verifyEqual(estimate,0);
            testCase.verifyEqual(ci,[0 1-0.05^(1/10)],'AbsTol',1e-14);
        end

        function pairedBootstrapIsReproducible(testCase)
            baseline = [0 .1 .2 .3 .4].';
            stage = [0 0 .1 .1 .2].';
            [estimate1,ci1] = exp1PairedDifferenceCI(baseline,stage,500,42);
            [estimate2,ci2] = exp1PairedDifferenceCI(baseline,stage,500,42);
            testCase.verifyEqual(estimate1,estimate2);
            testCase.verifyEqual(ci1,ci2);
            testCase.verifyGreaterThan(estimate1,0);
        end

        function pairedAllZeroDoesNotClaimZeroWidth(testCase)
            [estimate,ci] = exp1PairedDifferenceCI(zeros(10,1), ...
                zeros(10,1),100,42);
            upper = 1-0.05^(1/10);
            testCase.verifyEqual(estimate,0);
            testCase.verifyEqual(ci,[-upper upper],'AbsTol',1e-14);
        end
    end
end
