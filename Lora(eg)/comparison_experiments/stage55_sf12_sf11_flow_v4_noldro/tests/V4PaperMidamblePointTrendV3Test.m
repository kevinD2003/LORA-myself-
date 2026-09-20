classdef V4PaperMidamblePointTrendV3Test < matlab.unittest.TestCase
    methods (Test)
        function caseTwoNoiselessIsSubstantiallyImproved(testCase)
            [frame,c] = localFrame(2,Inf,1);
            point = v4PaperMidamblePointDecodeV2(frame.observation,c);
            trend = v4PaperMidamblePointTrendDecodeV3(frame.observation,c);
            a = v4EvaluateFrame(point,frame.truth,c);
            b = v4EvaluateFrame(trend,frame.truth,c);
            testCase.verifyLessThan(b.symbolErrors,a.symbolErrors);
            testCase.verifyTrue(all(isfinite(trend.midambleResidualBins)));
        end

        function implementationUsesOnlyKnownPointMeasurements(testCase)
            root = v4SetupPaths();source = fileread(fullfile(root,'src','paper', ...
                'v4PaperMidamblePointTrendDecodeV3.m'));
            testCase.verifyFalse(contains(source,'caseIndex'));
            testCase.verifyFalse(contains(source,'snrDb'));
            testCase.verifyFalse(contains(source,'frame.truth'));
            testCase.verifyFalse(contains(source,'observation.truth'));
            testCase.verifyFalse(contains(source,'v4Stage55'));
            testCase.verifyTrue(contains(source,'v4PaperRefinedPointEstimate'));
            testCase.verifyTrue(contains(source,'v4PaperLocalResidualEstimate'));
        end
    end
end

function [frame,c] = localFrame(caseIndex,snrDb,id)
c = sf12NoLdroSf11FlowConfig();cases = [-366 0];
key = struct('planVersion','paper-trend-v3-test','phase','mechanism', ...
    'track','B-case-anchor','channel','AWGN', ...
    'comparisonMode','case-anchor-controlled','snrDb',snrDb, ...
    'replicateId',id,'packetId',id,'eventType','paired-frame', ...
    'eventIndex',caseIndex,'sampleIndex',0);
ledger = v4EventRandomLedger(610000000,key);
frame = v4GenerateBCaseAnchorFrame(c,cases(caseIndex),snrDb,ledger);
end
