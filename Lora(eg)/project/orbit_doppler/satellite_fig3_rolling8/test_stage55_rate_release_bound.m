classdef test_stage55_rate_release_bound < SenLoRaStageTestCase
    %TEST_STAGE55_RATE_RELEASE_BOUND MATLAB unit-test wrapper for this regression.

    methods (Test)
        function runRegression(~)
            check_test_stage55_rate_release_bound();
        end
    end
end

function check_test_stage55_rate_release_bound()
%TEST_STAGE55_RATE_RELEASE_BOUND Keep VP rate updates near the reliable prior.

config = satelliteFig3Config();
schedule = satelliteFig3ContinuousPassSchedule(config);
known = zeros(config.bootstrapPilotCount,1);
payload = satelliteFig3GeneratePayload(config,2026330801);
labels = [known;payload.symbolBins];
[rx,~,~] = generateContinuousSatelliteFrame(labels,config, ...
    StartTimeSec=schedule.frameStartTimeSec(1),SampleSnrDb=-20, ...
    NoiseSeed=2026330901);
decoded = satelliteFig3SenLoRaVirtualPilotDecode(rx,config,known);
assert(decoded.rateDeviationLimitBinsPerSec == ...
        config.senloraRateTrackingDeviationLimitBinsPerSec, ...
    'SenLoRa bypasses its configured safe rate-release bound.');
fprintf('Stage 55 rate-release bound test passed.\n');
end
