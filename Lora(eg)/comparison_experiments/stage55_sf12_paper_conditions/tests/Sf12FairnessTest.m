classdef Sf12FairnessTest < matlab.unittest.TestCase
    methods (TestMethodSetup)
        function setup(testCase)
            root = fileparts(fileparts(mfilename('fullpath')));
            addpath(fullfile(root,'config'),fullfile(root,'src'));
            testCase.addTeardown(@()rmpath(fullfile(root,'config'), ...
                fullfile(root,'src')));
        end
    end
    methods (Test)
        function sharedBootstrapAndPilotIsolation(testCase)
            cfg = sf12PaperCommonConfig();
            cfg.orbit.disableDoppler = true;
            cfg.channel.disableNoise = true;
            result = sf12PairedFrameSimulation( ...
                cfg,"case1",0,1,"validation",1);
            testCase.verifyEqual(result.paperInitialCfoHz, ...
                result.stage55InitialCfoHz);
            testCase.verifyEqual(result.paperInitialPhaseRad, ...
                result.stage55InitialPhaseRad);
            testCase.verifyEqual(result.paperSymbolErrors,0);
            testCase.verifyEqual(result.stage55SymbolErrors,0);
            testCase.verifyEqual(result.paperEffectiveMidambles,7);
            testCase.verifyEqual(result.stage55ExplicitMidambleAccepted,0);
            testCase.verifyEqual(result.paperVirtualPilotAccepted,0);
        end
        function pairedPacketIsDeterministic(testCase)
            cfg = sf12PaperCommonConfig();
            first = sf12PairedFrameSimulation( ...
                cfg,"case2",-21,2,"validation",1);
            second = sf12PairedFrameSimulation( ...
                cfg,"case2",-21,2,"validation",1);
            testCase.verifyEqual(first.payloadSeed,second.payloadSeed);
            testCase.verifyEqual(first.noiseSeed,second.noiseSeed);
            testCase.verifyEqual(first.commonSampleFingerprint, ...
                second.commonSampleFingerprint,'AbsTol',1e-10);
            testCase.verifyEqual(first.paperInputFingerprint, ...
                first.stage55InputFingerprint,'AbsTol',0);
        end
        function virtualPilotsAreStrictlyCausal(testCase)
            cfg = sf12PaperCommonConfig();
            result = sf12PairedFrameSimulation( ...
                cfg,"case1",-21,3,"validation",1);
            accepted = find(result.stage55AcceptedMask);
            effective = result.stage55FirstEffectiveDataIndex(accepted);
            testCase.verifyTrue(all(isnan(effective) | effective > accepted));
        end
    end
end
