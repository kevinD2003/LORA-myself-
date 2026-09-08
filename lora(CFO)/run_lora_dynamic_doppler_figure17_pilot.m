function outputs = run_lora_dynamic_doppler_figure17_pilot(options)
%RUN_LORA_DYNAMIC_DOPPLER_FIGURE17_PILOT 运行可续跑的 Figure 17 粗网格。
%   OUTPUTS = RUN_LORA_DYNAMIC_DOPPLER_FIGURE17_PILOT() 使用论文参考
%   配置调用已验证的完整时域动态 Doppler BER 引擎。每完成一个点即写入
%   checkpoint；本函数不使用 FFT 域 order-statistic、人工 bin 平移或
%   Doppler 补偿，也不生成最终论文 Figure 17。

arguments
    options.OutputDirectory (1, 1) string = string(pwd)
    options.Config (1, 1) struct = ...
        lora_dynamic_doppler_figure17_pilot_config()
end

outputDirectory = options.OutputDirectory;
config = options.Config;
validate_pilot_config(config);
if ~isfolder(outputDirectory)
    mkdir(outputDirectory);
end

resultsCsvPath = fullfile(outputDirectory, ...
    "dynamic_doppler_ber_pilot_results.csv");
diagnosticsCsvPath = fullfile(outputDirectory, ...
    "dynamic_doppler_ber_pilot_diagnostics.csv");
figurePath = fullfile(outputDirectory, ...
    "dynamic_doppler_ber_figure17_pilot.png");
reportPath = fullfile(outputDirectory, ...
    "dynamic_doppler_ber_pilot_report.md");

[results, resumedPointCount] = load_checkpoint( ...
    resultsCsvPath, config);
scenarioNames = string({config.orbitScenarios.name});
numberPoints = numel(scenarioNames)*numel(config.spreadingFactors)* ...
    numel(config.snrDb);
newPointCount = 0;

for scenarioIndex = 1:numel(scenarioNames)
    orbitScenario = scenarioNames(scenarioIndex);
    for sf = config.spreadingFactors
        for snrDb = config.snrDb
            if has_completed_key(results, config, orbitScenario, sf, snrDb)
                fprintf("BER_PILOT resume scenario=%s SF=%d SNR=%.1f dB\n", ...
                    orbitScenario, sf, snrDb);
                resumedPointCount = resumedPointCount + 1;
                continue
            end
            point = simulate_lora_dynamic_doppler_ber_point( ...
                config.profile, orbitScenario, config.timeMode, ...
                config.dopplerModel, sf, snrDb, config);
            results = append_result(results, struct2table(point));
            results = sortrows(results, ...
                {'orbit_scenario', 'sf', 'snr_db'});
            writetable(results, resultsCsvPath);
            newPointCount = newPointCount + 1;
            fprintf("BER_PILOT %d/%d scenario=%s SF=%d SNR=%.1f " + ...
                "BER=%.6g errors=%d bits=%d elapsed=%.3fs\n", ...
                resumedPointCount + newPointCount, numberPoints, ...
                orbitScenario, sf, snrDb, point.ber, point.bit_errors, ...
                point.total_bits, point.elapsed_seconds);
        end
    end
end

validate_complete_grid(results, config, numberPoints);
diagnostics = lora_dynamic_doppler_pilot_diagnostics(results);
writetable(diagnostics, diagnosticsCsvPath);
export_pilot_figure(results, config, figurePath);
write_chinese_report(results, diagnostics, config, reportPath);

outputs = struct( ...
    "results", results, ...
    "diagnostics", diagnostics, ...
    "resultsCsvPath", string(resultsCsvPath), ...
    "diagnosticsCsvPath", string(diagnosticsCsvPath), ...
    "figurePath", string(figurePath), ...
    "reportPath", string(reportPath), ...
    "resumedPointCount", resumedPointCount, ...
    "newPointCount", newPointCount, ...
    "finalFigure17Generated", false);
end

function validate_pilot_config(config)
requiredFields = [ ...
    "profile", "spreadingFactors", "snrDb", "orbitScenarios", ...
    "dopplerModel", "timeMode", "targetBitErrors", ...
    "maxBitsPerPoint", "resume"];
if ~all(isfield(config, requiredFields))
    error("lora:InvalidPilotConfiguration", ...
        "Pilot configuration is missing required fields.");
end
if string(config.profile) ~= "paper_figure17_reference" || ...
        string(config.dopplerModel) ~= "paper_piecewise_linear" || ...
        string(config.timeMode) ~= ...
        "fixed_orbit_start_independent_symbols"
    error("lora:InvalidPilotConfiguration", ...
        "Pilot must use the required reference profile, fixed mode, and paper model.");
end
scenarioNames = string({config.orbitScenarios.name});
if ~isequal(scenarioNames, ...
        ["high_doppler_rate", "high_doppler_shift"])
    error("lora:InvalidPilotConfiguration", ...
        "Pilot scenarios must be high_doppler_rate and high_doppler_shift.");
end
end

function [results, resumedPointCount] = load_checkpoint(resultsCsvPath, config)
results = table();
resumedPointCount = 0;
if ~config.resume || ~isfile(resultsCsvPath)
    return
end
results = readtable(resultsCsvPath, TextType="string");
requiredKeyFields = ["profile", "orbit_scenario", "time_mode", ...
    "doppler_model", "sf", "snr_db"];
if ~all(ismember(requiredKeyFields, ...
        string(results.Properties.VariableNames)))
    error("lora:InvalidPilotCheckpoint", ...
        "The existing pilot checkpoint has no complete result key.");
end
if any_duplicate_keys(results)
    error("lora:DuplicatePilotCheckpoint", ...
        "The existing pilot checkpoint contains duplicate result keys.");
end
end

function duplicate = any_duplicate_keys(results)
keys = results(:, {'profile', 'orbit_scenario', 'time_mode', ...
    'doppler_model', 'sf', 'snr_db'});
duplicate = height(unique(keys, "rows")) ~= height(keys);
end

function found = has_completed_key(results, config, scenario, sf, snrDb)
if isempty(results)
    found = false;
    return
end
found = any(string(results.profile) == string(config.profile) & ...
    string(results.orbit_scenario) == scenario & ...
    string(results.time_mode) == string(config.timeMode) & ...
    string(results.doppler_model) == string(config.dopplerModel) & ...
    double(results.sf) == sf & double(results.snr_db) == snrDb);
end

function results = append_result(results, pointTable)
if isempty(results)
    results = pointTable;
else
    results = [results; pointTable];
end
end

function validate_complete_grid(results, ~, numberPoints)
if height(results) ~= numberPoints || any_duplicate_keys(results)
    error("lora:IncompletePilotGrid", ...
        "Pilot result table does not have one row for every requested point.");
end
if any(results.bit_errors < 0) || any(results.total_bits <= 0) || ...
        any(~isfinite(results.ber)) || ...
        ~all(logical(results.fft_bin_mapping_valid))
    error("lora:InvalidPilotResults", ...
        "Pilot result table contains invalid BER statistics or FFT mapping.");
end
end

function export_pilot_figure(results, config, figurePath)
figureHandle = figure(Visible="off", Color="white", ...
    Position=[100, 100, 1400, 580]);
cleanup = onCleanup(@() close(figureHandle));
layout = tiledlayout(figureHandle, 1, 2, ...
    TileSpacing="compact", Padding="compact");
scenarioNames = ["high_doppler_rate", "high_doppler_shift"];
panelTitles = ["(a) High Doppler Rate", "(b) High Doppler Shift"];
colors = lines(numel(config.spreadingFactors));

for panelIndex = 1:numel(scenarioNames)
    axesHandle = nexttile(layout, panelIndex);
    hold(axesHandle, "on");
    scenarioMask = string(results.orbit_scenario) == scenarioNames(panelIndex);
    for sfIndex = 1:numel(config.spreadingFactors)
        sf = config.spreadingFactors(sfIndex);
        rows = scenarioMask & double(results.sf) == sf;
        subset = sortrows(results(rows, :), "snr_db");
        plotBer = subset.ber;
        zeroMask = subset.bit_errors == 0;
        plotBer(zeroMask) = subset.ber_upper_bound(zeroMask);
        semilogy(axesHandle, subset.snr_db, plotBer, "-o", ...
            Color=colors(sfIndex, :), LineWidth=1.1, MarkerSize=4, ...
            DisplayName=sprintf("SF%d", sf));
        if any(zeroMask)
            semilogy(axesHandle, subset.snr_db(zeroMask), ...
                plotBer(zeroMask), "v", Color=colors(sfIndex, :), ...
                MarkerFaceColor="white", MarkerSize=7, ...
                HandleVisibility="off");
        end
    end
    grid(axesHandle, "on");
    xlabel(axesHandle, "SNR (dB)");
    ylabel(axesHandle, "BER");
    title(axesHandle, panelTitles(panelIndex));
    xlim(axesHandle, [min(config.snrDb), max(config.snrDb)]);
    ylim(axesHandle, [1e-7, 1]);
    legend(axesHandle, Location="southwest", NumColumns=2);
end
sgtitle(layout, "Dynamic Doppler BER pilot: raw Monte Carlo results");
exportgraphics(figureHandle, figurePath, Resolution=200);
clear cleanup
end

function write_chinese_report(results, diagnostics, config, reportPath)
fileId = fopen(reportPath, "w", "n", "UTF-8");
if fileId < 0
    error("lora:ReportOpenFailed", "Cannot open the pilot report.");
end
cleanup = onCleanup(@() fclose(fileId));

fprintf(fileId, "# Figure 17 动态 Doppler BER 粗网格预检报告\n\n");
fprintf(fileId, "- profile：`%s`\n", config.profile);
fprintf(fileId, "- 模型：`%s`\n", config.dopplerModel);
fprintf(fileId, "- 时间模式：`%s`\n", config.timeMode);
fprintf(fileId, "- 网格点数：%d\n", height(results));
fprintf(fileId, "- 原始 Monte Carlo 结果：未平滑、未拟合、未作 SNR 平移。\n");
fprintf(fileId, "- 零错误点：CSV 保持 BER=0；图中空心下三角表示一错误上界。\n");
fprintf(fileId, "- 最终 Figure 17：本轮未生成。\n\n");
fprintf(fileId, "## 完整性检查\n\n");
fprintf(fileId, "- NaN/Inf：%s\n", chinese_boolean(any(~isfinite(results.ber))));
fprintf(fileId, "- 空批：%s\n", chinese_boolean(any(results.monte_carlo_batches < 1)));
fprintf(fileId, "- FFT bin 映射全部有效：%s\n", ...
    chinese_boolean(all(logical(results.fft_bin_mapping_valid))));
fprintf(fileId, "- 最大批复采样数：%d\n", ...
    max(results.peak_complex_samples_per_batch));
fprintf(fileId, "- 最大 MATLAB 内存增量：%.2f MiB\n", ...
    max(results.peak_matlab_memory_delta_bytes)/2^20);
fprintf(fileId, "- 最慢单点：%.3f s\n\n", max(results.elapsed_seconds));
fprintf(fileId, "## 趋势诊断\n\n");
fprintf(fileId, "| 场景 | SF | -30 dB BER | -10 dB BER | 10 dB BER | 严格单调 | 高 SNR floor | 结论 |\n");
fprintf(fileId, "|---|---:|---:|---:|---:|---|---:|---|\n");
for rowIndex = 1:height(diagnostics)
    row = diagnostics(rowIndex, :);
    fprintf(fileId, "| %s | %d | %.6g | %.6g | %.6g | %s | %.6g | %s |\n", ...
        row.orbit_scenario, row.sf, row.ber_low_snr, row.ber_mid_snr, ...
        row.ber_high_snr, chinese_boolean(row.strict_monotonic_improvement), ...
        row.estimated_high_snr_ber_floor, row.trend_assessment);
end

requiresInvestigation = diagnostics.trend_assessment == ...
    "investigate_before_final_scan";
if any(requiresInvestigation)
    fprintf(fileId, "\n## 暂停最终扫描\n\n");
    fprintf(fileId, "以下组合需先排查：\n\n");
    for rowIndex = find(requiresInvestigation).'
        fprintf(fileId, "- %s SF%d：%s\n", ...
            diagnostics.orbit_scenario(rowIndex), diagnostics.sf(rowIndex), ...
            diagnostics.required_checklist(rowIndex));
    end
else
    fprintf(fileId, "\n## 结论\n\n粗网格未触发最终扫描前的强制排查标记。\n");
end
clear cleanup
end

function text = chinese_boolean(value)
if value
    text = "是";
else
    text = "否";
end
end
