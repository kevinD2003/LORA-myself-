classdef test_stage8_trusted_confidence < SenLoRaStageTestCase
    %TEST_STAGE8_TRUSTED_CONFIDENCE MATLAB unit-test wrapper for this stage regression.

    methods (Test)
        function runRegression(~)
            check_test_stage8_trusted_confidence();
        end
    end
end

function check_test_stage8_trusted_confidence()
%TEST_STAGE8_TRUSTED_CONFIDENCE Verify safety lock and no-truth interface.

config = satelliteFig3Config(); [window,~] = satelliteFig3VisibilityWindow(config);
payload = satelliteFig3GeneratePayload(config,2026080801);
bins = [zeros(config.bootstrapPilotCount,1);payload.symbolBins];
payloadRows = config.bootstrapPilotCount+1:numel(bins);

lowRx = generateContinuousSatelliteFrame(bins,config, ...
    StartTimeSec=window.deltaTimeInSec,SampleSnrDb=-24,NoiseSeed=2026080802);
low = satelliteFig3TrustedConfidenceDecode(lowRx,config,zeros(config.bootstrapPilotCount,1));
assert(low.replayFromFrameStart && max(abs( ...
    low.recheckTracker.compensatedSymbols(1:config.bootstrapPilotCount,:) - ...
    low.bootstrapTracker.compensatedSymbols(1:config.bootstrapPilotCount,:)),[],'all') < 1e-12, ...
    'Recompensation must replay identically from the eight-symbol preamble.');
assert(~low.snrPromotionEnabled && ~any(low.promotedMask(payloadRows)), ...
    'Low-SNR safety lock must prevent virtual-pilot promotion.');
assert(any(low.quarantineMask(payloadRows)), ...
    'Low SNR must retain quarantined candidates for later recheck.');

midRx = generateContinuousSatelliteFrame(bins,config, ...
    StartTimeSec=window.deltaTimeInSec,SampleSnrDb=-20,NoiseSeed=2026080804);
mid = satelliteFig3TrustedConfidenceDecode(midRx,config,zeros(config.bootstrapPilotCount,1));
assert(mid.snrPromotionEnabled && strcmp(mid.confidencePolicy,'validated_minus20_window'), ...
    'The independently validated narrow -20 dB policy window was not selected.');

highRx = generateContinuousSatelliteFrame(bins,config, ...
    StartTimeSec=window.deltaTimeInSec,SampleSnrDb=Inf,NoiseSeed=2026080803);
high = satelliteFig3TrustedConfidenceDecode(highRx,config,zeros(config.bootstrapPilotCount,1));
assert(high.snrPromotionEnabled && high.recheckEnabled && ...
    sum(high.anchorMask(payloadRows)) >= config.confidenceMinimumAnchorCount, ...
    'High-SNR frame must form two trusted anchors from receiver observations.');
assert(any(high.promotedMask(payloadRows)), ...
    'High-SNR frame must expose promotable virtual pilots.');
assert(isequal(high.finalSoft.decodedWaveformBins(payloadRows),bins(payloadRows)), ...
    'Virtual-pilot replay changed a noiseless payload decision.');
fprintf('Stage 8 trusted-confidence tests passed.\n');
end
