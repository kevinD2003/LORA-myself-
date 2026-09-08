classdef test_stage24_rate_replay < SenLoRaStageTestCase
    %TEST_STAGE24_RATE_REPLAY MATLAB unit-test wrapper for this stage regression.

    methods (Test)
        function runRegression(~)
            check_test_stage24_rate_replay();
        end
    end
end

function check_test_stage24_rate_replay()
%TEST_STAGE24_RATE_REPLAY Verify truth-free candidate selection and replay.

config = satelliteFig3Config();
[window,~] = satelliteFig3VisibilityWindow(config);
known = zeros(config.bootstrapPilotCount,1);
payload = satelliteFig3GeneratePayload(config,2026093602);
labels = [known;payload.symbolBins];
rx = generateContinuousSatelliteFrame(labels,config, ...
    StartTimeSec=window.deltaTimeInSec,SampleSnrDb=-20, ...
    NoiseSeed=2026093702);
result = satelliteFig3RateReplaySenLoRaDecode(rx,config,known);
assert(~ismember('labels',fieldnames(result.rateReplay)), ...
    'The rate-replay receiver exposed payload truth in its interface.');
assert(isequal(result.soft.decodedDataBits,payload.dataBits), ...
    'The blind rate replay did not recover the reproducible outlier frame.');
assert(abs(result.rateReplay.selectedRateBinsPerSec+1.5) <= 0.25, ...
    'The soft-Hamming score did not select the expected rate neighborhood.');
assert(result.rateReplay.scoreGap >= 0, ...
    'The candidate score gap is invalid.');
assert(numel(result.rateReplay.candidateRatesBinsPerSec) == 1 && ...
    ~result.rateReplay.selectionUsesPayloadCodeEvidence, ...
    'The formal rate path still list-selects using payload-code evidence.');

adaptive = satelliteFig3AdaptiveRateReplaySenLoRaDecode(rx,config,known);
assert(adaptive.rateReplay.triggered, ...
    'The reproducible no-anchor frame did not trigger rate replay.');
rxClean = generateContinuousSatelliteFrame(labels,config, ...
    StartTimeSec=window.deltaTimeInSec,SampleSnrDb=Inf,NoiseSeed=1);
clean = satelliteFig3AdaptiveRateReplaySenLoRaDecode(rxClean,config,known);
assert(clean.rateReplay.triggered && ...
    strcmp(clean.rateReplay.triggerReason,'single_orbit_prior_track'), ...
    'The noiseless frame did not use the common physical-prior path.');

% A low-SNR baseline can contain two mutually consistent but wrong pilots;
% it must remain below the independent confidence-SNR lock and replay.
payload2 = satelliteFig3GeneratePayload(config,2026093203);
labels2 = [known;payload2.symbolBins];
rx2 = generateContinuousSatelliteFrame(labels2,config, ...
    StartTimeSec=window.deltaTimeInSec,SampleSnrDb=-22, ...
    NoiseSeed=2026093303);
low = satelliteFig3AdaptiveRateReplaySenLoRaDecode(rx2,config,known);
assert(low.rateReplay.triggered && ...
    strcmp(low.rateReplay.triggerReason,'single_orbit_prior_track'), ...
    'A low-SNR frame did not use the common physical-prior path.');
fprintf('Stage 24 rate-replay test passed.\n');
end
