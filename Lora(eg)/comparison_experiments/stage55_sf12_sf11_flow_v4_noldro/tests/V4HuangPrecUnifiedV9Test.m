classdef V4HuangPrecUnifiedV9Test < matlab.unittest.TestCase
    methods (Test)
        function case1MatchesFrozenStageStaticPath(testCase)
            parameters=v4LoadMethodAlignedR3ParametersV1();
            for packetId=1:40
                [frame,c]=localFrame(1,-30,100+packetId);
                common=v4CommonBootstrap( ...
                    frame.observation.rxPhysical(1:8,:),c, ...
                    SearchStepBins=parameters.searchStepBins);
                stage=v4Stage55UnifiedDecodeV16(frame.observation,common,c);
                actual=v4HuangPrecUnifiedDecodeV9(frame.observation,c);
                testCase.verifyTrue(actual.modeEvidence.staticSelected);
                testCase.verifyEqual(actual.detectedPhysicalBins, ...
                    stage.detectedPhysicalBins);
                testCase.verifyEqual(actual.hardDecodedDataBits, ...
                    stage.hardDecodedDataBits);
            end
        end

        function case2MatchesSourceFixedCfo(testCase)
            [frame,c]=localFrame(2,-21,201);
            expected=v4HuangPrecDecodeV3(frame.observation,c);
            actual=v4HuangPrecUnifiedDecodeV9(frame.observation,c);
            testCase.verifyFalse(actual.modeEvidence.staticSelected);
            testCase.verifyEqual(actual.detectedPhysicalBins, ...
                expected.detectedPhysicalBins);
            testCase.verifyEqual(actual.hardDecodedDataBits, ...
                expected.hardDecodedDataBits);
            testCase.verifyFalse(actual.usesDopplerRate);
            testCase.verifyFalse(actual.usesPayloadFeedback);
        end

        function sourceHasNoForbiddenInputs(testCase)
            root=v4SetupPaths();source=fileread(fullfile(root,'src','stage55', ...
                'v4HuangPrecUnifiedDecodeV9.m'));
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
key=struct('planVersion','huang-prec-unified-v9-test', ...
    'phase','mechanism','track','B-method-aligned','channel','AWGN', ...
    'comparisonMode','case-anchor-controlled','snrDb',snrDb, ...
    'replicateId',id,'packetId',id,'eventType','paired-frame', ...
    'eventIndex',caseIndex,'sampleIndex',0);
ledger=v4EventRandomLedger(894000000,key);
frame=v4GenerateBCaseAnchorFrame(c,cases(caseIndex),snrDb,ledger);
end
