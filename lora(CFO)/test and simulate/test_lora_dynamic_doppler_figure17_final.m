function tests = test_lora_dynamic_doppler_figure17_final
%TEST_LORA_DYNAMIC_DOPPLER_FIGURE17_FINAL 正式扫描测试。
tests = functiontests(localfunctions);
end

function testFormalConfigDefinesRequiredGridAndStops(testCase)
% 网格或停止条件偏离正式声明时，此测试必须失败。
config = lora_dynamic_doppler_figure17_config();

verifyEqual(testCase, config.profile, "paper_figure17_reference");
verifyEqual(testCase, config.spreadingFactors, 5:12);
verifyEqual(testCase, config.snrDb, -30:1:10);
verifyEqual(testCase, config.targetBitErrors, 2000);
verifyEqual(testCase, config.maxBitsPerPoint, 5e7);
verifyEqual(testCase, config.dopplerModel, "paper_piecewise_linear");
verifyEqual(testCase, config.timeMode, ...
    "fixed_orbit_start_independent_symbols");
end

function testFormalZeroErrorUsesNanAndNamedLevels(testCase)
% 把零错误写成零 BER 或误称一错误水平时，此测试必须失败。
raw = struct("bit_errors", 0, "total_bits", 1e6, "ber", 0);
formal = lora_dynamic_doppler_formalize_result(raw);

verifyTrue(testCase, isnan(formal.ber));
verifyEqual(testCase, formal.raw_ber, 0, "AbsTol", 0);
verifyEqual(testCase, formal.one_count_level, 1e-6, "AbsTol", eps);
verifyEqual(testCase, formal.upper_95_approx, ...
    -log(0.05)/1e6, "AbsTol", eps);
end

function testFormalNonzeroErrorKeepsRawBer(testCase)
% 有错误时若错误地变为 NaN 或改变原始 BER，此测试必须失败。
raw = struct("bit_errors", 12, "total_bits", 1000, "ber", 0.012);
formal = lora_dynamic_doppler_formalize_result(raw);

verifyEqual(testCase, formal.ber, 0.012, "AbsTol", eps);
verifyEqual(testCase, formal.raw_ber, 0.012, "AbsTol", eps);
verifyEqual(testCase, formal.one_count_level, 0.001, "AbsTol", eps);
end

function testPairedExactUsesSameStreamsAndCommonBatches(testCase)
% 若两模型读取不同符号/噪声或未共同推进批次，此测试必须失败。
config = lora_dynamic_doppler_figure17_config();
config.targetBitErrors = 4;
config.maxBitsPerPoint = 200;
config.maxComplexSamplesPerBatch = 1024;
config.maxSymbolsPerBatch = 8;
paired = simulate_lora_dynamic_doppler_paired_point( ...
    "high_doppler_rate", 5, 0, config);

verifyEqual(testCase, paired.paper.seed_symbols, paired.exact.seed_symbols);
verifyEqual(testCase, paired.paper.seed_noise, paired.exact.seed_noise);
verifyEqual(testCase, paired.paper.total_bits, paired.exact.total_bits);
verifyTrue(testCase, isfinite(paired.rms_phase_error_rad));
verifyTrue(testCase, isfinite(paired.max_doppler_error_hz));
verifyTrue(testCase, islogical(paired.statistically_consistent));
end

function testPairedExactCachesFixedStartSymbolTraces(testCase)
config = lora_dynamic_doppler_figure17_config();
config.targetBitErrors = 4;
config.maxBitsPerPoint = 200;
config.maxComplexSamplesPerBatch = 1024;
config.maxSymbolsPerBatch = 8;
paired = simulate_lora_dynamic_doppler_paired_point( ...
    "high_doppler_rate", 5, 0, config);

verifyTrue(testCase, paired.trace_cache_enabled);
verifyEqual(testCase, paired.trace_cache_entries, 2^5);
verifyEqual(testCase, paired.paper.seed_symbols, paired.exact.seed_symbols);
verifyEqual(testCase, paired.paper.seed_noise, paired.exact.seed_noise);
end

function testPairedExactTreatsIdenticalZeroBerAsConsistent(testCase)
config = lora_dynamic_doppler_figure17_config();
config.targetBitErrors = 4;
config.maxBitsPerPoint = 160;
config.maxComplexSamplesPerBatch = 1024;
config.maxSymbolsPerBatch = 8;
paired = simulate_lora_dynamic_doppler_paired_point( ...
    "high_doppler_rate", 5, 100, config);

verifyEqual(testCase, paired.paper.bit_errors, 0);
verifyEqual(testCase, paired.exact.bit_errors, 0);
verifyEqual(testCase, paired.difference_ber, 0, "AbsTol", 0);
verifyEqual(testCase, paired.consistency_threshold, 0, "AbsTol", 0);
verifyTrue(testCase, paired.statistically_consistent);
end

function testFormalRunnerResumesCompletedMainAndExactCsv(testCase)
outputDirectory = string(tempname); mkdir(outputDirectory);
cleanup = onCleanup(@() rmdir(outputDirectory, "s"));
config = lora_dynamic_doppler_figure17_config();
config.spreadingFactors = 5;
config.snrDb = [-30 -10 0 10];
config.targetBitErrors = 2;
config.maxBitsPerPoint = 40;
config.maxComplexSamplesPerBatch = 1024;
config.maxSymbolsPerBatch = 8;

mainPath = fullfile(outputDirectory, "dynamic_doppler_ber_results.csv");
exactPath = fullfile(outputDirectory, ...
    "dynamic_doppler_ber_exact_validation.csv");
writetable(make_complete_main_results(config), mainPath);
writetable(make_complete_exact_results(), exactPath);

outputs = run_lora_dynamic_doppler_figure17( ...
    OutputDirectory=outputDirectory, Config=config, RunExactValidation=true);

verifyEqual(testCase, height(outputs.results), 8);
verifyTrue(testCase, ismember("resume_marker", ...
    string(outputs.results.Properties.VariableNames)));
verifyEqual(testCase, height(outputs.exactValidation), 24);
verifyTrue(testCase, ismember("seed_symbols_piecewise", ...
    string(outputs.exactValidation.Properties.VariableNames)));
verifyTrue(testCase, ismember("seed_noise_exact", ...
    string(outputs.exactValidation.Properties.VariableNames)));
verifyTrue(testCase, all(outputs.exactValidation.statistically_consistent));
clear cleanup
end

function testFormalRunnerWritesRequestedArtifacts(testCase)
% 缺少正式 CSV、图、metadata 或报告时，此测试必须失败。
outputDirectory = string(tempname); mkdir(outputDirectory);
cleanup = onCleanup(@() rmdir(outputDirectory, "s"));
config = lora_dynamic_doppler_figure17_config();
config.spreadingFactors = 5;
config.snrDb = [-30 -10 0 10];
config.targetBitErrors = 4;
config.maxBitsPerPoint = 200;
config.maxComplexSamplesPerBatch = 1024;
config.maxSymbolsPerBatch = 8;
outputs = run_lora_dynamic_doppler_figure17( ...
    OutputDirectory=outputDirectory, Config=config, RunExactValidation=false);
verifyEqual(testCase, height(outputs.results), 8);
verifyTrue(testCase, isfile(outputs.resultsCsvPath));
verifyTrue(testCase, isfile(outputs.figurePngPath));
verifyTrue(testCase, isfile(outputs.figurePdfPath));
verifyTrue(testCase, isfile(outputs.metadataJsonPath));
verifyTrue(testCase, isfile(outputs.reportPath));
verifyTrue(testCase, any(isnan(outputs.results.ber) | outputs.results.ber >= 0));
clear cleanup
end

function results = make_complete_main_results(config)
scenarioNames = string({config.orbitScenarios.name});
scenario = strings(0, 1);
sf = zeros(0, 1);
snrDb = zeros(0, 1);
for scenarioName = scenarioNames
    for spreadingFactor = config.spreadingFactors
        for snrValue = config.snrDb
            scenario(end + 1, 1) = scenarioName; %#ok<AGROW>
            sf(end + 1, 1) = spreadingFactor; %#ok<AGROW>
            snrDb(end + 1, 1) = snrValue; %#ok<AGROW>
        end
    end
end
rowCount = numel(sf);
results = table(scenario, sf, snrDb, 0.25*ones(rowCount, 1), ...
    0.25*ones(rowCount, 1), 1e-6*ones(rowCount, 1), ...
    2e-6*ones(rowCount, 1), (1:rowCount)', ...
    'VariableNames', {'orbit_scenario', 'sf', 'snr_db', 'ber', ...
    'raw_ber', 'one_count_level', 'upper_95_approx', ...
    'resume_marker'});
end

function exact = make_complete_exact_results()
scenarios = ["high_doppler_rate", "high_doppler_shift"];
spreadingFactors = [5 7 8 12];
snrValues = [-10 0 10];
orbitScenario = strings(0, 1);
sf = zeros(0, 1);
snrDb = zeros(0, 1);
for scenario = scenarios
    for spreadingFactor = spreadingFactors
        for snrValue = snrValues
            orbitScenario(end + 1, 1) = scenario; %#ok<AGROW>
            sf(end + 1, 1) = spreadingFactor; %#ok<AGROW>
            snrDb(end + 1, 1) = snrValue; %#ok<AGROW>
        end
    end
end
rowCount = numel(sf);
exact = table(orbitScenario, sf, snrDb, ...
    0.1*ones(rowCount, 1), 0.1*ones(rowCount, 1), ...
    0.2*ones(rowCount, 1), 0.2*ones(rowCount, 1), ...
    ones(rowCount, 1), ones(rowCount, 1), ...
    10*ones(rowCount, 1), 10*ones(rowCount, 1), ...
    true(rowCount, 1), zeros(rowCount, 1), zeros(rowCount, 1), ...
    zeros(rowCount, 1), zeros(rowCount, 1), ones(rowCount, 1), ...
    true(rowCount, 1), ...
    'VariableNames', {'orbit_scenario', 'sf', 'snr_db', ...
    'ber_piecewise', 'ber_exact', 'ser_piecewise', 'ser_exact', ...
    'bit_errors_piecewise', 'bit_errors_exact', ...
    'total_bits_piecewise', 'total_bits_exact', ...
    'noiseless_fft_peak_equal', 'fft_energy_relative_error', ...
    'max_doppler_error_hz', 'rms_phase_error_rad', ...
    'abs_ber_difference', 'consistency_threshold', ...
    'statistically_consistent'});
end
