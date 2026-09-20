classdef V4IdealReferenceV1Test < matlab.unittest.TestCase
    methods (Test)
        function referenceMatchesFrozenCurrentConditions(testCase)
            root=v4SetupPaths();r=v4IdealSerReference(root);
            testCase.verifyEqual(r.snrDb,(-30:-21).');
            testCase.verifyEqual(r.ser(end),0.000100089634497226, ...
                'RelTol',1e-12);
            testCase.verifyTrue(r.commonAcrossCases);
            testCase.verifyTrue(r.readOnly);
        end

        function currentCaseOneCrossingIsSamplingFluctuation(testCase)
            r=v4IdealBoundTest(2,22400,0.000100089634497226);
            testCase.verifyEqual(r.status,'PASS_MONTE_CARLO_FLUCTUATION');
            testCase.verifyTrue(r.pass);
            testCase.verifyGreaterThan(r.oneSidedUpper95,r.idealSer);
        end

        function significantBelowIdealFails(testCase)
            r=v4IdealBoundTest(0,10000000,0.000100089634497226);
            testCase.verifyEqual(r.status,'FAIL_BELOW_IDEAL');
            testCase.verifyFalse(r.pass);
        end

        function ordinaryReceiverAboveIdealPasses(testCase)
            r=v4IdealBoundTest(100,10000,0.001);
            testCase.verifyEqual(r.status,'PASS_ABOVE_IDEAL');
            testCase.verifyTrue(r.pass);
        end
    end
end
