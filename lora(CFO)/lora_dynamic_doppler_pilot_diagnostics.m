function diagnostics = lora_dynamic_doppler_pilot_diagnostics(results)
%LORA_DYNAMIC_DOPPLER_PILOT_DIAGNOSTICS 汇总 BER 粗网格的趋势诊断。
%   DIAGNOSTICS = LORA_DYNAMIC_DOPPLER_PILOT_DIAGNOSTICS(RESULTS) 将逐点
%   原始 Monte Carlo 表按场景和 SF 汇总。该函数不修改 RESULTS 中的 BER，
%   仅生成趋势和数值一致性诊断。

requiredFields = [ ...
    "orbit_scenario", "sf", "snr_db", "ber", ...
    "orbit_initial_doppler_hz", ...
    "orbit_initial_doppler_rate_hz_per_s", ...
    "half_bin_tolerance_hz", "normalized_initial_bin_offset", ...
    "normalized_rate_sweep_bins"];
if ~istable(results) || ~all(ismember(requiredFields, ...
        string(results.Properties.VariableNames)))
    error("lora:InvalidPilotResults", ...
        "Pilot results are missing required diagnostic fields.");
end
if any(~isfinite(results.ber))
    error("lora:NonfinitePilotBer", ...
        "Pilot BER values must be finite before trend diagnosis.");
end

scenarioValues = string(results.orbit_scenario);
sfValues = double(results.sf);
keys = unique(table(scenarioValues, sfValues, ...
    'VariableNames', {'orbit_scenario', 'sf'}), "rows", "stable");
numberRows = height(keys);

orbitInitialDopplerHz = zeros(numberRows, 1);
orbitInitialRateHzPerSec = zeros(numberRows, 1);
halfBinToleranceHz = zeros(numberRows, 1);
normalizedInitialBinOffset = zeros(numberRows, 1);
normalizedRateSweepBins = zeros(numberRows, 1);
berLowSnr = zeros(numberRows, 1);
berMidSnr = zeros(numberRows, 1);
berHighSnr = zeros(numberRows, 1);
strictMonotonic = false(numberRows, 1);
tolerantMonotonic = false(numberRows, 1);
violationCount = zeros(numberRows, 1);
highSnrFloor = zeros(numberRows, 1);
trendAssessment = strings(numberRows, 1);
requiredChecklist = strings(numberRows, 1);

for rowIndex = 1:numberRows
    rowMask = scenarioValues == keys.orbit_scenario(rowIndex) & ...
        sfValues == keys.sf(rowIndex);
    subset = sortrows(results(rowMask, :), "snr_db");
    require_snr_points(subset.snr_db, keys.orbit_scenario(rowIndex), ...
        keys.sf(rowIndex));
    differences = diff(subset.ber);
    tolerances = 1.96*sqrt( ...
        adjacent_ber_variances(subset).^2 + ...
        adjacent_ber_variances(subset, true).^2);

    orbitInitialDopplerHz(rowIndex) = subset.orbit_initial_doppler_hz(1);
    orbitInitialRateHzPerSec(rowIndex) = ...
        subset.orbit_initial_doppler_rate_hz_per_s(1);
    halfBinToleranceHz(rowIndex) = subset.half_bin_tolerance_hz(1);
    normalizedInitialBinOffset(rowIndex) = ...
        subset.normalized_initial_bin_offset(1);
    normalizedRateSweepBins(rowIndex) = ...
        subset.normalized_rate_sweep_bins(1);
    berLowSnr(rowIndex) = ber_at_snr(subset, -30);
    berMidSnr(rowIndex) = ber_at_snr(subset, -10);
    berHighSnr(rowIndex) = ber_at_snr(subset, 10);
    strictMonotonic(rowIndex) = all(differences <= 0);
    tolerantMonotonic(rowIndex) = all(differences <= tolerances);
    violationCount(rowIndex) = nnz(differences > 0);
    highSnrFloor(rowIndex) = median(subset.ber(ismember( ...
        subset.snr_db, [6, 8, 10])));
    [trendAssessment(rowIndex), requiredChecklist(rowIndex)] = ...
        assess_trend(keys.orbit_scenario(rowIndex), keys.sf(rowIndex), ...
        berLowSnr(rowIndex), berHighSnr(rowIndex), ...
        tolerantMonotonic(rowIndex));
end

diagnostics = table( ...
    keys.orbit_scenario, keys.sf, orbitInitialDopplerHz, ...
    orbitInitialRateHzPerSec, halfBinToleranceHz, ...
    normalizedInitialBinOffset, normalizedRateSweepBins, ...
    berLowSnr, berMidSnr, berHighSnr, strictMonotonic, ...
    tolerantMonotonic, violationCount, highSnrFloor, trendAssessment, ...
    requiredChecklist, 'VariableNames', { ...
    'orbit_scenario', 'sf', 'initial_doppler_hz', ...
    'doppler_rate_hz_per_s', 'half_bin_tolerance_hz', ...
    'normalized_initial_bin_offset', 'normalized_rate_sweep_bins', ...
    'ber_low_snr', 'ber_mid_snr', 'ber_high_snr', ...
    'strict_monotonic_improvement', ...
    'mc_tolerance_monotonic_improvement', 'monotonic_violation_count', ...
    'estimated_high_snr_ber_floor', 'trend_assessment', ...
    'required_checklist'});
end

function require_snr_points(snrDb, scenario, sf)
requiredSnrDb = [-30, -10, 6, 8, 10];
if ~all(ismember(requiredSnrDb, snrDb))
    error("lora:IncompletePilotGrid", ...
        "Scenario %s SF%d is missing required SNR diagnostic points.", ...
        scenario, sf);
end
end

function value = ber_at_snr(subset, snrDb)
value = subset.ber(subset.snr_db == snrDb);
end

function standardErrors = adjacent_ber_variances(subset, useRightValue)
if nargin < 2
    useRightValue = false;
end
ber = subset.ber;
if ismember("total_bits", string(subset.Properties.VariableNames))
    totalBits = subset.total_bits;
else
    totalBits = ones(size(ber));
end
if useRightValue
    ber = ber(2:end);
    totalBits = totalBits(2:end);
else
    ber = ber(1:end-1);
    totalBits = totalBits(1:end-1);
end
effectiveBer = max(ber, 1./max(totalBits, 1));
standardErrors = sqrt(effectiveBer.*(1 - min(effectiveBer, 1))./ ...
    max(totalBits, 1));
end

function [assessment, checklist] = assess_trend( ...
        scenario, sf, berLowSnr, berHighSnr, tolerantMonotonic)
checklist = "";
if scenario == "high_doppler_rate" && sf <= 7
    if tolerantMonotonic && berHighSnr < berLowSnr
        assessment = "expected_improvement";
    else
        assessment = "investigate_before_final_scan";
        checklist = investigation_checklist();
    end
elseif scenario == "high_doppler_rate"
    assessment = "floor_or_limited_improvement_diagnostic";
elseif scenario == "high_doppler_shift" && berHighSnr >= 0.05
    assessment = "expected_poor_ber";
else
    assessment = "investigate_before_final_scan";
    checklist = investigation_checklist();
end
end

function checklist = investigation_checklist()
checklist = strjoin([ ...
    "SNR/AWGN 方差", "carrier/baseband Hz", "radians/degrees", ...
    "2*pi 相位因子", "cd Hz/s 单位", "每秒/每采样", ...
    "chirp wrap Delta_f_k 符号", "FFT bin 映射方向", ...
    "high-rate/high-shift 场景", "连续轨道时间推进", ...
    "意外 Doppler 补偿", "B=125 kHz 误配"], "; ");
end
