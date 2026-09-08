classdef test_stage16_receiver_phase_continuity < SenLoRaStageTestCase
    %TEST_STAGE16_RECEIVER_PHASE_CONTINUITY MATLAB unit-test wrapper for this stage regression.

    methods (Test)
        function runRegression(~)
            check_test_stage16_receiver_phase_continuity();
        end
    end
end

function check_test_stage16_receiver_phase_continuity()
%TEST_STAGE16_RECEIVER_PHASE_CONTINUITY Guard the preamble/payload boundary.

config = satelliteFig3Config();
[window,~] = satelliteFig3VisibilityWindow(config);
startTimes = [-window.deltaTimeOutSec,window.deltaTimeInSec];
payload = satelliteFig3GeneratePayload(config,2026082101);
bins = [zeros(config.bootstrapPilotCount,1);payload.symbolBins];
firstPayload = config.bootstrapPilotCount+1;

for scenario = 1:numel(startTimes)
    [rx,~,truth] = generateContinuousSatelliteFrame(bins,config, ...
        StartTimeSec=startTimes(scenario),SampleSnrDb=Inf,NoiseSeed=1);
    tracker = satelliteFig3RollingPilotTracker(rx,config, ...
        zeros(config.bootstrapPilotCount,1));
    phaseError = angle(exp(1i*( ...
        tracker.predictedPhaseStartRad(firstPayload)- ...
        truth.phaseRad(firstPayload,1))));
    assert(abs(phaseError) < 0.05, ...
        'The receiver phase state did not cross the preamble boundary.');
end

fprintf('Stage 16 receiver phase-continuity test passed.\n');
end
