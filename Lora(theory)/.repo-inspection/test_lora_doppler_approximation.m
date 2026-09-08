function tests = test_lora_doppler_approximation
%TEST_LORA_DOPPLER_APPROXIMATION 验证论文分段线性 Doppler 近似。
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
testCase.TestData.originalPath = path();
addpath("D:\codex\Lora(theory)");
end

function teardownOnce(testCase)
path(testCase.TestData.originalPath);
end

function testFigure17GeometryUsesFormulaDerivedSharedWindow(testCase)
geometry = lora_figure17_geometry();

verifyEqual(testCase, geometry.deltaTimeABSec, ...
    1.507287527200, "AbsTol", 0.01);
verifyEqual(testCase, geometry.singleDeviceAFirstSec, ...
    [-254.870648405068, -2.344896842552], ...
    "AbsTol", 0.05);
verifyEqual(testCase, geometry.sharedFirstSec, ...
    [-253.364624963310, -2.344896842552], ...
    "AbsTol", 0.05);
verifyEqual(testCase, geometry.highShiftTimeSec, ...
    geometry.sharedFirstSec(1), "AbsTol", 1e-12);
verifyEqual(testCase, geometry.highRateTimeSec, ...
    geometry.sharedFirstSec(2), "AbsTol", 1e-12);
verifyEqual(testCase, geometry.configA.internalAngleUnit, "radian");
verifyEqual(testCase, geometry.configA.theoreticalMaxElevationRad, ...
    deg2rad(89), "AbsTol", 1e-14);
verifyEqual(testCase, geometry.configB.theoreticalMaxElevationRad, ...
    deg2rad(89.2), "AbsTol", 1e-14);
end

function testExactDopplerUsesFullRfInstantaneousFrequency(testCase)
geometry = lora_figure17_geometry();
sf = 7;
symbol = uint32(2^(sf-1));
bandwidthHz = 250e3;
result = lora_doppler_piecewise_linear( ...
    symbol, sf, geometry.highShiftTimeSec, geometry.configA, ...
    BandwidthHz=bandwidthHz);

sampleTimeSec = geometry.highShiftTimeSec + ...
    (0:2^sf-1).'/bandwidthHz;
basebandHz = lora_symbol_instantaneous_frequency( ...
    symbol, sf, bandwidthHz);
orbit = lora_orbit_doppler_trajectory( ...
    sampleTimeSec, geometry.configA);
expectedHz = -(geometry.configA.carrierFrequencyHz + basebandHz).* ...
    orbit.radialVelocityMps/geometry.configA.speedOfLightMps;

verifyEqual(testCase, result.exactDopplerHz, ...
    expectedHz, "AbsTol", 1e-9);
verifyEqual(testCase, result.basebandFrequencyHz, ...
    basebandHz, "AbsTol", 1e-12);
verifyEqual(testCase, result.radialVelocityMps, ...
    orbit.radialVelocityMps, "AbsTol", 1e-12);
end

function testSingleSymbolExactAndLinearAgreement(testCase)
geometry = lora_figure17_geometry();
cases = approximation_cases(geometry);

for caseIndex = 1:height(cases)
    result = lora_doppler_piecewise_linear( ...
        uint32(cases.symbol(caseIndex)), ...
        cases.sf(caseIndex), ...
        cases.startTimeSec(caseIndex), ...
        geometry.configA, ...
        BandwidthHz=250e3);
    diagnostic = case_diagnostic(cases, caseIndex, -1);

    verifyLessThanOrEqual(testCase, ...
        result.meanAbsErrorHz, 5e-4, diagnostic);
    verifyLessThanOrEqual(testCase, ...
        result.maxAbsErrorHz, 1e-3, diagnostic);
    verifyLessThanOrEqual(testCase, ...
        result.rmseHz, 6e-4, diagnostic);
    verifyLessThanOrEqual(testCase, ...
        result.phaseRmseRad, 2e-5, diagnostic);
    verifyEqual(testCase, result.appliedDeltaFkHz, ...
        -result.paperPrintedBvOverCHz, "AbsTol", 1e-12);
    verifyEqual(testCase, result.velocityConvention, ...
        "range_rate_positive_receding");
end
end

function testExactAndLinearPhaseUseTrapezoidalIntegration(testCase)
geometry = lora_figure17_geometry();
cases = approximation_cases(geometry);

for caseIndex = 1:height(cases)
    result = lora_doppler_piecewise_linear( ...
        uint32(cases.symbol(caseIndex)), ...
        cases.sf(caseIndex), ...
        cases.startTimeSec(caseIndex), ...
        geometry.configA, ...
        BandwidthHz=250e3);
    expectedExactPhase = trapezoidal_phase( ...
        result.exactDopplerHz, result.sampleRateHz);
    expectedLinearPhase = trapezoidal_phase( ...
        result.linearDopplerHz, result.sampleRateHz);

    verifyEqual(testCase, result.exactPhaseRad, ...
        expectedExactPhase, "AbsTol", 1e-12);
    verifyEqual(testCase, result.linearPhaseRad, ...
        expectedLinearPhase, "AbsTol", 1e-12);
end
end

function testNoiselessFftPeakMatchesForExactAndLinearDoppler(testCase)
geometry = lora_figure17_geometry();
cases = approximation_cases(geometry);

for caseIndex = 1:height(cases)
    sf = cases.sf(caseIndex);
    symbol = uint32(cases.symbol(caseIndex));
    result = lora_doppler_piecewise_linear( ...
        symbol, sf, cases.startTimeSec(caseIndex), ...
        geometry.configA, BandwidthHz=250e3);
    tx = lora_css_modulate(symbol, sf);
    exactRx = tx.*exp(1i*result.exactPhaseRad);
    linearRx = tx.*exp(1i*result.linearPhaseRad);

    exactBin = lora_css_demodulate(exactRx, sf);
    linearBin = lora_css_demodulate(linearRx, sf);
    [exactFft, linearFft] = dechirped_ffts( ...
        exactRx, linearRx, sf);
    relativeDifference = norm(exactFft - linearFft)/ ...
        norm(exactFft);
    diagnostic = case_diagnostic(cases, caseIndex, -1);

    verifyEqual(testCase, exactBin, linearBin, diagnostic);
    verifyLessThanOrEqual(testCase, ...
        relativeDifference, 1e-4, diagnostic);
end
end

function testSymbolwiseVdFollowsSmoothOrbitRate(testCase)
geometry = lora_figure17_geometry();
cases = approximation_cases(geometry);
symbolCount = 50;

for caseIndex = 1:height(cases)
    sf = cases.sf(caseIndex);
    symbol = uint32(cases.symbol(caseIndex));
    symbolPeriodSec = 2^sf/250e3;
    startTimeSec = cases.startTimeSec(caseIndex) + ...
        (0:symbolCount-1).'*symbolPeriodSec;
    vdHz = zeros(symbolCount, 1);

    for symbolIndex = 1:symbolCount
        result = lora_doppler_piecewise_linear( ...
            symbol, sf, startTimeSec(symbolIndex), ...
            geometry.configA, BandwidthHz=250e3);
        vdHz(symbolIndex) = result.vdHz;
        verify_symbol_error_limits( ...
            testCase, result, cases, caseIndex, symbolIndex-1);
    end

    orbitAtStarts = lora_orbit_doppler_trajectory( ...
        startTimeSec, geometry.configA);
    expectedStepHz = 0.5*( ...
        orbitAtStarts.dopplerRateHzPerSec(1:end-1) + ...
        orbitAtStarts.dopplerRateHzPerSec(2:end))* ...
        symbolPeriodSec;
    verifyEqual(testCase, diff(vdHz), ...
        expectedStepHz, "AbsTol", 1e-4, ...
        case_diagnostic(cases, caseIndex, -1));
end
end

function testSymbolwiseCdAndWrapCorrectionRemainContinuous(testCase)
geometry = lora_figure17_geometry();
cases = approximation_cases(geometry);
symbolCount = 50;

for caseIndex = 1:height(cases)
    sf = cases.sf(caseIndex);
    symbol = uint32(cases.symbol(caseIndex));
    symbolPeriodSec = 2^sf/250e3;
    cdHzPerSec = zeros(symbolCount, 1);
    appliedDeltaFkHz = zeros(symbolCount, 1);

    for symbolIndex = 1:symbolCount
        startTimeSec = cases.startTimeSec(caseIndex) + ...
            (symbolIndex-1)*symbolPeriodSec;
        result = lora_doppler_piecewise_linear( ...
            symbol, sf, startTimeSec, geometry.configA, ...
            BandwidthHz=250e3);
        cdHzPerSec(symbolIndex) = result.cdHzPerSec;
        appliedDeltaFkHz(symbolIndex) = ...
            result.appliedDeltaFkHz;
    end

    diagnostic = case_diagnostic(cases, caseIndex, -1);
    verifyLessThanOrEqual(testCase, ...
        max(abs(diff(cdHzPerSec))), 5, diagnostic);
    verifyLessThanOrEqual(testCase, ...
        max(abs(diff(appliedDeltaFkHz))), 0.01, diagnostic);
end
end

function testRunnerCreatesRequiredArtifacts(testCase)
outputDirectory = tempname;
mkdir(outputDirectory);
testCase.addTeardown(@() remove_temp_directory(outputDirectory));

outputs = run_lora_doppler_approx_validation( ...
    OutputDirectory=outputDirectory, ...
    SymbolCount=2, ...
    FigureVisible="off");

expectedFiles = [ ...
    "doppler_approx_figure5_like_high_shift_sf7.png"
    "doppler_approx_figure5_like_high_shift_sf7.pdf"
    "doppler_approx_figure5_like_high_rate_sf7.png"
    "doppler_approx_figure5_like_high_rate_sf7.pdf"
    "doppler_approx_figure5_like_high_shift_sf12.png"
    "doppler_approx_figure5_like_high_shift_sf12.pdf"
    "doppler_approx_figure5_like_high_rate_sf12.png"
    "doppler_approx_figure5_like_high_rate_sf12.pdf"
    "doppler_symbol_to_symbol_drift_high_shift_sf7.png"
    "doppler_symbol_to_symbol_error_high_shift_sf7.png"
    "doppler_symbol_to_symbol_drift_high_rate_sf7.png"
    "doppler_symbol_to_symbol_error_high_rate_sf7.png"
    "doppler_symbol_to_symbol_drift_high_shift_sf12.png"
    "doppler_symbol_to_symbol_error_high_shift_sf12.png"
    "doppler_symbol_to_symbol_drift_high_rate_sf12.png"
    "doppler_symbol_to_symbol_error_high_rate_sf12.png"
    "doppler_approx_single_symbol_metrics.csv"
    "doppler_approx_single_symbol_metrics.json"
    "doppler_symbolwise_validation.csv"
    "doppler_symbolwise_validation.json"];

for fileIndex = 1:numel(expectedFiles)
    filePath = fullfile(outputDirectory, expectedFiles(fileIndex));
    verifyTrue(testCase, isfile(filePath), ...
        "缺少输出文件：" + expectedFiles(fileIndex));
    fileInfo = dir(filePath);
    verifyGreaterThan(testCase, fileInfo.bytes, 0, ...
        "输出文件为空：" + expectedFiles(fileIndex));
end
verifyEqual(testCase, outputs.symbolCount, 2);
verifyEqual(testCase, outputs.berSweepRun, false);
end

function testInvalidApproximationInputsAreRejected(testCase)
geometry = lora_figure17_geometry();

verifyError(testCase, @() lora_doppler_piecewise_linear( ...
    uint32(128), 7, geometry.highShiftTimeSec, ...
    geometry.configA), "lora:InvalidSymbol");
verifyError(testCase, @() lora_doppler_piecewise_linear( ...
    uint32(64), 7, Inf, geometry.configA), ...
    "lora:InvalidStartTime");
verifyError(testCase, @() lora_doppler_piecewise_linear( ...
    uint32(64), 7, geometry.highShiftTimeSec, ...
    geometry.configA, BandwidthHz=0), ...
    "lora:InvalidBandwidth");
end

function cases = approximation_cases(geometry)
scenario = [ ...
    "high_shift"; ...
    "high_rate"; ...
    "high_shift"; ...
    "high_rate"];
sf = [7; 7; 12; 12];
symbol = 2.^(sf-1);
startTimeSec = [ ...
    geometry.highShiftTimeSec; ...
    geometry.highRateTimeSec; ...
    geometry.highShiftTimeSec; ...
    geometry.highRateTimeSec];
cases = table(scenario, sf, symbol, startTimeSec);
end

function phaseRad = trapezoidal_phase(frequencyHz, sampleRateHz)
phaseIncrementRad = pi/sampleRateHz*( ...
    frequencyHz(1:end-1) + frequencyHz(2:end));
phaseRad = [0; cumsum(phaseIncrementRad)];
end

function [exactFft, linearFft] = dechirped_ffts( ...
        exactRx, linearRx, sf)
m = 2^sf;
sampleIndex = (0:m-1).';
baseUpChirp = exp(1i*2*pi*( ...
    sampleIndex.^2/(2*m) - sampleIndex/2));
exactFft = fft(exactRx.*conj(baseUpChirp), m, 1);
linearFft = fft(linearRx.*conj(baseUpChirp), m, 1);
end

function verify_symbol_error_limits( ...
        testCase, result, cases, caseIndex, symbolIndex)
diagnostic = case_diagnostic(cases, caseIndex, symbolIndex);
verifyLessThanOrEqual(testCase, ...
    result.meanAbsErrorHz, 5e-4, diagnostic);
verifyLessThanOrEqual(testCase, ...
    result.maxAbsErrorHz, 1e-3, diagnostic);
verifyLessThanOrEqual(testCase, ...
    result.rmseHz, 6e-4, diagnostic);
verifyLessThanOrEqual(testCase, ...
    result.phaseRmseRad, 2e-5, diagnostic);
end

function diagnostic = case_diagnostic(cases, caseIndex, symbolIndex)
if symbolIndex < 0
    diagnostic = sprintf("scenario=%s, SF=%d", ...
        cases.scenario(caseIndex), cases.sf(caseIndex));
else
    diagnostic = sprintf( ...
        "scenario=%s, SF=%d, symbol_index=%d", ...
        cases.scenario(caseIndex), ...
        cases.sf(caseIndex), symbolIndex);
end
end

function remove_temp_directory(directoryPath)
if isfolder(directoryPath)
    rmdir(directoryPath, "s");
end
end
