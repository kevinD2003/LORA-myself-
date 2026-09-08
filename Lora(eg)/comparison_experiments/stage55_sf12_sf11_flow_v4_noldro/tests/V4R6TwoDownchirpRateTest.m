classdef V4R6TwoDownchirpRateTest < matlab.unittest.TestCase
    methods (Test)
        function case0NoiselessRateAndSer(testCase)
            root=v4SetupPaths();c=sf12NoLdroSf11FlowConfig();q=v4GenerateTrackAPacket(c,0,Inf,1,810000000);b=v4TrackATwoDownchirpBootstrap(q,c,0.05);
            truth=v4TrackAOrbit([8.5 9.5]*c.symbolDurationSec,c);truthRate=diff(truth.dopplerHz/c.fftBinSpacingHz)/c.symbolDurationSec;
            testCase.verifyLessThan(abs(b.rateBinsPerSec-truthRate),1.0);
            p=localParameters(root);r=v4TrackAStage55TwoDownRateDecode(q,c,p);
            testCase.verifyEqual(r.detectedPhysicalBins,q.truth.labels);testCase.verifyFalse(r.usesTruth);
        end
        function caseMinus366NoiselessSer(testCase)
            root=v4SetupPaths();c=sf12NoLdroSf11FlowConfig();q=v4GenerateTrackAPacket(c,-366,Inf,2,810000000);r=v4TrackAStage55TwoDownRateDecode(q,c,localParameters(root));testCase.verifyEqual(r.detectedPhysicalBins,q.truth.labels);
        end
        function receiverHasNoForbiddenInputs(testCase)
            root=v4SetupPaths();text=fileread(fullfile(root,'src','paper_anchor','v4TrackAStage55TwoDownRateDecode.m'));
            testCase.verifyFalse(contains(text,'packet.truth'));testCase.verifyFalse(contains(text,'v4DecodePayload'));testCase.verifyFalse(contains(text,'midamble'));
        end
        function paperAndR5FormalRemainUnchanged(testCase)
            root=v4SetupPaths();files=dir(fullfile(root,'results','formal','track_a','R5-point-anchored','**','formal_cell.mat'));testCase.verifyEqual(numel(files),20);
            audit=jsondecode(fileread(fullfile(root,'results','reports','EXPERIMENT_A_FINAL_AUDIT.json')));testCase.verifyEqual(audit.overall,'PASS');
        end
    end
end
function p=localParameters(root)
m=jsondecode(fileread(fullfile(root,'config','paperReceiverParameterManifest_stage3s_v01.json')));p=m.parameters;p.bootstrapStepBins=0.05;
end
