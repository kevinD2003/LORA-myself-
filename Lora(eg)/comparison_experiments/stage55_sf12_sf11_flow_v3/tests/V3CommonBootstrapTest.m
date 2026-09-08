classdef V3CommonBootstrapTest < matlab.unittest.TestCase
    properties
        Config
        RxPilots
        ExpectedCenterCfo
        ExpectedStartPhase
        ExpectedRate
    end
    methods (TestMethodSetup)
        function makePilots(testCase)
            c = sf12Sf11FlowConfig();
            m = c.samplesPerSymbol;
            pilotCount = c.bootstrapPilotCount;
            cfoAtTimeZero = 0.35;
            rateBinsPerSec = 0.08;
            phaseAtTimeZero = 0.4;
            globalSample = (0:pilotCount*m-1).';
            symbolTime = globalSample/m;
            rateBinsPerSymbol = rateBinsPerSec*c.symbolDurationSec;
            phaseCycles = phaseAtTimeZero/(2*pi)+cfoAtTimeZero*symbolTime+ ...
                0.5*rateBinsPerSymbol*symbolTime.^2;
            carrier = exp(1i*2*pi*phaseCycles);
            upchirp = v3ModulateSymbol(0,c);
            tx = repmat(upchirp,pilotCount,1);
            testCase.Config = c;
            testCase.RxPilots = tx.*reshape(carrier,m,pilotCount).';
            centers = (0:pilotCount-1).'+0.5;
            testCase.ExpectedCenterCfo = cfoAtTimeZero+rateBinsPerSymbol*centers;
            starts = (0:pilotCount-1).';
            testCase.ExpectedStartPhase = angle(exp(1i*2*pi*( ...
                phaseAtTimeZero/(2*pi)+cfoAtTimeZero*starts+ ...
                0.5*rateBinsPerSymbol*starts.^2)));
            testCase.ExpectedRate = rateBinsPerSec;
        end
    end
    methods (Test)
        function noiselessCfoPhaseRateAreRecovered(testCase)
            b = v3CommonBootstrap(testCase.RxPilots,testCase.Config, ...
                SearchStepBins=0.05);
            testCase.verifyEqual(b.cfoBins,testCase.ExpectedCenterCfo, ...
                'AbsTol',5e-5);
            phaseError = angle(exp(1i*(b.phaseRad-testCase.ExpectedStartPhase)));
            % A linearly changing tone's finite-symbol coherent mean has a
            % small deterministic phase bias relative to the instantaneous
            % symbol-start phase.  Keep the tolerance below 5e-4 rad.
            testCase.verifyEqual(phaseError,zeros(8,1),'AbsTol',2e-3);
            testCase.verifyEqual(b.rateBinsPerSec,testCase.ExpectedRate, ...
                'AbsTol',2e-4);
            testCase.verifyLessThan(abs(b.rateBinsPerSec-b.jointRateBinsPerSec), ...
                2e-4);
        end
        function threeMethodsReceiveIdenticalBootstrap(testCase)
            states = v3InitializeReceiverStates(testCase.RxPilots,testCase.Config, ...
                SearchStepBins=0.05);
            testCase.verifyEqual({states.methodName}.',testCase.Config.methodNames);
            for method = 2:3
                testCase.verifyEqual(states(method).bootstrap.cfoBins, ...
                    states(1).bootstrap.cfoBins);
                testCase.verifyEqual(states(method).bootstrap.phaseRad, ...
                    states(1).bootstrap.phaseRad);
                testCase.verifyEqual(states(method).bootstrap.rateBinsPerSec, ...
                    states(1).bootstrap.rateBinsPerSec);
            end
        end
        function bootstrapDeclaresNoTruthUse(testCase)
            b = v3CommonBootstrap(testCase.RxPilots,testCase.Config);
            testCase.verifyFalse(b.usesPayloadTruth);
            testCase.verifyFalse(b.usesOrbitTruth);
            testCase.verifyEqual(b.source, ...
                'common 8-upchirp receiver-visible bootstrap');
        end
        function rejectsNonEightPilotInput(testCase)
            short = testCase.RxPilots(1:7,:);
            testCase.verifyError(@()v3CommonBootstrap(short,testCase.Config), ...
                'V3:BootstrapShape');
        end
    end
end
