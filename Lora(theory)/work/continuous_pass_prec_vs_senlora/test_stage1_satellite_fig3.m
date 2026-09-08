function test_stage1_satellite_fig3()
%TEST_STAGE1_SATELLITE_FIG3 Deterministic foundation checks for Stage 1.

config = satelliteFig3Config();
[window,~] = satelliteFig3VisibilityWindow(config);
assert(abs(window.deltaTimeOutSec-249.752) < 0.5, 'Outer visibility time changed.');
assert(abs(window.deltaTimeInSec-37.082) < 0.5, 'Inner visibility time changed.');
assert(abs(window.totalVisibleDurationSec-425.339) < 1.0, 'Visible duration changed.');

t = linspace(-window.deltaTimeOutSec,-window.deltaTimeInSec,10001).';
trajectory = satelliteFig3Trajectory(t,config);
absShift = abs(trajectory.dopplerShiftHz);
absRate = abs(trajectory.dopplerRateHzPerSec);
assert(max(absShift) > 18e3 && min(absShift) < 7.2e3, 'Figure 3 shift range mismatch.');
assert(max(absRate) > 160 && min(absRate) < 9, 'Figure 3 rate range mismatch.');

stream = RandStream('mt19937ar','Seed',17);
for k = 1:20
    code = randi(stream,[0 1],config.sf,4+config.cr);
    bins = satelliteFig3DiagonalInterleave(code);
    assert(isequal(code,satelliteFig3DiagonalDeinterleave(bins,config.sf)), ...
        'Diagonal interleaver round trip failed.');
end

payload = satelliteFig3GeneratePayload(config,19);
assert(numel(payload.symbolBins) == config.payloadSymbolCount, 'Payload length mismatch.');
frameBins = [zeros(config.bootstrapPilotCount,1); payload.symbolBins];
[rx,tx,truth] = generateContinuousSatelliteFrame(frameBins,config, ...
    StartTimeSec=window.deltaTimeInSec,SampleSnrDb=Inf);
assert(max(abs(rx(:)-tx(:).*exp(1i*truth.phaseRad(:)))) < 1e-12, ...
    'Noise-free channel mismatch.');
phase = reshape(truth.phaseRad.',[],1);
doppler = reshape(truth.dopplerHz.',[],1);
edge = config.samplesPerSymbol*(1:config.frameSymbolCount-1);
expected = pi/config.sampleRateHz*(doppler(edge)+doppler(edge+1));
actual = phase(edge+1)-phase(edge);
assert(max(abs(actual-expected)) < 1e-10, 'Phase is not continuous at a symbol edge.');
fprintf('Stage 1 tests passed.\\n');
end
