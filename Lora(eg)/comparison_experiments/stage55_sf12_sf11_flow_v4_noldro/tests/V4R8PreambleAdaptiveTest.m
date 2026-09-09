classdef V4R8PreambleAdaptiveTest < matlab.unittest.TestCase
    methods (Test)
        function noiselessModesAndLabels(testCase)
            root=v4SetupPaths();c=sf12NoLdroSf11FlowConfig();p=localP(root);
            a=v4GenerateTrackAPacket(c,-366,Inf,1,860000000);ra=v4TrackAStage55PreambleAdaptiveDecode(a,c,p);testCase.verifyEqual(ra.receiverMode,'EIGHT_UPCHIRP_STATIC');testCase.verifyEqual(ra.detectedPhysicalBins,a.truth.labels);
            b=v4GenerateTrackAPacket(c,0,Inf,2,860000000);rb=v4TrackAStage55PreambleAdaptiveDecode(b,c,p);testCase.verifyEqual(rb.receiverMode,'TWO_DOWN_DYNAMIC_VP');testCase.verifyEqual(rb.detectedPhysicalBins,b.truth.labels);
        end
        function sourceHasNoCaseOrTruthInput(testCase)
            root=v4SetupPaths();text=fileread(fullfile(root,'src','paper_anchor','v4TrackAStage55PreambleAdaptiveDecode.m'));testCase.verifyFalse(contains(text,'packet.truth'));testCase.verifyFalse(contains(text,'caseStartTime'));testCase.verifyFalse(contains(text,'midamble'));
        end
    end
end
function p=localP(root),m=jsondecode(fileread(fullfile(root,'config','paperReceiverParameterManifest_stage3s_v01.json')));p=m.parameters;p.bootstrapStepBins=0.05;p.highShiftThresholdBins=100;end
