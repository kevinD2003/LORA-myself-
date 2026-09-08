function tests = test_lora_dynamic_doppler_figure17_pilot
%TEST_LORA_DYNAMIC_DOPPLER_FIGURE17_PILOT 粗网格预检测试。
tests = functiontests(localfunctions);
end

function testPilotConfigUsesRequiredReferenceGrid(testCase)
% 缺少引用配置、网格或停止条件时，此测试必须失败。
config = lora_dynamic_doppler_figure17_pilot_config();

verifyEqual(testCase, config.profile, "paper_figure17_reference");
verifyEqual(testCase, config.spreadingFactors, 5:12);
verifyEqual(testCase, config.snrDb, -30:2:10);
verifyEqual(testCase, config.targetBitErrors, 500);
verifyEqual(testCase, config.maxBitsPerPoint, 1e7);
verifyEqual(testCase, config.dopplerModel, ...
    "paper_piecewise_linear");
verifyEqual(testCase, config.timeMode, ...
    "fixed_orbit_start_independent_symbols");
end

function testPilotConfigUsesFormulaDerivedScenarioTimes(testCase)
% 错用论文近似常数或将 high-rate/high-shift 对调时，此测试必须失败。
config = lora_dynamic_doppler_figure17_pilot_config();
geometry = lora_figure17_geometry();
names = string({config.orbitScenarios.name});

verifyEqual(testCase, ...
    config.orbitScenarios(names == "high_doppler_rate").startTimeSec, ...
    geometry.sharedFirstSec(2), "AbsTol", 1e-12);
verifyEqual(testCase, ...
    config.orbitScenarios(names == "high_doppler_shift").startTimeSec, ...
    geometry.sharedFirstSec(1), "AbsTol", 1e-12);
end

function testDiagnosticsAggregateRawTrendMetrics(testCase)
% 若诊断未按原始 BER 或错误选择高 SNR 点，该测试必须失败。
diagnostics = lora_dynamic_doppler_pilot_diagnostics( ...
    synthetic_pilot_results());

verifyEqual(testCase, height(diagnostics), 2);
verifyTrue(testCase, diagnostics.strict_monotonic_improvement(1));
verifyEqual(testCase, diagnostics.ber_low_snr(1), 0.3, "AbsTol", eps);
verifyEqual(testCase, diagnostics.ber_mid_snr(1), 0.2, "AbsTol", eps);
verifyEqual(testCase, diagnostics.ber_high_snr(1), 6e-4, "AbsTol", eps);
verifyEqual(testCase, diagnostics.estimated_high_snr_ber_floor(1), ...
    8e-4, "AbsTol", eps);
verifyEqual(testCase, diagnostics.normalized_initial_bin_offset(1), ...
    0.073, "AbsTol", eps);
end

function testDiagnosticsFlagsNonmonotonicRawBerWithoutNonfiniteValues(testCase)
% 若 BER 反弹未标出或零错误令诊断出现 NaN/Inf，该测试必须失败。
results = synthetic_pilot_results();
results.ber(2) = 0;
results.ber(3) = 0.01;
diagnostics = lora_dynamic_doppler_pilot_diagnostics(results);

verifyFalse(testCase, diagnostics.strict_monotonic_improvement(1));
verifyGreaterThan(testCase, diagnostics.monotonic_violation_count(1), 0);
verifyTrue(testCase, all(isfinite( ...
    diagnostics.estimated_high_snr_ber_floor)));
end

function testPilotRunnerWritesCheckpointDiagnosticsAndFigure(testCase)
% 若 runner 未保存原始计数、诊断或图像，此测试必须失败。
outputDirectory = string(tempname);
mkdir(outputDirectory);
cleanup = onCleanup(@() rmdir(outputDirectory, "s"));
config = tiny_pilot_config();

outputs = run_lora_dynamic_doppler_figure17_pilot( ...
    OutputDirectory=outputDirectory, Config=config);

verifyEqual(testCase, height(outputs.results), 10);
verifyEqual(testCase, height(outputs.diagnostics), 2);
verifyTrue(testCase, isfile(outputs.resultsCsvPath));
verifyTrue(testCase, isfile(outputs.diagnosticsCsvPath));
verifyTrue(testCase, isfile(outputs.figurePath));
savedResults = readtable(outputs.resultsCsvPath, TextType="string");
verifyEqual(testCase, height(savedResults), 10);
verifyTrue(testCase, all(savedResults.bit_errors >= 0));
verifyTrue(testCase, all(savedResults.total_bits > 0));
verifyTrue(testCase, all(savedResults.fft_bin_mapping_valid));
clear cleanup
end

function testPilotRunnerResumeSkipsCompletedKeys(testCase)
% 若同一配置重复执行时重新仿真已完成点，此测试必须失败。
outputDirectory = string(tempname);
mkdir(outputDirectory);
cleanup = onCleanup(@() rmdir(outputDirectory, "s"));
config = tiny_pilot_config();
first = run_lora_dynamic_doppler_figure17_pilot( ...
    OutputDirectory=outputDirectory, Config=config);
second = run_lora_dynamic_doppler_figure17_pilot( ...
    OutputDirectory=outputDirectory, Config=config);

verifyEqual(testCase, second.resumedPointCount, height(first.results));
verifyEqual(testCase, second.results.bit_errors, first.results.bit_errors);
verifyEqual(testCase, second.results.total_bits, first.results.total_bits);
clear cleanup
end

function results = synthetic_pilot_results()
snrDb = [-30; -10; 6; 8; 10];
rateBer = [0.3; 0.2; 1e-3; 8e-4; 6e-4];
shiftBer = [0.48; 0.47; 0.46; 0.46; 0.45];
results = table( ...
    [repmat("high_doppler_rate", 5, 1); ...
     repmat("high_doppler_shift", 5, 1)], ...
    repmat(5, 10, 1), ...
    repmat(snrDb, 2, 1), ...
    [rateBer; shiftBer], ...
    [repmat(571, 5, 1); repmat(18600, 5, 1)], ...
    [repmat(-243, 5, 1); repmat(5.4, 5, 1)], ...
    repmat(3906.25, 10, 1), ...
    [repmat(0.073, 5, 1); repmat(2.5, 5, 1)], ...
    [repmat(-4e-6, 5, 1); repmat(1e-6, 5, 1)], ...
    'VariableNames', { ...
    'orbit_scenario', 'sf', 'snr_db', 'ber', ...
    'orbit_initial_doppler_hz', ...
    'orbit_initial_doppler_rate_hz_per_s', ...
    'half_bin_tolerance_hz', 'normalized_initial_bin_offset', ...
    'normalized_rate_sweep_bins'});
end

function config = tiny_pilot_config()
config = lora_dynamic_doppler_figure17_pilot_config();
config.spreadingFactors = 5;
config.snrDb = [-30, -10, 6, 8, 10];
config.targetBitErrors = 2;
config.maxBitsPerPoint = 200;
config.maxComplexSamplesPerBatch = 1024;
config.maxSymbolsPerBatch = 8;
end
