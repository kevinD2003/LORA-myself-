classdef test_stage28_rate_release < SenLoRaStageTestCase
    %TEST_STAGE28_RATE_RELEASE MATLAB unit-test wrapper for this stage regression.

    methods (Test)
        function runRegression(~)
            check_test_stage28_rate_release();
        end
    end
end

function check_test_stage28_rate_release()
%TEST_STAGE28_RATE_RELEASE Trusted virtual pilots must update Doppler rate.

config = satelliteFig3Config();
[window,~] = satelliteFig3VisibilityWindow(config);
known = zeros(config.bootstrapPilotCount,1);
payload = satelliteFig3GeneratePayload(config,2026210001);
labels = [known;payload.symbolBins];
rx = generateContinuousSatelliteFrame(labels,config, ...
    StartTimeSec=window.deltaTimeInSec,SampleSnrDb=Inf,NoiseSeed=1);
requested = true(numel(labels),1);
tracker = satelliteFig3RollingPilotTracker(rx,config,known, ...
    AcceptedMask=requested,DecisionWaveformBins=labels, ...
    ForceAccept=true,FreezeBootstrapRate=true, ...
    BootstrapRateOverrideBinsPerSec=0, ...
    ReleaseBootstrapRateAfterVirtualPilotCount=2);
firstPayload = config.bootstrapPilotCount+1;

assert(tracker.predictedRateBinsPerSec(firstPayload) == 0 && ...
    tracker.predictedRateBinsPerSec(firstPayload+1) == 0, ...
    'Bootstrap rate was released before two virtual pilots were accepted.');
assert(abs(tracker.predictedRateBinsPerSec(firstPayload+2)) > 0.1, ...
    'Trusted rolling virtual pilots did not release and update the rate.');
assert(tracker.acceptedVirtualPilotCount == config.payloadSymbolCount, ...
    'The tracker virtual-pilot acceptance audit count is inconsistent.');
fprintf('Stage 28 rate-release test passed.\n');
end
