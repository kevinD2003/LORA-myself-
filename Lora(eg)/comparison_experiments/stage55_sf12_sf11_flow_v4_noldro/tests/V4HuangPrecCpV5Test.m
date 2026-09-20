classdef V4HuangPrecCpV5Test < matlab.unittest.TestCase
    methods (Test)
        function case1NoiselessDecodesExactly(testCase)
            [frame,c]=localFrame(1,Inf,1);
            receiver=v4HuangPrecCpDecodeV5(frame.observation,c);
            testCase.verifyEqual(receiver.detectedPhysicalBins, ...
                frame.truth.payloadPhysicalBins);
            testCase.verifyTrue(receiver.continuousPhaseAdaptation);
            testCase.verifyEqual(receiver.preambleCombination, ...
                'sum-per-preamble-fft-power');
        end

        function preambleCombinationIsPhaseInvariant(testCase)
            [frame,c]=localFrame(1,Inf,2);
            baseline=v4HuangPrecCpDecodeV5(frame.observation,c);
            rotated=frame.observation;
            phases=(0:c.bootstrapPilotCount-1).'*0.73;
            rotated.rxPhysical(1:c.bootstrapPilotCount,:)= ...
                rotated.rxPhysical(1:c.bootstrapPilotCount,:).*exp(1i*phases);
            changed=v4HuangPrecCpDecodeV5(rotated,c);
            testCase.verifyEqual(changed.epsilonHatBins, ...
                baseline.epsilonHatBins,'AbsTol',10*eps);
            testCase.verifyEqual(changed.detectedPhysicalBins, ...
                baseline.detectedPhysicalBins);
        end

        function case2NoiselessUsesOnlyFixedCfo(testCase)
            [frame,c]=localFrame(2,Inf,3);
            receiver=v4HuangPrecCpDecodeV5(frame.observation,c);
            testCase.verifyTrue(all(isfinite(receiver.detectedPhysicalBins)));
            testCase.verifyFalse(receiver.usesDopplerRate);
            testCase.verifyFalse(receiver.usesPayloadFeedback);
            testCase.verifyEqual(numel(unique(receiver.estimatedCfoBins)),1);
        end

        function sourceHasNoForbiddenInputsOrComplexPilotAverage(testCase)
            root=v4SetupPaths();source=fileread(fullfile(root,'src','stage55', ...
                'v4HuangPrecCpDecodeV5.m'));
            forbidden={'caseIndex','caseProfile','snrDb','frame.truth', ...
                'observation.truth','mean(pilots,1)'};
            for index=1:numel(forbidden)
                testCase.verifyFalse(contains(source,forbidden{index}));
            end
        end
    end
end

function [frame,c]=localFrame(caseIndex,snrDb,id)
c=sf12NoLdroSf11FlowConfig();cases=[-366 0];
key=struct('planVersion','huang-prec-cp-v5-test','phase','mechanism', ...
    'track','B-method-aligned','channel','AWGN', ...
    'comparisonMode','case-anchor-controlled','snrDb',snrDb, ...
    'replicateId',id,'packetId',id,'eventType','paired-frame', ...
    'eventIndex',caseIndex,'sampleIndex',0);
ledger=v4EventRandomLedger(890000000,key);
frame=v4GenerateBCaseAnchorFrame(c,cases(caseIndex),snrDb,ledger);
end
