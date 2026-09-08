classdef V4ContinuousFrameTest < matlab.unittest.TestCase
    methods (Test)
        function scheduleUsesSf12FrameAndSkipsBlindMetrics(testCase)
            c = sf12NoLdroSf11FlowConfig();
            schedule = v4ContinuousPassSchedule(c);
            testCase.verifyEqual(schedule.noMidambleFrameDurationSec,3.93216, ...
                'AbsTol',1e-12);
            testCase.verifyEqual(schedule.frameDurationSec, ...
                c.commonTimelineSymbolCount*c.symbolDurationSec,'AbsTol',1e-12);
            testCase.verifyTrue(any(schedule.fullyBlind));
            testCase.verifyFalse(any(schedule.metricEligible & schedule.fullyBlind));
        end
        function phaseBridgesAcrossFramesModuloTwoPi(testCase)
            c = sf12NoLdroSf11FlowConfig();
            ledger1 = v4RandomLedger(c,'validation',1,1,1);
            ledger2 = v4RandomLedger(c,'validation',1,1,2);
            frame1 = v4GenerateContinuousFrame(c,-100,Inf,ledger1,0.7);
            frame2 = v4GenerateContinuousFrame(c,frame1.nextFrameStartTimeSec, ...
                Inf,ledger2,frame1.nextFrameStartPhaseRad);
            errorRad = angle(exp(1i*(frame2.truth.firstSamplePhaseRad- ...
                frame1.nextFrameStartPhaseRad)));
            testCase.verifyEqual(errorRad,0,'AbsTol',10*eps);
            testCase.verifyGreaterThanOrEqual(frame1.nextFrameStartPhaseRad,-pi);
            testCase.verifyLessThanOrEqual(frame1.nextFrameStartPhaseRad,pi);
        end
        function ricianPowerIsUnitMean(testCase)
            c = sf12NoLdroSf11FlowConfig();
            coefficients = v4RicianCoefficient(c,c.seeds.mechanismChannelBase+1,50000);
            testCase.verifyEqual(mean(abs(coefficients).^2),1,'AbsTol',0.015);
        end
        function interruptedResumeMatchesContinuousRun(testCase)
            c = sf12NoLdroSf11FlowConfig();
            p = localStage4Parameters();
            initial = struct('nextFrameIndex',1,'nextFrameStartTimeSec',-100, ...
                'nextFrameStartPhaseRad',0.7,'crossFrameRateState',struct());
            [allState,allRecords] = v4AdvanceFrameSequence(initial,2,c,Inf, ...
                'validation',1,1,p);
            [firstState,firstRecord] = v4AdvanceFrameSequence(initial,1,c,Inf, ...
                'validation',1,1,p);
            folder = tempname;
            mkdir(folder);
            cleanup = onCleanup(@()rmdir(folder,'s'));
            checkpoint = fullfile(folder,'checkpoint.mat');
            signature = 'stage4-resume-test';
            v4WriteCheckpointAtomic(checkpoint,firstState,signature);
            resumed = v4LoadCheckpoint(checkpoint,signature);
            [resumedState,secondRecord] = v4AdvanceFrameSequence(resumed,1,c,Inf, ...
                'validation',1,1,p);
            joined = [firstRecord;secondRecord];
            testCase.verifyEqual(joined,allRecords);
            testCase.verifyEqual(resumedState,allState);
            testCase.verifyError(@()v4LoadCheckpoint(checkpoint,'wrong-signature'), ...
                'V4:CheckpointSignature');
            clear cleanup
        end
        function seedDomainsDoNotIntersect(testCase)
            c = sf12NoLdroSf11FlowConfig();
            values = zeros(10*20*3,3);
            row = 0;
            for snr = 1:10
                for pass = 1:20
                    for frame = [1 2000 4000]
                        row = row+1;
                        ledger = v4RandomLedger(c,'formal',snr,pass,frame);
                        values(row,:) = [ledger.payloadSeed ledger.noiseSeed ledger.channelSeed];
                    end
                end
            end
            testCase.verifyEqual(numel(unique(values(:))),numel(values));
        end
        function crossFrameRateFeedsOnlyStage55(testCase)
            c = sf12NoLdroSf11FlowConfig();
            p = localStage4Parameters();
            ledger = v4RandomLedger(c,'validation',1,3,1);
            frame = v4GenerateContinuousFrame(c,-100,Inf,ledger,0.7);
            bootstrap = v4CommonBootstrap(frame.observation.rxPhysical(1:8,:),c, ...
                SearchStepBins=p.searchStepBins);
            suppliedRate = bootstrap.rateBinsPerSec+0.01;
            receivers = v4DecodeThreeMethods(frame.observation,c,p, ...
                Bootstrap=bootstrap,CrossFrameRateBinsPerSec=suppliedRate, ...
                CrossFrameHistoryCount=2);
            testCase.verifyTrue(receivers{2}.usesCrossFrameState);
            testCase.verifyEqual(receivers{2}.initialRateBinsPerSec,suppliedRate);
            testCase.verifyFalse(receivers{1}.usesDopplerRate);
            testCase.verifyFalse(receivers{3}.usesPayloadFeedback);
        end
    end
end

function parameters = localStage4Parameters()
parameters = struct('searchStepBins',0.05, ...
    'residualSearchBins',(-0.5:0.05:0.5).', ...
    'historyDecay',0.85,'huberThresholdBins',0.15, ...
    'residualPeakRatioThreshold',1.01,'decisionPeakRatioThreshold',1.01, ...
    'innovationLimitBins',0.49,'singleSymbolInnovationGain',0.35, ...
    'phasePairInnovationGain',0.60,'phasePairInnovationLimitBins',0.10, ...
    'phasePairAgreementLimitBins',0.15,'virtualPilotCfoStdBins',0.075, ...
    'virtualPilotRateStdLimitBinsPerSec',0.10, ...
    'rateDeviationLimitBinsPerSec',0.10,'maximumRateBinsPerSec',2.0, ...
    'confidenceAlpha',0.8,'confidenceThresholdScale',1.0, ...
    'softHammingMarginRatio',0);
parameters.requireSoftHardAgreement = true;
parameters.minimumCrossFrameHistoryForVirtualPilots = 2;
end
