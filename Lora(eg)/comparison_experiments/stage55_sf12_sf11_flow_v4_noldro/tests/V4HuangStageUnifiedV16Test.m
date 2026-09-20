classdef V4HuangStageUnifiedV16Test < matlab.unittest.TestCase
    methods (Test)
        function noiselessCasesDecodeExactly(testCase)
            for caseIndex=1:2
                [frame,common,c]=localFrame(caseIndex,Inf,caseIndex);
                huang=v4HuangUnifiedDecodeV2(frame.observation,common,c);
                stage=v4Stage55UnifiedDecodeV16(frame.observation,common,c);
                testCase.verifyEqual(huang.detectedPhysicalBins, ...
                    frame.truth.payloadPhysicalBins);
                testCase.verifyEqual(stage.detectedPhysicalBins, ...
                    frame.truth.payloadPhysicalBins);
            end
        end

        function case1PathsAreLegacyEquivalent(testCase)
            for packetId=1:40
                [frame,common,c]=localFrame(1,-30,100+packetId);
                legacy=v4HuangStaticDecode(frame.observation,common,c);
                huang=v4HuangUnifiedDecodeV2(frame.observation,common,c);
                stage=v4Stage55UnifiedDecodeV16(frame.observation,common,c);
                testCase.verifyEqual(huang.huangRegime, ...
                    'legacy-static-prec-observable');
                testCase.verifyEqual(stage.stageRegime, ...
                    'huang-equivalent-static-observable');
                testCase.verifyEqual(huang.detectedPhysicalBins, ...
                    legacy.detectedPhysicalBins);
                testCase.verifyEqual(stage.detectedPhysicalBins, ...
                    legacy.detectedPhysicalBins);
            end
        end

        function case2UsesDynamicObservablePaths(testCase)
            [frame,common,c]=localFrame(2,-21,201);
            huang=v4HuangUnifiedDecodeV2(frame.observation,common,c);
            stage=v4Stage55UnifiedDecodeV16(frame.observation,common,c);
            testCase.verifyEqual(huang.huangRegime, ...
                'preamble-rate-prec-dynamic-observable');
            testCase.verifyEqual(stage.stageRegime, ...
                'joint-preamble-vp-dynamic-observable');
            testCase.verifyFalse(huang.usesPayloadFeedback);
        end

        function sourcesHaveNoForbiddenInputs(testCase)
            root=v4SetupPaths();files={'v4HuangUnifiedDecodeV2.m', ...
                'v4Stage55UnifiedDecodeV16.m'};
            forbidden={'caseIndex','caseProfile','snrDb','frame.truth', ...
                'observation.truth'};
            for fileIndex=1:numel(files)
                source=fileread(fullfile(root,'src','stage55',files{fileIndex}));
                for wordIndex=1:numel(forbidden)
                    testCase.verifyFalse(contains(source,forbidden{wordIndex}));
                end
            end
        end
    end
end

function [frame,common,c]=localFrame(caseIndex,snrDb,id)
c=sf12NoLdroSf11FlowConfig();cases=[-366 0];
key=struct('planVersion','unified-v16-test','phase','mechanism', ...
    'track','B-method-aligned','channel','AWGN', ...
    'comparisonMode','case-anchor-controlled','snrDb',snrDb, ...
    'replicateId',id,'packetId',id,'eventType','paired-frame', ...
    'eventIndex',caseIndex,'sampleIndex',0);
ledger=v4EventRandomLedger(883000000,key);
frame=v4GenerateBCaseAnchorFrame(c,cases(caseIndex),snrDb,ledger);
p=v4LoadMethodAlignedR3ParametersV1();
common=v4CommonBootstrap(frame.observation.rxPhysical(1:8,:),c, ...
    SearchStepBins=p.searchStepBins);
end
