classdef V4TrackACausalityTest < matlab.unittest.TestCase
    methods (Test)
        function terminalMidambleCannotChangePayload(testCase)
            c = sf12NoLdroSf11FlowConfig();
            packet = v4GenerateTrackAPacket(c,0,-21,3,410000000);
            a = v4PaperNativeMidambleDecode(packet,c,false);
            row = packet.schedule.terminalMidambleRow;
            first = packet.schedule.startSample(row)+1;
            packet.rx(first:end) = -packet.rx(first:end);
            b = v4PaperNativeMidambleDecode(packet,c,false);
            testCase.verifyEqual(a.detectedPhysicalBins,b.detectedPhysicalBins);
            testCase.verifyEqual(a.estimatedCfoBins,b.estimatedCfoBins);
            testCase.verifyFalse(a.terminalAffectsPayload);
        end
        function acceptedVpAppliesStrictlyLater(testCase)
            c = sf12NoLdroSf11FlowConfig();
            packet = v4GenerateTrackAPacket(c,0,-21,4,410000000);
            result = v4TrackAStage55Decode(packet,c,v4TrackADefaultParameters());
            rows = find(result.virtualPilotAccepted);
            testCase.verifyGreaterThan(result.appliedTimeSec(rows),result.decisionTimeSec(rows));
        end
    end
end
