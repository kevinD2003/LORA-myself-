function test_stage43_hard_prec_common_orbit_prior()
%TEST_STAGE43_HARD_PREC_COMMON_ORBIT_PRIOR Keep physical conditions fair.

config = satelliteFig3Config();
[window,~] = satelliteFig3VisibilityWindow(config);
known = zeros(config.bootstrapPilotCount,1);
payload = satelliteFig3GeneratePayload(config,2026100801);
labels = [known;payload.symbolBins];
rx = generateContinuousSatelliteFrame(labels,config, ...
    StartTimeSec=window.deltaTimeInSec,SampleSnrDb=Inf,NoiseSeed=1);
result = satelliteFig3HardPrecDecode(rx,config,known);
expected = satelliteFig3OrbitRatePriorFromCfo( ...
    result.tracker.bootstrap.coarseCfoBins,config);

assert(result.tracker.bootstrapRateWasOverridden, ...
    'Hard PREC did not use the common receiver-visible orbit prior.');
assert(abs(result.tracker.bootstrapRatePriorBinsPerSec- ...
    expected.rateBinsPerSec) < 10*eps(max(1,abs(expected.rateBinsPerSec))), ...
    'Hard PREC and SenLoRa do not share the same orbit-rate prior.');
assert(result.tracker.rateDeviationLimitBinsPerSec == ...
    config.hardPrecRateTrackingDeviationLimitBinsPerSec, ...
    'Hard PREC did not apply its declared physical rate constraint.');
fprintf('Stage 43 hard-PREC common-orbit-prior test passed.\n');
end
