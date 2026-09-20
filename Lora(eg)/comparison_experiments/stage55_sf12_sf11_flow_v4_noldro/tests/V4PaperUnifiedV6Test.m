classdef V4PaperUnifiedV6Test < matlab.unittest.TestCase
    methods (Test)
        function case1NoiselessDecodeIsExact(testCase)
            [frame,common,c]=localFrame(1,Inf,1);
            receiver=v4PaperMidamblePointUnifiedV6(frame.observation,common,c);
            testCase.verifyEqual(receiver.detectedPhysicalBins, ...
                frame.truth.payloadPhysicalBins);
            testCase.verifyEqual(receiver.paperRegime, ...
                'legacy-point-static-observable');
        end

        function case1ObservablePathIsLegacyBitExact(testCase)
            for packetId=1:40
                [frame,common,c]=localFrame(1,-30,100+packetId);
                legacy=v4PaperMidamblePointUnifiedV4(frame.observation,common,c);
                unified=v4PaperMidamblePointUnifiedV6(frame.observation,common,c);
                testCase.verifyEqual(unified.paperRegime, ...
                    'legacy-point-static-observable');
                testCase.verifyEqual(unified.detectedPhysicalBins, ...
                    legacy.detectedPhysicalBins);
                testCase.verifyEqual(unified.hardDecodedDataBits, ...
                    legacy.hardDecodedDataBits);
            end
        end

        function case2UsesFiniteDynamicTrendPath(testCase)
            [frame,common,c]=localFrame(2,Inf,201);
            receiver=v4PaperMidamblePointUnifiedV6(frame.observation,common,c);
            testCase.verifyEqual(receiver.paperRegime, ...
                'trend-point-dynamic-observable');
            testCase.verifyTrue(receiver.usesDopplerRate);
            testCase.verifyTrue(all(isfinite(receiver.detectedPhysicalBins)));
            testCase.verifyEqual(receiver.methodId,'paper-midamble-adapted-v6');
        end

        function sourceHasNoForbiddenInputs(testCase)
            root=v4SetupPaths();source=fileread(fullfile(root,'src','paper', ...
                'v4PaperMidamblePointUnifiedV6.m'));
            forbidden={'caseIndex','caseProfile','snrDb','frame.truth', ...
                'observation.truth'};
            for index=1:numel(forbidden)
                testCase.verifyFalse(contains(source,forbidden{index}));
            end
        end
    end
end

function [frame,common,c]=localFrame(caseIndex,snrDb,id)
c=sf12NoLdroSf11FlowConfig();cases=[-366 0];
key=struct('planVersion','paper-unified-v6-test','phase','mechanism', ...
    'track','B-method-aligned','channel','AWGN', ...
    'comparisonMode','case-anchor-controlled','snrDb',snrDb, ...
    'replicateId',id,'packetId',id,'eventType','paired-frame', ...
    'eventIndex',caseIndex,'sampleIndex',0);
ledger=v4EventRandomLedger(882000000,key);
frame=v4GenerateBCaseAnchorFrame(c,cases(caseIndex),snrDb,ledger);
p=v4LoadMethodAlignedR3ParametersV1();
common=v4CommonBootstrap(frame.observation.rxPhysical(1:8,:),c, ...
    SearchStepBins=p.searchStepBins);
end
