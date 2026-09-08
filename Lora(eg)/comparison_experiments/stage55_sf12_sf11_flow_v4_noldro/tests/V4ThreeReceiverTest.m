classdef V4ThreeReceiverTest < matlab.unittest.TestCase
    properties
        Config
        Parameters
        Observation
        Truth
    end
    methods (TestMethodSetup)
        function makeFrame(testCase)
            c = sf12NoLdroSf11FlowConfig();
            p = localWiringParameters();
            layout = v4BuildFrameLayout(c);
            payload = v4GeneratePayload(c,c.seeds.mechanismPayloadBase+3);
            cfoBins = 0.35;
            phase0 = 0.4;
            rx = complex(zeros(layout.physicalSymbolCount,c.samplesPerSymbol));
            for row = 1:layout.physicalSymbolCount
                if layout.kind(row) == "data"
                    physicalBin = payload.physicalBins(layout.dataIndex(row));
                else
                    physicalBin = 0;
                end
                waveform = v4ModulateSymbol(physicalBin,c);
                g = (row-1)*c.samplesPerSymbol+(0:c.samplesPerSymbol-1);
                channelPhase = phase0+2*pi*cfoBins*g/c.samplesPerSymbol;
                rx(row,:) = waveform.*exp(1i*channelPhase);
            end
            testCase.Config = c;
            testCase.Parameters = p;
            testCase.Observation = struct('rxPhysical',rx,'layout',layout);
            testCase.Truth = struct('payloadPhysicalBins',payload.physicalBins, ...
                'dataBits',logical(payload.dataBits), ...
                'dataCfoBins',repmat(cfoBins,c.payloadSymbolCount,1));
        end
    end
    methods (Test)
        function threeBranchesUseFixedNamesAndDecodeNoiselessly(testCase)
            receivers = v4DecodeThreeMethods(testCase.Observation, ...
                testCase.Config,testCase.Parameters);
            for method = 1:3
                testCase.verifyEqual(receivers{method}.methodName, ...
                    testCase.Config.methodNames{method});
                metrics = v4EvaluateFrame(receivers{method},testCase.Truth,testCase.Config);
                testCase.verifyEqual([metrics.ser metrics.hardBer ...
                    metrics.softBer metrics.per],[0 0 0 0]);
                testCase.verifyFalse(receivers{method}.usesPayloadTruth);
                testCase.verifyFalse(receivers{method}.usesOrbitTruth);
            end
        end
        function fairnessAndPilotBoundariesHold(testCase)
            receivers = v4DecodeThreeMethods(testCase.Observation, ...
                testCase.Config,testCase.Parameters);
            for method = 2:3
                testCase.verifyEqual(receivers{method}.bootstrap.cfoBins, ...
                    receivers{1}.bootstrap.cfoBins);
                testCase.verifyEqual(receivers{method}.bootstrap.phaseRad, ...
                    receivers{1}.bootstrap.phaseRad);
            end
            testCase.verifyFalse(any(receivers{1}.explicitMidambleAccepted));
            testCase.verifyFalse(any(receivers{2}.explicitMidambleAccepted));
            testCase.verifyFalse(any(receivers{3}.virtualPilotAccepted));
            testCase.verifyTrue(all(receivers{3}.explicitMidambleAccepted));
            testCase.verifyEqual(receivers{2}.virtualPilotLabelSource, ...
                'hard LoRa decision');
            testCase.verifyTrue(receivers{2}.usesSoftInformationOnlyForAdmission);
        end
        function stage55PilotsAreBlockCausalAndRollingEight(testCase)
            receivers = v4DecodeThreeMethods(testCase.Observation, ...
                testCase.Config,testCase.Parameters);
            stage55 = receivers{2};
            accepted = find(stage55.virtualPilotAccepted);
            if ~isempty(accepted)
                testCase.verifyGreaterThan( ...
                    stage55.pilotFirstEffectivePhysicalRow(accepted), ...
                    testCase.Observation.layout.dataRows(accepted));
                testCase.verifyGreaterThanOrEqual( ...
                    stage55.pilotFirstEffectivePhysicalRow(accepted), ...
                    stage55.pilotAvailabilityPhysicalRow(accepted));
            end
            testCase.verifyLessThanOrEqual(max(stage55.activeHistoryCount),8);
            testCase.verifyLessThanOrEqual(stage55.iterations,5);
        end
    end
end

function parameters = localWiringParameters()
parameters = struct('searchStepBins',0.05, ...
    'residualSearchBins',(-0.5:0.05:0.5).', ...
    'historyDecay',0.85,'huberThresholdBins',0.15, ...
    'residualPeakRatioThreshold',1.01,'decisionPeakRatioThreshold',1.01, ...
    'innovationLimitBins',0.49,'singleSymbolInnovationGain',0.35, ...
    'phasePairInnovationGain',0.60, ...
    'phasePairInnovationLimitBins',0.10, ...
    'phasePairAgreementLimitBins',0.15, ...
    'virtualPilotCfoStdBins',0.075, ...
    'virtualPilotRateStdLimitBinsPerSec',0.10, ...
    'rateDeviationLimitBinsPerSec',0.10, ...
    'maximumRateBinsPerSec',2.0,'confidenceAlpha',0.8, ...
    'confidenceThresholdScale',1.0,'softHammingMarginRatio',0);
parameters.requireSoftHardAgreement = true;
parameters.minimumCrossFrameHistoryForVirtualPilots = 2;
end
