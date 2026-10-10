classdef Exp1PhysicsTest < matlab.unittest.TestCase
    methods(Test)
        function orbitMatchesFrozenParent(testCase)
            exp1SetupPaths();
            config = exp1Config();
            time = [-366 -183 0 5.144576];
            expected = v4TrackAOrbit(time,config.parent);
            actual = exp1TrackAOrbit(time,config.parent);
            testCase.verifyEqual(actual.dopplerHz,expected.dopplerHz, ...
                'AbsTol',1e-10);
            testCase.verifyEqual(actual.rangeM,expected.rangeM,'AbsTol',1e-6);
        end

        function generatedFrameMatchesParent(testCase)
            exp1SetupPaths();
            config = exp1Config();
            ledger = exp1SeedPlan(config,'legacy',1,-21,1,'legacy');
            expected = v4GenerateBCaseAnchorFrame(config.parent,-366,-21,ledger);
            actual = exp1GenerateFrame(config,-366,-21,ledger);
            testCase.verifyEqual(actual.observation.rxPhysical, ...
                expected.observation.rxPhysical,'AbsTol',1e-12);
            testCase.verifyEqual(actual.truth.payloadPhysicalBins, ...
                expected.truth.payloadPhysicalBins);
            testCase.verifyEqual(actual.truth.dataCfoBins, ...
                expected.truth.dataCfoBins,'AbsTol',1e-12);
            testCase.verifyEqual(actual.truth.lastSampleTimeSec, ...
                -366+config.lastSampleOffsetSec,'AbsTol',1e-12);
            testCase.verifyEqual(actual.truth.rightBoundaryTimeSec, ...
                -366+config.frameDurationSec,'AbsTol',1e-12);
        end
    end
end

