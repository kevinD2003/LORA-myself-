function test_stage31_causal_confidence_timing()
%TEST_STAGE31_CAUSAL_CONFIDENCE_TIMING Prevent within-code-block feedback.

config = satelliteFig3Config();
[window,~] = satelliteFig3VisibilityWindow(config);
known = zeros(config.bootstrapPilotCount,1);
payload = satelliteFig3GeneratePayload(config,2026100701);
labels = [known;payload.symbolBins];
rx = generateContinuousSatelliteFrame(labels,config, ...
    StartTimeSec=window.deltaTimeInSec,SampleSnrDb=-18, ...
    NoiseSeed=2026100702);
result = satelliteFig3AdaptiveRateReplaySenLoRaDecode(rx,config,known);

assert(result.useCausalConfidenceTiming, ...
    'The formal SenLoRa path does not enforce causal confidence timing.');
blockLength = 4+config.cr;
payloadRows = (config.bootstrapPilotCount+1:numel(labels)).';
blockNumber = floor((payloadRows-config.bootstrapPilotCount-1)/blockLength);
blockEnd = config.bootstrapPilotCount+(blockNumber+1)*blockLength;
expectedAvailability = min(numel(labels)+1,blockEnd+1);
assert(isequal(result.tracker.pilotAvailabilityRows(payloadRows), ...
    expectedAvailability), ...
    'A confidence pilot becomes available before its Hamming block ends.');
accepted = result.pilotAccepted(payloadRows);
assert(all(result.tracker.pilotAppliedAtRows(payloadRows(accepted)) >= ...
    expectedAvailability(accepted)), ...
    'A virtual pilot was applied before all evidence used to confirm it arrived.');
fprintf('Stage 31 causal-confidence-timing test passed.\n');
end
