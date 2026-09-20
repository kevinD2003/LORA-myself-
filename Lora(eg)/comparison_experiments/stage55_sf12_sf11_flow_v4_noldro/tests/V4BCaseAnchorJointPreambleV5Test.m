classdef V4BCaseAnchorJointPreambleV5Test < matlab.unittest.TestCase
    methods (Test)
        function noiselessJointEstimateMatchesBothPhysicalRegimes(testCase)
            expectedRate = [0 -9.145];
            for caseIndex = 1:2
                [frame,~,c,~] = localFrame(caseIndex,Inf,caseIndex);
                estimate = v4Stage55JointPreambleMlBootstrap( ...
                    frame.observation.rxPhysical(1:8,:),c);
                testCase.verifyEqual(estimate.rateBinsPerSec, ...
                    expectedRate(caseIndex),'AbsTol',0.01);
                testCase.verifyFalse(estimate.usesPayloadTruth);
                testCase.verifyFalse(estimate.usesOrbitTruth);
            end
        end

        function caseOneIsExactlyHuangEquivalent(testCase)
            [frame,common,c,p] = localFrame(1,-30,11);
            stage = v4Stage55CaseAnchorDecodeV5( ...
                frame.observation,common,c,p(2));
            huang = v4HuangStaticDecode(frame.observation,common,c);
            testCase.verifyEqual(stage.caseRegime, ...
                'observable-near-static-huang-equivalent');
            testCase.verifyTrue(stage.staticFallbackExact);
            testCase.verifyEqual(stage.detectedPhysicalBins, ...
                huang.detectedPhysicalBins);
            testCase.verifyEqual(stage.hardDecodedDataBits, ...
                huang.hardDecodedDataBits);
            testCase.verifyEqual(stage.softDecodedDataBits, ...
                huang.softDecodedDataBits);
        end

        function caseTwoIsDynamicAndNoiselessExact(testCase)
            [frame,common,c,p] = localFrame(2,Inf,12);
            stage = v4Stage55CaseAnchorDecodeV5( ...
                frame.observation,common,c,p(2));
            metrics = v4EvaluateFrame(stage,frame.truth,c);
            testCase.verifyEqual(stage.caseRegime, ...
                'observable-dynamic-joint-preamble-vp');
            testCase.verifyFalse(stage.staticFallbackExact);
            testCase.verifyEqual([metrics.symbolErrors ...
                metrics.hardBitErrors metrics.softBitErrors],[0 0 0]);
        end

        function implementationHasNoCaseOrTruthSwitch(testCase)
            root = v4SetupPaths();
            source = fileread(fullfile(root,'src','stage55', ...
                'v4Stage55CaseAnchorDecodeV5.m'));
            testCase.verifyFalse(contains(source,'caseIndex'));
            testCase.verifyFalse(contains(source,'frame.truth'));
            testCase.verifyFalse(contains(source,'observation.truth'));
            testCase.verifyTrue(contains(source, ...
                'virtualPilotRateStdLimitBinsPerSec'));
        end

        function frozenBaselinesRemainUnchanged(testCase)
            root = v4SetupPaths();
            testCase.verifyEqual(v4Sha256(fullfile(root,'src','paper', ...
                'v4PaperMidambleDecode.m')), ...
                'f2b8fee79b6920118710cb3e380f461d3e821f8c532034bb4b328594600e690f');
            testCase.verifyEqual(v4Sha256(fullfile(root,'src','stage55', ...
                'v4HuangStaticDecode.m')), ...
                '27dc3630f976428efbd999126b01d7a88129f98a42c6c53946543a7fc878cef2');
        end

        function admissionGateImplementsZeroFloorWithoutRelaxingCaseTwo(testCase)
            raw = zeros(2,10,3,4);
            raw(1,:,1,1:3) = 5;
            raw(1,:,2,1:3) = 5;
            raw(1,:,3,1:3) = 6;
            raw(1,10,1,1:3) = 0;
            raw(1,10,2,1:3) = 0;
            raw(1,10,3,1:3) = 0;
            raw(2,:,1,1:3) = 5;
            raw(2,:,2,1:3) = 4;
            raw(2,:,3,1:3) = 6;
            gate = v4BCaseAnchorAdmissionV2(raw);
            testCase.verifyTrue(gate.overallPass);
            raw(2,1,2,1) = raw(2,1,1,1);
            gate = v4BCaseAnchorAdmissionV2(raw);
            testCase.verifyFalse(gate.case2Pass);
        end

        function v6CfoRegimeGateIsStableAtLowSnr(testCase)
            for caseIndex = 1:2
                for id = 21:30
                    [frame,common,c,p] = localFrame(caseIndex,-30,id);
                    stage = v4Stage55CaseAnchorDecodeV6( ...
                        frame.observation,common,c,p(2));
                    if caseIndex == 1
                        huang = v4HuangStaticDecode( ...
                            frame.observation,common,c);
                        testCase.verifyTrue(stage.staticFallbackExact);
                        testCase.verifyEqual(stage.detectedPhysicalBins, ...
                            huang.detectedPhysicalBins);
                        testCase.verifyEqual(stage.hardDecodedDataBits, ...
                            huang.hardDecodedDataBits);
                        testCase.verifyEqual(stage.softDecodedDataBits, ...
                            huang.softDecodedDataBits);
                    else
                        testCase.verifyFalse(stage.staticFallbackExact);
                    end
                end
            end
        end

        function v6SourceUsesNoCaseOrTruthSwitch(testCase)
            root = v4SetupPaths();
            source = fileread(fullfile(root,'src','stage55', ...
                'v4Stage55CaseAnchorDecodeV6.m'));
            testCase.verifyFalse(contains(source,'caseIndex'));
            testCase.verifyFalse(contains(source,'frame.truth'));
            testCase.verifyFalse(contains(source,'observation.truth'));
            testCase.verifyTrue(contains(source,'c.samplesPerSymbol/8'));
        end
    end
end

function [frame,common,c,p] = localFrame(caseIndex,snrDb,id)
c = sf12NoLdroSf11FlowConfig();
p = v4BCalibrationCandidates();
cases = [-366 0];
key = struct('planVersion','B-case-anchor-AWGN-v5-test', ...
    'phase','mechanism','track','B-case-anchor','channel','AWGN', ...
    'comparisonMode','case-anchor-controlled','snrDb',snrDb, ...
    'replicateId',id,'packetId',id,'eventType','paired-frame', ...
    'eventIndex',caseIndex,'sampleIndex',0);
ledger = v4EventRandomLedger(588500000,key);
frame = v4GenerateBCaseAnchorFrame(c,cases(caseIndex),snrDb,ledger);
common = v4CommonBootstrap(frame.observation.rxPhysical(1:8,:),c, ...
    SearchStepBins=p(1).searchStepBins);
end
