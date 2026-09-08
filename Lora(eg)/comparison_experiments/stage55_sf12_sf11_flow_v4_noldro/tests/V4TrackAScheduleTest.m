classdef V4TrackAScheduleTest < matlab.unittest.TestCase
    methods (Test)
        function exactEventsAndTiming(testCase)
            c = sf12NoLdroSf11FlowConfig(); s = v4BuildTrackASchedule(c);
            testCase.verifyEqual(s.totalSymbols,41.25);
            testCase.verifyEqual(s.durationSec,1.351680,'AbsTol',1e-12);
            testCase.verifyEqual(numel(s.dataRows),23);
            testCase.verifyEqual(numel(s.midambleRows),8);
            testCase.verifyEqual(s.midambleAfterDataIndex,[3;6;9;12;15;18;21;23]);
            testCase.verifyEqual(s.startSample(s.terminalMidambleRow)/c.samplesPerSymbol,40.25);
            testCase.verifyEqual(s.pointDownRow,10);
        end
    end
end
