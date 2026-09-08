function test_stage7_hamming_margin()
%TEST_STAGE7_HAMMING_MARGIN Basic integrity test for SenLoRa score margins.
%   The margin is a soft-Hamming winner-versus-runner-up score and is used
%   only as receiver-visible evidence.  This test contains no pilot update.

root = fileparts(mfilename('fullpath')); addpath(root);
config = satelliteFig3Config(); [window,~] = satelliteFig3VisibilityWindow(config);
payload = satelliteFig3GeneratePayload(config,2026080701);
bins = [zeros(config.bootstrapPilotCount,1); payload.symbolBins];
[rx,~,truth] = generateContinuousSatelliteFrame(bins,config, ...
    StartTimeSec=window.deltaTimeInSec,SampleSnrDb=Inf,NoiseSeed=1);
% The soft decoder is a decision layer, not a Doppler estimator.  Feed it
% the same ideal samplewise compensated signal used by the stage-3 physics
% test, so this verifies the new margin mapping rather than channel removal.
soft = satelliteFig3SenLoRaConfidence(rx.*exp(-1i*truth.phaseRad),config);
payloadRows = config.bootstrapPilotCount+1:numel(bins);
assert(all(isfinite(soft.symbolCodewordMargin(payloadRows))), ...
    'Every completed code block must expose a codeword margin.');
assert(all(soft.symbolCodewordMargin(payloadRows) > 0), ...
    'A noiseless decoded codeword must have positive winner-runner-up margin.');
assert(isequal(soft.decodedWaveformBins(payloadRows),bins(payloadRows)), ...
    'Soft Hamming decoding changed the noiseless payload labels.');
fprintf('Stage 7 Hamming-margin integrity test passed.\n');
end
