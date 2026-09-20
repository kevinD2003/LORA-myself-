classdef V4PaperMidamblePointV2Test < matlab.unittest.TestCase
    methods (Test)
        function estimatorReturnsIntegerFullFftBin(testCase)
            c = sf12NoLdroSf11FlowConfig();
            symbol = v4ModulateSymbol(0,c).*exp( ...
                1i*2*pi*17*(0:c.samplesPerSymbol-1)/c.samplesPerSymbol);
            estimate = v4PaperIntegerPointEstimate(symbol,0,c);
            testCase.verifyEqual(estimate.offsetBins,17);
            testCase.verifyTrue(estimate.integerOnly);
        end

        function noiselessCaseTwoUsesDeterministicIntegerUpdates(testCase)
            [frame,c] = localFrame(2,Inf,1);
            paper = v4PaperMidamblePointDecodeV2(frame.observation,c);
            m = v4EvaluateFrame(paper,frame.truth,c);
            testCase.verifyEqual(m.symbolErrors,71);
            testCase.verifyTrue(all(mod(paper.midambleResidualBins,1)==0));
        end

        function receiverUsesNoCaseTruthOrSubbinSearch(testCase)
            root = v4SetupPaths();
            source = fileread(fullfile(root,'src','paper', ...
                'v4PaperMidamblePointDecodeV2.m'));
            testCase.verifyFalse(contains(source,'caseIndex'));
            testCase.verifyFalse(contains(source,'frame.truth'));
            testCase.verifyFalse(contains(source,'v4PhaseRotationEstimate'));
            testCase.verifyTrue(contains(source,'v4PaperIntegerPointEstimate'));
        end

        function extendedAdmissionRequiresRequestedCurveProperties(testCase)
            raw = zeros(2,16,3,4);
            for snr = 1:16
                raw(1,snr,1,1:3) = max(0,20-snr);
                raw(1,snr,2,1:3) = max(0,20-snr);
                raw(1,snr,3,1:3) = max(0,20-snr)+1;
                raw(2,snr,1,1:3) = 100;
                raw(2,snr,2,1:3) = max(0,50-4*snr);
                raw(2,snr,3,1:3) = max(20,100-3*snr);
            end
            raw(1,9:10,1,2:3) = 0;raw(1,9:10,2,2:3) = 0;
            raw(1,9,3,2:3) = 2;raw(1,10,3,2:3) = 0;
            den = repmat(reshape([112 768 768 1],1,1,1,4),2,16,3,1);
            gate = v4BCaseAnchorExtendedAdmissionV4(raw,den);
            testCase.verifyTrue(gate.paperCurvePass);
            testCase.verifyTrue(gate.targetBerPass);
            testCase.verifyTrue(gate.overallPass);
        end

        function robustRegimeClassifierSeparatesLowSnrAnchors(testCase)
            c = sf12NoLdroSf11FlowConfig();
            for caseIndex = 1:2
                for id = 101:120
                    [frame,~] = localFrame(caseIndex,-30,id);
                    classification = v4Stage55PreambleRegimeClassifier( ...
                        frame.observation.rxPhysical(1:8,:),c);
                    testCase.verifyEqual(classification.largeCfoRegion, ...
                        caseIndex == 1);
                end
            end
        end

        function v7DecoderHasNoCaseOrTruthSwitch(testCase)
            root = v4SetupPaths();source = fileread(fullfile(root,'src', ...
                'stage55','v4Stage55CaseAnchorDecodeV7.m'));
            testCase.verifyFalse(contains(source,'caseIndex'));
            testCase.verifyFalse(contains(source,'frame.truth'));
            testCase.verifyFalse(contains(source,'observation.truth'));
            testCase.verifyTrue(contains(source, ...
                'v4Stage55PreambleRegimeClassifier'));
        end

    end
end

function [frame,c] = localFrame(caseIndex,snrDb,id)
c = sf12NoLdroSf11FlowConfig();cases = [-366 0];
key = struct('planVersion','B-case-anchor-paper-v2-test', ...
    'phase','mechanism','track','B-case-anchor','channel','AWGN', ...
    'comparisonMode','case-anchor-controlled','snrDb',snrDb, ...
    'replicateId',id,'packetId',id,'eventType','paired-frame', ...
    'eventIndex',caseIndex,'sampleIndex',0);
ledger = v4EventRandomLedger(597000000,key);
frame = v4GenerateBCaseAnchorFrame(c,cases(caseIndex),snrDb,ledger);
end
