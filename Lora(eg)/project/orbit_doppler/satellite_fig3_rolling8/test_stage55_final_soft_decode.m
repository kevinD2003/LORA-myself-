classdef test_stage55_final_soft_decode < SenLoRaStageTestCase
    %TEST_STAGE55_FINAL_SOFT_DECODE MATLAB unit-test wrapper for this regression.

    methods (Test)
        function runRegression(~)
            check_test_stage55_final_soft_decode();
        end
    end
end

function check_test_stage55_final_soft_decode()
%TEST_STAGE55_FINAL_SOFT_DECODE Make soft-Hamming bits the SenLoRa output.

config = satelliteFig3Config();
[window,~] = satelliteFig3VisibilityWindow(config);
known = zeros(config.bootstrapPilotCount,1);
payload = satelliteFig3GeneratePayload(config,2026270801);
labels = [known;payload.symbolBins];
[rx,~,~] = generateContinuousSatelliteFrame(labels,config, ...
    StartTimeSec=window.deltaTimeInSec,SampleSnrDb=-20, ...
    NoiseSeed=2026270901);
result = satelliteFig3SenLoRaVirtualPilotDecode(rx,config,known);

assert(isfield(result,'softDecodedDataBits'), ...
    'SenLoRa does not expose final soft-Hamming payload bits.');
assert(isfield(result,'decodedDataBits'), ...
    'SenLoRa does not expose a declared final payload output.');
assert(isequal(result.decodedDataBits,result.softDecodedDataBits), ...
    'The declared final SenLoRa output is not the soft-Hamming result.');
assert(numel(result.decodedDataBits) == numel(payload.dataBits), ...
    'The final soft payload has the wrong bit count.');
assert(isfield(result,'hardDecodedDataBits'), ...
    'The hard-decoded audit output was removed instead of retained.');
fprintf('Stage 55 final-soft-decode interface test passed.\n');
end
