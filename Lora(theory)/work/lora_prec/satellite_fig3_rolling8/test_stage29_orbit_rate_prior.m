function test_stage29_orbit_rate_prior()
%TEST_STAGE29_ORBIT_RATE_PRIOR Check truth-free CFO-to-rate orbit mapping.

config = satelliteFig3Config();
[window,~] = satelliteFig3VisibilityWindow(config);
starts = [-window.deltaTimeOutSec,window.deltaTimeInSec];
known = zeros(config.bootstrapPilotCount,1);
for scene = 1:numel(starts)
    [rx,~,truth] = generateContinuousSatelliteFrame(known,config, ...
        StartTimeSec=starts(scene),SampleSnrDb=Inf,NoiseSeed=1);
    bootstrap = satelliteFig3BootstrapEstimate(rx,known,config);
    prior = satelliteFig3OrbitRatePriorFromCfo( ...
        bootstrap.coarseCfoBins,config);
    truthRate = mean(truth.trueDopplerRateHzPerSec)/ ...
        config.fftBinSpacingHz;
    assert(abs(prior.rateBinsPerSec-truthRate) < 0.01, ...
        'Coarse-CFO orbit rate prior disagrees with the channel geometry.');
    assert(~any(ismember({'truth','startTimeSec'},fieldnames(prior))), ...
        'Orbit-prior receiver output exposes simulation truth.');
end
fprintf('Stage 29 orbit-rate-prior test passed.\n');
end
