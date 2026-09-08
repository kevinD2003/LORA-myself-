classdef test_stage30_confidence_only_pilot_labels < SenLoRaStageTestCase
    %TEST_STAGE30_CONFIDENCE_ONLY_PILOT_LABELS MATLAB unit-test wrapper for this stage regression.

    methods (Test)
        function runRegression(~)
            check_test_stage30_confidence_only_pilot_labels();
        end
    end
end

function check_test_stage30_confidence_only_pilot_labels()
%TEST_STAGE30_CONFIDENCE_ONLY_PILOT_LABELS Match the hard-Hamming reference.
%   SenLoRa soft evidence may decide whether a payload symbol is trusted,
%   but the formal compensation path must use the currently compensated
%   hard LoRa decision as the virtual-pilot label.  Otherwise soft Hamming
%   decoding becomes a second, code-aided channel estimator and the hard-
%   Hamming analytical AWGN curve is no longer a matched reference.

config = satelliteFig3Config();
[window,~] = satelliteFig3VisibilityWindow(config);
known = zeros(config.bootstrapPilotCount,1);
payload = satelliteFig3GeneratePayload(config,2026100601);
labels = [known;payload.symbolBins];
rx = generateContinuousSatelliteFrame(labels,config, ...
    StartTimeSec=window.deltaTimeInSec,SampleSnrDb=-20, ...
    NoiseSeed=2026100602);
result = satelliteFig3AdaptiveRateReplaySenLoRaDecode(rx,config,known);
payloadRows = config.bootstrapPilotCount+1:numel(labels);
accepted = result.pilotAccepted(payloadRows);

assert(~result.useSoftDecodedPilotLabels, ...
    'The formal SenLoRa path still uses soft-decoded pilot labels.');
assert(all(result.detectedWaveformBins(payloadRows(accepted)) == ...
    result.tracker.hardWaveformBins(payloadRows(accepted))), ...
    ['An accepted virtual pilot was labelled by a soft codeword rather ', ...
    'than the current hard LoRa decision.']);
fprintf('Stage 30 confidence-only pilot-label test passed.\n');
end
