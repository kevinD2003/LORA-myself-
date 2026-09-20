classdef V4KnownCaseProfileV8Test < matlab.unittest.TestCase
    methods (Test)
        function case1ProfileIsBitExactHuang(testCase)
            [frame,common,c,p] = localFrame(1,-30,1);
            stage = v4Stage55CaseProfileDecodeV8( ...
                frame.observation,common,c,p(2),"case1-static");
            huang = v4HuangStaticDecode(frame.observation,common,c);
            testCase.verifyEqual(stage.detectedPhysicalBins,huang.detectedPhysicalBins);
            testCase.verifyEqual(stage.hardDecodedDataBits,huang.hardDecodedDataBits);
            testCase.verifyEqual(stage.softDecodedDataBits,huang.softDecodedDataBits);
            testCase.verifyTrue(stage.usesKnownCaseProfile);
        end

        function case2ProfileMatchesV7DynamicBranch(testCase)
            [frame,common,c,p] = localFrame(2,-30,2);
            v7 = v4Stage55CaseAnchorDecodeV7(frame.observation,common,c,p(2));
            testCase.assumeFalse(v7.staticFallbackExact);
            v8 = v4Stage55CaseProfileDecodeV8( ...
                frame.observation,common,c,p(2),"case2-dynamic");
            testCase.verifyEqual(v8.detectedPhysicalBins,v7.detectedPhysicalBins);
            testCase.verifyEqual(v8.hardDecodedDataBits,v7.hardDecodedDataBits);
            testCase.verifyEqual(v8.softDecodedDataBits,v7.softDecodedDataBits);
        end

        function profilesDoNotReadPayloadOrOrbitTruth(testCase)
            root = v4SetupPaths();source = fileread(fullfile(root,'src', ...
                'stage55','v4Stage55CaseProfileDecodeV8.m'));
            testCase.verifyFalse(contains(source,'frame.truth'));
            testCase.verifyFalse(contains(source,'observation.truth'));
            testCase.verifyTrue(contains(source,'caseProfile'));
        end
    end
end

function [frame,common,c,p] = localFrame(caseIndex,snrDb,id)
c = sf12NoLdroSf11FlowConfig();p = v4BCalibrationCandidates();cases = [-366 0];
key = struct('planVersion','known-case-profile-v8-test','phase','mechanism', ...
    'track','B-case-anchor','channel','AWGN', ...
    'comparisonMode','case-anchor-controlled','snrDb',snrDb, ...
    'replicateId',id,'packetId',id,'eventType','paired-frame', ...
    'eventIndex',caseIndex,'sampleIndex',0);
ledger = v4EventRandomLedger(608000000,key);
frame = v4GenerateBCaseAnchorFrame(c,cases(caseIndex),snrDb,ledger);
common = v4CommonBootstrap(frame.observation.rxPhysical(1:8,:),c, ...
    SearchStepBins=p(1).searchStepBins);
end
