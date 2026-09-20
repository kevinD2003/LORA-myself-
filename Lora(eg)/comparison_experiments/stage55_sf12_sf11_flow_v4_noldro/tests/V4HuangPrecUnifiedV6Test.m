classdef V4HuangPrecUnifiedV6Test < matlab.unittest.TestCase
    methods (Test)
        function case1SelectsContinuousPhaseRepair(testCase)
            for packetId=1:40
                [frame,c]=localFrame(1,-30,100+packetId);
                expected=v4HuangPrecCpDecodeV5(frame.observation,c);
                actual=v4HuangPrecUnifiedDecodeV6(frame.observation,c);
                testCase.verifyEqual(actual.huangRegime, ...
                    'continuous-phase-static-observable');
                testCase.verifyEqual(actual.detectedPhysicalBins, ...
                    expected.detectedPhysicalBins);
                testCase.verifyEqual(actual.hardDecodedDataBits, ...
                    expected.hardDecodedDataBits);
            end
        end

        function case2SelectsSourceFixedCfo(testCase)
            [frame,c]=localFrame(2,-21,201);
            expected=v4HuangPrecDecodeV3(frame.observation,c);
            actual=v4HuangPrecUnifiedDecodeV6(frame.observation,c);
            testCase.verifyEqual(actual.huangRegime, ...
                'source-fixed-cfo-dynamic-observable');
            testCase.verifyEqual(actual.detectedPhysicalBins, ...
                expected.detectedPhysicalBins);
            testCase.verifyEqual(actual.hardDecodedDataBits, ...
                expected.hardDecodedDataBits);
            testCase.verifyFalse(actual.usesDopplerRate);
            testCase.verifyFalse(actual.usesPayloadFeedback);
        end

        function sourceHasNoForbiddenInputs(testCase)
            root=v4SetupPaths();source=fileread(fullfile(root,'src','stage55', ...
                'v4HuangPrecUnifiedDecodeV6.m'));
            forbidden={'caseIndex','caseProfile','snrDb','frame.truth', ...
                'observation.truth'};
            for index=1:numel(forbidden)
                testCase.verifyFalse(contains(source,forbidden{index}));
            end
        end
    end
end

function [frame,c]=localFrame(caseIndex,snrDb,id)
c=sf12NoLdroSf11FlowConfig();cases=[-366 0];
key=struct('planVersion','huang-prec-unified-v6-test', ...
    'phase','mechanism','track','B-method-aligned','channel','AWGN', ...
    'comparisonMode','case-anchor-controlled','snrDb',snrDb, ...
    'replicateId',id,'packetId',id,'eventType','paired-frame', ...
    'eventIndex',caseIndex,'sampleIndex',0);
ledger=v4EventRandomLedger(891000000,key);
frame=v4GenerateBCaseAnchorFrame(c,cases(caseIndex),snrDb,ledger);
end
