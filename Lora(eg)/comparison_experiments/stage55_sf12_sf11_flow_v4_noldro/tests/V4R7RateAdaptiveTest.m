classdef V4R7RateAdaptiveTest < matlab.unittest.TestCase
    methods (Test)
        function noiselessCasesSelectExpectedModesAndDecode(testCase)
            root=v4SetupPaths();c=sf12NoLdroSf11FlowConfig();p=localP(root);
            a=v4GenerateTrackAPacket(c,-366,Inf,1,850000000);ra=v4TrackAStage55RateAdaptiveDecode(a,c,p);testCase.verifyEqual(ra.receiverMode,'STATIC_SUBBIN');testCase.verifyEqual(ra.detectedPhysicalBins,a.truth.labels);
            b=v4GenerateTrackAPacket(c,0,Inf,2,850000000);rb=v4TrackAStage55RateAdaptiveDecode(b,c,p);testCase.verifyEqual(rb.receiverMode,'DYNAMIC_VP');testCase.verifyEqual(rb.detectedPhysicalBins,b.truth.labels);
        end
        function conditionsAndPaperRemainFrozen(testCase)
            root=v4SetupPaths();m=jsondecode(fileread(fullfile(root,'config','plan_manifest_r6_stage55_improvement.json')));testCase.verifyTrue(m.experimentConditionsFrozen);testCase.verifyTrue(m.paperReceiverFrozen);testCase.verifyEqual(numel(dir(fullfile(root,'results','formal','track_a','R5-point-anchored','**','formal_cell.mat'))),20);
        end
    end
end
function p=localP(root),m=jsondecode(fileread(fullfile(root,'config','paperReceiverParameterManifest_stage3s_v01.json')));p=m.parameters;p.bootstrapStepBins=0.05;p.staticRateThresholdBinsPerSec=3;end
