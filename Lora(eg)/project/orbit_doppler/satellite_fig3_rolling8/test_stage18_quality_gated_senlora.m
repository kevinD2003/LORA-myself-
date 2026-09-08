classdef test_stage18_quality_gated_senlora < SenLoRaStageTestCase
    %TEST_STAGE18_QUALITY_GATED_SENLORA MATLAB unit-test wrapper for this stage regression.

    methods (Test)
        function runRegression(~)
            check_test_stage18_quality_gated_senlora();
        end
    end
end

function check_test_stage18_quality_gated_senlora()
%TEST_STAGE18_QUALITY_GATED_SENLORA Verify safety and high-SNR operation.

config = satelliteFig3Config();
[window,~] = satelliteFig3VisibilityWindow(config);
known = zeros(config.bootstrapPilotCount,1);
payloadRows = config.bootstrapPilotCount+ ...
    (1:config.payloadSymbolCount);

% These low-SNR seeds expose false pilots in the ungated five-pass route.
for frame = 2:3
    payload = satelliteFig3GeneratePayload(config, ...
        config.randomSeedSymbols+2000+frame);
    bins = [known;payload.symbolBins];
    rx = generateContinuousSatelliteFrame(bins,config, ...
        StartTimeSec=window.deltaTimeInSec,SampleSnrDb=-22, ...
        NoiseSeed=config.randomSeedNoise+2000+frame);
    result = satelliteFig3QualityGatedSenLoRaDecode(rx,config,known);
    falseAccepted = result.pilotAccepted(payloadRows) & ...
        result.detectedWaveformBins(payloadRows) ~= bins(payloadRows);
    assert(~any(falseAccepted), ...
        'The quality-gated SenLoRa route accepted a wrong low-SNR pilot.');
end

% In a noiseless high-rate frame, dynamic pilots must remain available.
payload = satelliteFig3GeneratePayload(config,2026082601);
bins = [known;payload.symbolBins];
rx = generateContinuousSatelliteFrame(bins,config, ...
    StartTimeSec=window.deltaTimeInSec,SampleSnrDb=Inf,NoiseSeed=1);
result = satelliteFig3QualityGatedSenLoRaDecode(rx,config,known);
assert(any(result.pilotAccepted(payloadRows)), ...
    'The quality gate suppressed every noiseless virtual pilot.');
assert(isequal(result.soft.decodedDataBits,payload.dataBits), ...
    'The quality-gated noiseless receiver did not recover all data bits.');
for iteration = 2:numel(result.iterationHistory)
    previous = result.iterationHistory(iteration-1).requestedMask;
    current = result.iterationHistory(iteration).requestedMask;
    assert(all(current(previous)), ...
        'A confirmed virtual pilot disappeared on a later replay.');
end

fprintf('Stage 18 quality-gated SenLoRa test passed.\n');
end
