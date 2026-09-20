classdef V4HuangPrecV3Test < matlab.unittest.TestCase
    methods (Test)
        function case1NoiselessDecodesExactly(testCase)
            [frame,c]=localFrame(1,Inf,1);
            receiver=v4HuangPrecDecodeV3(frame.observation,c);
            testCase.verifyEqual(receiver.detectedPhysicalBins, ...
                frame.truth.payloadPhysicalBins);
        end

        function case2NoiselessIsFiniteAndReceiverOnly(testCase)
            [frame,c]=localFrame(2,Inf,2);
            receiver=v4HuangPrecDecodeV3(frame.observation,c);
            testCase.verifyTrue(all(isfinite(receiver.detectedPhysicalBins)));
            testCase.verifyEqual(receiver.preambleAverageCount,8);
            testCase.verifyFalse(receiver.usesDopplerRate);
            testCase.verifyFalse(receiver.usesPayloadFeedback);
        end

        function sourceHasNoForbiddenInputs(testCase)
            root=v4SetupPaths();source=fileread(fullfile(root,'src','stage55', ...
                'v4HuangPrecDecodeV3.m'));
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
key=struct('planVersion','huang-prec-v3-test','phase','mechanism', ...
    'track','B-method-aligned','channel','AWGN', ...
    'comparisonMode','case-anchor-controlled','snrDb',snrDb, ...
    'replicateId',id,'packetId',id,'eventType','paired-frame', ...
    'eventIndex',caseIndex,'sampleIndex',0);
ledger=v4EventRandomLedger(885000000,key);
frame=v4GenerateBCaseAnchorFrame(c,cases(caseIndex),snrDb,ledger);
end
