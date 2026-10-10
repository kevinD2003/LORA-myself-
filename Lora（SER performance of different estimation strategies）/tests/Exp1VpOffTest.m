classdef Exp1VpOffTest < matlab.unittest.TestCase
    methods(Test)
        function vpOffCutsPayloadUpdatesOnly(testCase)
            exp1SetupPaths();
            config = exp1Config();
            ledger = exp1SeedPlan(config,'legacy',numel(config.orbitStartSec), ...
                -21,1,'legacy');
            frame = exp1GenerateFrame(config,0,-21,ledger);
            parameters = v4LoadMethodAlignedR3ParametersV1();
            common = v4CommonBootstrap(frame.observation.rxPhysical(1:8,:), ...
                config.parent,SearchStepBins=parameters.searchStepBins);
            full = exp1Stage55Decode(frame.observation,common,config,true);
            off = exp1Stage55Decode(frame.observation,common,config,false);
            testCase.verifyFalse(off.payloadVpEnabled);
            testCase.verifyTrue(full.payloadVpEnabled);
            testCase.verifyFalse(any(off.virtualPilotAccepted));
            testCase.verifyFalse(off.usesPayloadTruth);
            testCase.verifyFalse(off.usesOrbitTruth);
            testCase.verifyEqual(off.jointPreambleEstimate.rateBinsPerSec, ...
                full.jointPreambleEstimate.rateBinsPerSec,'AbsTol',1e-12);
            testCase.verifyEqual(off.initialRateBinsPerSec, ...
                full.initialRateBinsPerSec,'AbsTol',1e-12);
        end
    end
end

