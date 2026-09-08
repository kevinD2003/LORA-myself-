function tests = test_lora_dynamic_doppler
%TEST_LORA_DYNAMIC_DOPPLER Unit tests for orbit Doppler and Figure 3.
tests = functiontests(localfunctions);
end

function testDopplerShiftOddSymmetry(testCase)
config = lora_orbit_doppler_config();
positiveTimeSec = linspace(0, config.plotHalfSpanSec, 4001);
positive = lora_orbit_doppler_trajectory(positiveTimeSec, config);
negative = lora_orbit_doppler_trajectory(-positiveTimeSec, config);

symmetryErrorHz = max(abs( ...
    positive.dopplerShiftHz + negative.dopplerShiftHz));
verifyLessThanOrEqual(testCase, symmetryErrorHz, 1e-9);
end

function testDopplerRateEvenSymmetry(testCase)
config = lora_orbit_doppler_config();
positiveTimeSec = linspace(0, config.plotHalfSpanSec, 4001);
positive = lora_orbit_doppler_trajectory(positiveTimeSec, config);
negative = lora_orbit_doppler_trajectory(-positiveTimeSec, config);

symmetryErrorHzPerSec = max(abs( ...
    positive.dopplerRateHzPerSec - ...
    negative.dopplerRateHzPerSec));
verifyLessThanOrEqual(testCase, symmetryErrorHzPerSec, 1e-9);
end

function testVisibilityWindowDuration(testCase)
config = lora_orbit_doppler_config();
window = lora_visibility_window(config);

verifyEqual(testCase, window.totalVisibleDurationSec, ...
    425.3392082263823, "AbsTol", 0.1);
verifyEqual(testCase, window.totalVisibleDurationSec, ...
    config.paperReportedApproximateValue.visibleDurationSec, ...
    "AbsTol", 5);
end

function testVisibilityWindowHasCentralBlindInterval(testCase)
config = lora_orbit_doppler_config();
[window, isVisible] = lora_visibility_window( ...
    config, [window_probe_times(config)]);

verifyGreaterThan(testCase, window.deltaTimeOutSec, ...
    window.deltaTimeInSec);
verifyGreaterThan(testCase, window.deltaTimeInSec, 0);
verifyEqual(testCase, isVisible, [true, false, true]);
verifyEqual(testCase, window.intervalsSec, [ ...
    -249.75203746714354, -37.082433353952396; ...
    37.082433353952396, 249.75203746714354], ...
    "AbsTol", 0.05);
end

function testVisibilityBoundaryElevations(testCase)
config = lora_orbit_doppler_config();
window = lora_visibility_window(config);
outer = lora_orbit_doppler_trajectory( ...
    window.intervalsSec([1, 4]), config);
inner = lora_orbit_doppler_trajectory( ...
    window.intervalsSec([2, 3]), config);

verifyEqual(testCase, outer.elevationRad, ...
    repmat(config.minimumElevationRad, size(outer.elevationRad)), ...
    "AbsTol", deg2rad(1e-8));
verifyEqual(testCase, inner.elevationRad, ...
    repmat(config.maximumElevationRad, size(inner.elevationRad)), ...
    "AbsTol", deg2rad(1e-8));
end

function testMaximumVisibleDopplerShift(testCase)
config = lora_orbit_doppler_config();
window = lora_visibility_window(config);
outer = lora_orbit_doppler_trajectory( ...
    window.intervalsSec([1, 4]), config);
maximumShiftHz = max(abs(outer.dopplerShiftHz));

verifyEqual(testCase, maximumShiftHz, 18215.37944907706, ...
    "AbsTol", 5);
verifyEqual(testCase, maximumShiftHz, 18.2e3, "AbsTol", 300);
end

function testMaximumVisibleDopplerRate(testCase)
config = lora_orbit_doppler_config();
window = lora_visibility_window(config);
inner = lora_orbit_doppler_trajectory( ...
    window.intervalsSec([2, 3]), config);
maximumRateHzPerSec = max(abs(inner.dopplerRateHzPerSec));

verifyEqual(testCase, maximumRateHzPerSec, 166.4306378, ...
    "AbsTol", 0.1);
verifyEqual(testCase, maximumRateHzPerSec, 165.1, "AbsTol", 3);
end

function testInternalAnglesUseRadians(testCase)
config = lora_orbit_doppler_config();

verifyEqual(testCase, config.internalAngleUnit, "radian");
verifyEqual(testCase, config.inclinationRad, deg2rad(15), ...
    "AbsTol", 1e-14);
verifyEqual(testCase, config.theoreticalMaxElevationRad, ...
    deg2rad(56), "AbsTol", 1e-14);
verifyEqual(testCase, config.minimumElevationRad, deg2rad(10), ...
    "AbsTol", 1e-14);
verifyEqual(testCase, config.maximumElevationRad, deg2rad(50), ...
    "AbsTol", 1e-14);
end

function testAnalyticDerivatives(testCase)
config = lora_orbit_doppler_config();
timeSec = [-249, -37, 0, 37, 249];
stepSec = 1e-3;
center = lora_orbit_doppler_trajectory(timeSec, config);
left = lora_orbit_doppler_trajectory(timeSec - stepSec, config);
right = lora_orbit_doppler_trajectory(timeSec + stepSec, config);

velocityDifference = (right.slantRangeM - left.slantRangeM) / ...
    (2*stepSec);
rateDifference = (right.dopplerShiftHz - left.dopplerShiftHz) / ...
    (2*stepSec);

verifyEqual(testCase, center.radialVelocityMps, ...
    velocityDifference, "AbsTol", 1e-3);
verifyEqual(testCase, center.dopplerRateHzPerSec, ...
    rateDifference, "AbsTol", 1e-3);
end

function timesSec = window_probe_times(config)
window = lora_visibility_window(config);
leftMidpoint = mean(window.intervalsSec(1, :));
rightMidpoint = mean(window.intervalsSec(2, :));
timesSec = [leftMidpoint, config.centralVisibilityTimeSec, rightMidpoint];
end
