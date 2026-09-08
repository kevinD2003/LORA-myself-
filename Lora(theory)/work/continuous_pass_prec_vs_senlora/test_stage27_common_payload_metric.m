function test_stage27_common_payload_metric()
%TEST_STAGE27_COMMON_PAYLOAD_METRIC Keep compensation and decoding gains separate.

config = satelliteFig3Config();
[window,~] = satelliteFig3VisibilityWindow(config);
known = zeros(config.bootstrapPilotCount,1);
payload = satelliteFig3GeneratePayload(config,2026100501);
labels = [known;payload.symbolBins];
[rx,~,~] = generateContinuousSatelliteFrame(labels,config, ...
    StartTimeSec=window.deltaTimeInSec,SampleSnrDb=-18, ...
    NoiseSeed=2026100502);
sen = satelliteFig3AdaptiveRateReplaySenLoRaDecode(rx,config,known);
payloadRows = config.bootstrapPilotCount+1:numel(labels);
expected = satelliteFig3HardPayloadBits( ...
    sen.tracker.hardWaveformBins(payloadRows),config);

assert(isequal(sen.hardDecodedDataBits,expected), ...
    ['SenLoRa BER is not derived from the final compensated hard bins. ', ...
    'The analytical hard-Hamming AWGN reference would be mismatched.']);
assert(numel(sen.hardDecodedDataBits) == numel(payload.dataBits), ...
    'The common payload metric has the wrong decoded bit count.');
fprintf('Stage 27 common-payload-metric test passed.\n');
end
