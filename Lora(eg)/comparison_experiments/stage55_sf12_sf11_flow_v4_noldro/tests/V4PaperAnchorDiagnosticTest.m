classdef V4PaperAnchorDiagnosticTest < matlab.unittest.TestCase
    methods (Test)
        function noDopplerNoNoiseHasZeroSer(testCase)
            c = sf12NoLdroSf11FlowConfig();
            packet = v4GenerateTrackAPacket(c,-366,Inf,1,410000000);
            receiver = v4PaperNoDopplerBaseline(packet,c);
            metrics = v4EvaluateTrackAPacket(receiver,packet.truth,c);
            testCase.verifyEqual(metrics.ser,0);
        end
        function stage55IsSymbolOnly(testCase)
            c = sf12NoLdroSf11FlowConfig();
            packet = v4GenerateTrackAPacket(c,0,Inf,2,410000000);
            result = v4TrackAStage55Decode(packet,c,v4TrackADefaultParameters());
            testCase.verifyFalse(result.usesHamming);
            testCase.verifyFalse(result.usesPhasePair);
            testCase.verifyFalse(result.terminalMidambleObserved);
        end
    end
end
