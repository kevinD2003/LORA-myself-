classdef Sf12TrackingRegressionTest < matlab.unittest.TestCase
    methods (TestMethodSetup)
        function setup(testCase)
            root = fileparts(fileparts(mfilename('fullpath')));
            addpath(fullfile(root,'config'),fullfile(root,'src'));
            testCase.addTeardown(@()rmpath(fullfile(root,'config'), ...
                fullfile(root,'src')));
        end
    end
    methods (Test)
        function case2NoiselessTrackingRemainsCorrect(testCase)
            cfg = sf12PaperCommonConfig();
            cfg.channel.disableNoise = true;
            result = sf12PairedFrameSimulation( ...
                cfg,"case2",-21,1,"validation",1);
            testCase.verifyEqual(result.paperSymbolErrors,0);
            testCase.verifyEqual(result.stage55SymbolErrors,0);
            testCase.verifyEqual(result.stage55AcceptedVirtualPilots,23);
            testCase.verifyEqual(result.stage55FalseAcceptedVirtualPilots,0);
        end
        function case2QualityGateAvoidsBranchLock(testCase)
            cfg = sf12PaperCommonConfig();
            testCase.assertTrue(cfg.receiver.manifest.calibrationRunCompleted, ...
                'Run V2 mechanism calibration before the regression suite.');
            packets = 20;
            accepted = 0;
            falseAccepted = 0;
            for packet = 1:packets
                result = sf12PairedFrameSimulation( ...
                    cfg,"case2",-21,packet,"validation",1);
                accepted = accepted+result.stage55AcceptedVirtualPilots;
                falseAccepted = falseAccepted+ ...
                    result.stage55FalseAcceptedVirtualPilots;
            end
            acceptanceRate = accepted/(packets*cfg.frame.payloadSymbolCount);
            falseAcceptanceRate = falseAccepted/max(accepted,1);
            testCase.verifyGreaterThanOrEqual(acceptanceRate,0.5);
            testCase.verifyLessThanOrEqual(falseAcceptanceRate,0.1);
        end
    end
end
