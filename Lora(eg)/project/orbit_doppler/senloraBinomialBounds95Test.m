classdef senloraBinomialBounds95Test < matlab.unittest.TestCase
    %SENLORABINOMIALBOUNDS95TEST Tests for exact binomial confidence bounds.

    methods (Test)
        function zeroErrorUsesTwoSidedUpperBound(testCase)
            [lower95,upper95] = senloraBinomialBounds95(0,100);

            testCase.verifyEqual(lower95,0);
            testCase.verifyEqual(upper95,1-0.025^(1/100), ...
                "AbsTol",1e-14);
        end

        function allErrorsUseTwoSidedLowerBound(testCase)
            [lower95,upper95] = senloraBinomialBounds95(100,100);

            testCase.verifyEqual(lower95,0.025^(1/100), ...
                "AbsTol",1e-14);
            testCase.verifyEqual(upper95,1);
        end

        function interiorBoundsMatchClopperPearson(testCase)
            [lower95,upper95] = senloraBinomialBounds95(12,100);

            testCase.verifyEqual(lower95,betainv(0.025,12,89), ...
                "AbsTol",1e-14);
            testCase.verifyEqual(upper95,betainv(0.975,13,88), ...
                "AbsTol",1e-14);
        end

        function emptySampleReturnsNaN(testCase)
            [lower95,upper95] = senloraBinomialBounds95(0,0);

            testCase.verifyTrue(isnan(lower95));
            testCase.verifyTrue(isnan(upper95));
        end

        function errorCountCannotExceedTotal(testCase)
            testCase.verifyError( ...
                @()senloraBinomialBounds95(2,1), ...
                "SenLoRa:InvalidBinomialCounts");
        end
    end
end
