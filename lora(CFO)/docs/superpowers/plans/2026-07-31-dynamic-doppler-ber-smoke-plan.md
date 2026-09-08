# Dynamic Doppler BER Smoke Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 复用前四轮轨道与 Doppler 实现，建立完整时域动态 Doppler BER 引擎，实际运行 24 个 smoke 点并生成中文报告。

**Architecture:** 先把 `D:\codex\lora(CFO)` 中已经通过 33 项测试的 MATLAB 源码原样迁入当前 Git 分支，再新增配置、单点完整时域 Monte Carlo、smoke runner 和测试。场景始终由 `lora_figure17_geometry` 的 shared visibility window 推导；Doppler 相位始终由现有 `lora_doppler_piecewise_linear` 的 linear/exact 字段产生。

**Tech Stack:** MATLAB R2022a、`matlab.unittest`、复基带 LoRa CSS、Git、PowerShell。

## Global Constraints

- 工作分支固定为 `codex/dynamic-doppler-ber-smoke`，不得在 `main` 上实现。
- 不重建或复制第二套轨道、可见窗口、场景选择、瞬时频率或 Doppler 函数。
- 不修改原 `lora_css_modulate`、`lora_css_demodulate`、`simulate_lora_css_awgn_point` 的行为。
- 动态 BER 不得调用 AWGN order-statistic 主算法。
- 动态 BER 必须执行完整时域 `waveform -> Doppler phase -> AWGN -> dechirp -> FFT`。
- 主 smoke 模型为 `paper_piecewise_linear`；保留 `exact_orbit_sampled` 交叉验证。
- 主 smoke 时间模式为 `fixed_orbit_start_independent_symbols`。
- `continuous_symbol_sequence` 只能标记为诊断模式。
- `maxComplexSamplesPerBatch=2e6`，批大小由 `floor(limit/M)` 自动得到并受 `maxSymbolsPerBatch=4096` 限制。
- 本轮不生成最终 Figure 17。
- Markdown、TXT、设计、计划和审查记录使用中文。

---

### Task 1: 迁入并验证前四轮唯一 Doppler 实现

**Files:**
- Create from validated source: `lora_orbit_doppler_config.m`
- Create from validated source: `lora_orbit_doppler_trajectory.m`
- Create from validated source: `lora_visibility_window.m`
- Create from validated source: `lora_figure17_geometry.m`
- Create from validated source: `lora_symbol_instantaneous_frequency.m`
- Create from validated source: `apply_lora_dynamic_doppler.m`
- Create from validated source: `lora_doppler_piecewise_linear.m`
- Create from validated source: `lora_css_demodulate_dynamic_channel.m`
- Create from validated source: `run_lora_doppler_figure3.m`
- Create from validated source: `run_lora_doppler_approx_validation.m`
- Create from validated source: `test_lora_dynamic_doppler.m`
- Create from validated source: `test_lora_dynamic_channel.m`
- Create from validated source: `test_lora_doppler_approximation.m`

**Interfaces:**
- Consumes: 已验证目录 `D:\codex\lora(CFO)` 中的 13 个 MATLAB 文件。
- Produces: 仓库内唯一的前四轮轨道、Doppler、动态信道和测试接口。

- [ ] **Step 1: 记录源文件 SHA-256**

Run:

```powershell
$source = 'D:\codex\lora(CFO)'
$names = @(
  'lora_orbit_doppler_config.m',
  'lora_orbit_doppler_trajectory.m',
  'lora_visibility_window.m',
  'lora_figure17_geometry.m',
  'lora_symbol_instantaneous_frequency.m',
  'apply_lora_dynamic_doppler.m',
  'lora_doppler_piecewise_linear.m',
  'lora_css_demodulate_dynamic_channel.m',
  'run_lora_doppler_figure3.m',
  'run_lora_doppler_approx_validation.m',
  'test_lora_dynamic_doppler.m',
  'test_lora_dynamic_channel.m',
  'test_lora_doppler_approximation.m'
)
Get-FileHash -Algorithm SHA256 -LiteralPath (
  $names | ForEach-Object { Join-Path $source $_ }
)
```

Expected: 13 个非空哈希。

- [ ] **Step 2: 原样复制已验证文件**

Run:

```powershell
foreach ($name in $names) {
  Copy-Item -LiteralPath (Join-Path $source $name) `
    -Destination (Join-Path (Get-Location) $name)
}
```

Expected: 当前分支根目录新增 13 个 MATLAB 文件，不改动 AWGN 文件。

- [ ] **Step 3: 比较迁入前后哈希**

Run:

```powershell
$sourceHash = @{}
foreach ($name in $names) {
  $sourceHash[$name] = (Get-FileHash -Algorithm SHA256 `
    -LiteralPath (Join-Path $source $name)).Hash
}
foreach ($name in $names) {
  $destinationHash = (Get-FileHash -Algorithm SHA256 `
    -LiteralPath (Join-Path (Get-Location) $name)).Hash
  if ($destinationHash -ne $sourceHash[$name]) {
    throw "Hash mismatch: $name"
  }
}
```

Expected: 无哈希不一致异常。

- [ ] **Step 4: 运行前四轮 33 项测试**

Run:

```powershell
& 'E:\Matlab2022\MATLAB2022\bin\matlab.exe' -batch `
  "files={'test_lora_dynamic_doppler.m','test_lora_dynamic_channel.m','test_lora_doppler_approximation.m'}; parts=cell(size(files)); for k=1:numel(files), parts{k}=matlab.unittest.TestSuite.fromFile(files{k}); end; r=run([parts{:}]); fprintf('PRIOR total=%d passed=%d failed=%d incomplete=%d\n',numel(r),sum([r.Passed]),sum([r.Failed]),sum([r.Incomplete])); assert(all([r.Passed]));"
```

Expected: `PRIOR total=33 passed=33 failed=0 incomplete=0`。

- [ ] **Step 5: 提交迁入**

```powershell
git add -- *.m
git commit -m "feat: import validated dynamic Doppler models"
```

---

### Task 2: 配置与公式推导场景

**Files:**
- Create: `lora_dynamic_doppler_ber_config.m`
- Create: `test_lora_dynamic_doppler_ber.m`

**Interfaces:**
- Consumes: `geometry = lora_figure17_geometry()`.
- Produces: `config = lora_dynamic_doppler_ber_config()`，包含 24 点 smoke 轴、shared-window 场景、批处理、停止条件和双随机种子。

- [ ] **Step 1: 写配置 RED 测试**

在 `test_lora_dynamic_doppler_ber.m` 中先创建测试入口并加入：

```matlab
function tests = test_lora_dynamic_doppler_ber
tests = functiontests(localfunctions);
end

function testConfigDefinesRequiredSmokeGrid(testCase)
config = lora_dynamic_doppler_ber_config();
verifyEqual(testCase, config.spreadingFactors, [5, 7, 8, 12]);
verifyEqual(testCase, config.snrDb, [-10, 0, 10]);
verifyEqual(testCase, string({config.orbitScenarios.name}), ...
    ["high_doppler_rate", "high_doppler_shift"]);
verifyEqual(testCase, config.dopplerModel, "paper_piecewise_linear");
verifyEqual(testCase, config.timeMode, ...
    "fixed_orbit_start_independent_symbols");
verifyEqual(testCase, config.targetBitErrors, 200);
verifyEqual(testCase, config.maxBitsPerPoint, 2e6);
verifyEqual(testCase, config.maxComplexSamplesPerBatch, 2e6);
verifyEqual(testCase, config.maxSymbolsPerBatch, 4096);
verifyEqual(testCase, ...
    numel(config.spreadingFactors)*numel(config.snrDb)* ...
    numel(config.orbitScenarios), 24);
end

function testConfigUsesFormulaDerivedSharedWindow(testCase)
config = lora_dynamic_doppler_ber_config();
geometry = lora_figure17_geometry();
names = string({config.orbitScenarios.name});
rate = config.orbitScenarios(names == "high_doppler_rate");
shift = config.orbitScenarios(names == "high_doppler_shift");
verifyEqual(testCase, rate.startTimeSec, geometry.sharedFirstSec(2), ...
    "AbsTol", 1e-12);
verifyEqual(testCase, shift.startTimeSec, geometry.sharedFirstSec(1), ...
    "AbsTol", 1e-12);
verifyNotEqual(testCase, shift.startTimeSec, ...
    geometry.paperReportedApproximateHighShiftTimeSec);
verifyNotEqual(testCase, rate.startTimeSec, ...
    geometry.paperReportedApproximateHighRateTimeSec);
end
```

- [ ] **Step 2: 运行 RED**

Run:

```powershell
& 'E:\Matlab2022\MATLAB2022\bin\matlab.exe' -batch `
  "r=run(matlab.unittest.TestSuite.fromFile('test_lora_dynamic_doppler_ber.m')); fprintf('CONFIG_RED passed=%d failed=%d incomplete=%d\n',sum([r.Passed]),sum([r.Failed]),sum([r.Incomplete])); assert(any([r.Failed]));"
```

Expected: 因 `lora_dynamic_doppler_ber_config` 未定义而失败。

- [ ] **Step 3: 实现最小配置**

`lora_dynamic_doppler_ber_config.m` 的核心内容：

```matlab
function config = lora_dynamic_doppler_ber_config()
geometry = lora_figure17_geometry();
config = struct( ...
    "profile", "figure17_smoke", ...
    "bandwidthHz", 250e3, ...
    "spreadingFactors", [5, 7, 8, 12], ...
    "snrDb", [-10, 0, 10], ...
    "orbitScenarios", struct( ...
        "name", {"high_doppler_rate", "high_doppler_shift"}, ...
        "startTimeSec", {geometry.highRateTimeSec, ...
            geometry.highShiftTimeSec}), ...
    "dopplerModel", "paper_piecewise_linear", ...
    "timeMode", "fixed_orbit_start_independent_symbols", ...
    "targetBitErrors", 200, ...
    "maxBitsPerPoint", 2e6, ...
    "maxComplexSamplesPerBatch", 2e6, ...
    "maxSymbolsPerBatch", 4096, ...
    "baseSeedSymbols", 20251701, ...
    "baseSeedNoise", 20251702, ...
    "geometry", geometry, ...
    "receiver", "uncompensated noncoherent dechirp FFT argmax", ...
    "channel", "unit-power complex baseband AWGN");
end
```

- [ ] **Step 4: 运行 GREEN**

Run:

```powershell
& 'E:\Matlab2022\MATLAB2022\bin\matlab.exe' -batch `
  "r=run(matlab.unittest.TestSuite.fromFile('test_lora_dynamic_doppler_ber.m')); disp(r); assert(all([r.Passed]));"
```

Expected: 2 项配置测试通过。

- [ ] **Step 5: 提交配置**

```powershell
git add -- lora_dynamic_doppler_ber_config.m test_lora_dynamic_doppler_ber.m
git commit -m "feat: configure dynamic Doppler BER smoke grid"
```

---

### Task 3: Fixed 模式完整时域 BER 单点

**Files:**
- Create: `simulate_lora_dynamic_doppler_ber_point.m`
- Modify: `test_lora_dynamic_doppler_ber.m`

**Interfaces:**
- Consumes: 原调制/解调器、`lora_doppler_piecewise_linear`、BER config。
- Produces: 一个完整字段的 BER 结果结构，支持 fixed 模式和两个 Doppler 模型。

- [ ] **Step 1: 写 fixed 模式 RED 测试**

加入以下测试：

```matlab
function testFixedPointUsesFullWaveformAndRequiredFields(testCase)
config = tiny_config();
result = simulate_lora_dynamic_doppler_ber_point( ...
    config.profile, "high_doppler_rate", ...
    "fixed_orbit_start_independent_symbols", ...
    "paper_piecewise_linear", 5, 0, config);
required = [ ...
    "profile","orbit_scenario","time_mode","doppler_model","sf","snr_db", ...
    "orbit_start_time_s","orbit_initial_doppler_hz", ...
    "orbit_initial_doppler_rate_hz_per_s","symbol_duration_s", ...
    "fft_bin_spacing_hz","half_bin_tolerance_hz", ...
    "normalized_initial_bin_offset","doppler_change_over_symbol_hz", ...
    "normalized_rate_sweep_bins","quadratic_phase_span_rad","ber", ...
    "bit_errors","total_bits","ser","symbol_errors","total_symbols", ...
    "monte_carlo_batches","symbols_per_batch","seed_symbols","seed_noise", ...
    "stop_reason","elapsed_seconds","peak_complex_samples_per_batch", ...
    "estimated_peak_memory_bytes","peak_matlab_memory_bytes", ...
    "peak_matlab_memory_delta_bytes","fft_bin_mapping_valid"];
verifyTrue(testCase, all(isfield(result, required)));
verifyGreaterThan(testCase, result.total_symbols, 0);
verifyGreaterThan(testCase, result.monte_carlo_batches, 0);
verifyLessThanOrEqual(testCase, ...
    result.peak_complex_samples_per_batch, ...
    config.maxComplexSamplesPerBatch);
verifyTrue(testCase, all(isfinite(struct_numeric_values(result))));
end

function testFixedModeIsReproducible(testCase)
config = tiny_config();
first = simulate_lora_dynamic_doppler_ber_point( ...
    config.profile, "high_doppler_shift", ...
    "fixed_orbit_start_independent_symbols", ...
    "paper_piecewise_linear", 5, -10, config);
second = simulate_lora_dynamic_doppler_ber_point( ...
    config.profile, "high_doppler_shift", ...
    "fixed_orbit_start_independent_symbols", ...
    "paper_piecewise_linear", 5, -10, config);
verifyEqual(testCase, first.bit_errors, second.bit_errors);
verifyEqual(testCase, first.symbol_errors, second.symbol_errors);
verifyEqual(testCase, first.total_bits, second.total_bits);
end

function config = tiny_config()
config = lora_dynamic_doppler_ber_config();
config.targetBitErrors = 12;
config.maxBitsPerPoint = 4000;
config.maxComplexSamplesPerBatch = 4096;
config.maxSymbolsPerBatch = 32;
end

function values = struct_numeric_values(value)
names = fieldnames(value);
values = zeros(0, 1);
for index = 1:numel(names)
    fieldValue = value.(names{index});
    if isnumeric(fieldValue) && isscalar(fieldValue)
        values(end + 1, 1) = double(fieldValue); %#ok<AGROW>
    end
end
end
```

- [ ] **Step 2: 运行 RED**

Run:

```powershell
& 'E:\Matlab2022\MATLAB2022\bin\matlab.exe' -batch `
  "r=run(matlab.unittest.TestSuite.fromFile('test_lora_dynamic_doppler_ber.m')); fprintf('POINT_RED passed=%d failed=%d incomplete=%d\n',sum([r.Passed]),sum([r.Failed]),sum([r.Incomplete])); assert(any([r.Failed]));"
```

Expected: 因单点仿真函数未定义而失败。

- [ ] **Step 3: 实现参数验证、场景解析和派生字段**

在 `simulate_lora_dynamic_doppler_ber_point.m` 中实现：

```matlab
geometry = config.geometry;
scenarioNames = string({config.orbitScenarios.name});
scenarioIndex = find(scenarioNames == orbitScenario, 1);
if isempty(scenarioIndex)
    error("lora:InvalidOrbitScenario", "Unknown orbit scenario.");
end
t0 = config.orbitScenarios(scenarioIndex).startTimeSec;
orbitStart = lora_orbit_doppler_trajectory(t0, geometry.configA);
m = 2^sf;
ts = m/config.bandwidthHz;
binSpacing = config.bandwidthHz/m;
batchSymbols = min(config.maxSymbolsPerBatch, ...
    max(1, floor(config.maxComplexSamplesPerBatch/m)));
modelIndex = find( ...
    ["paper_piecewise_linear", "exact_orbit_sampled"] == dopplerModel, 1);
timeModeIndex = find([ ...
    "fixed_orbit_start_independent_symbols", ...
    "continuous_symbol_sequence"] == timeMode, 1);
sfIndex = find(config.spreadingFactors == sf, 1);
if isinf(snrDb)
    snrIndex = 999;
else
    snrIndex = round(10*(snrDb + 100));
end
seedSymbols = config.baseSeedSymbols + ...
    100000*scenarioIndex + 1000*modelIndex + ...
    100*timeModeIndex + 10*sfIndex + snrIndex;
seedNoise = config.baseSeedNoise + ...
    100000*scenarioIndex + 1000*modelIndex + ...
    100*timeModeIndex + 10*sfIndex + snrIndex;
```

验证 `profile`、`timeMode`、`dopplerModel`、SF、SNR、停止条件和批限制均为
允许且有限的值。

- [ ] **Step 4: 实现双随机流与 fixed 批循环**

核心循环必须使用：

```matlab
symbolStream = RandStream("mt19937ar", "Seed", seedSymbols);
noiseStream = RandStream("mt19937ar", "Seed", seedNoise);
remainingSymbols = floor((config.maxBitsPerPoint-totalBits)/sf);
count = min(batchSymbols, remainingSymbols);
if count < 1
    break
end
transmitted = randi(symbolStream, [0, m-1], 1, count, "uint32");
tx = lora_css_modulate(transmitted, sf);
phaseRad = zeros(m, count);
for uniqueSymbol = unique(transmitted)
    trace = lora_doppler_piecewise_linear( ...
        uniqueSymbol, sf, t0, geometry.configA, ...
        BandwidthHz=config.bandwidthHz);
    if dopplerModel == "paper_piecewise_linear"
        selectedPhase = trace.linearPhaseRad;
    else
        selectedPhase = trace.exactPhaseRad;
    end
    phaseRad(:, transmitted == uniqueSymbol) = selectedPhase;
end
noiselessRx = tx.*exp(1i*phaseRad);
noiseVariance = 10^(-snrDb/10);
noise = sqrt(noiseVariance/2)*( ...
    randn(noiseStream, m, count) + ...
    1i*randn(noiseStream, m, count));
detected = lora_css_demodulate(noiselessRx + noise, sf);
```

禁止调用 `simulate_lora_css_awgn_point`。

- [ ] **Step 5: 实现自然二进制统计、停止与内存字段**

```matlab
xorValues = bitxor(transmitted(:), detected(:));
errorsThisBatch = 0;
for bitIndex = 1:sf
    errorsThisBatch = errorsThisBatch + ...
        nnz(bitget(xorValues, bitIndex));
end
symbolErrors = symbolErrors + nnz(transmitted(:) ~= detected(:));
bitErrors = bitErrors + errorsThisBatch;
totalSymbols = totalSymbols + count;
totalBits = totalBits + count*sf;
if any(detected(:) > uint32(m-1))
    error("lora:InvalidDetectedSymbol", ...
        "FFT detector returned a symbol outside [0,M-1].");
end
fftBinMappingValid = true;
```

设置：

```matlab
estimatedPeakMemoryBytes = max(estimatedPeakMemoryBytes, 128*m*count);
peakComplexSamples = max(peakComplexSamples, m*count);
```

用本地 `current_matlab_memory_bytes` 在主要分配阶段采样
`MemUsedMATLAB`；失败时返回 0，不返回 NaN。

- [ ] **Step 6: 运行 GREEN**

Run:

```powershell
& 'E:\Matlab2022\MATLAB2022\bin\matlab.exe' -batch `
  "r=run(matlab.unittest.TestSuite.fromFile('test_lora_dynamic_doppler_ber.m')); disp(r); assert(all([r.Passed]));"
```

Expected: 配置、完整字段、批上限和可复现测试全部通过。

- [ ] **Step 7: 提交 fixed 引擎**

```powershell
git add -- simulate_lora_dynamic_doppler_ber_point.m test_lora_dynamic_doppler_ber.m
git commit -m "feat: simulate fixed-start dynamic Doppler BER"
```

---

### Task 4: Exact 模型、continuous 模式与接口一致性

**Files:**
- Modify: `simulate_lora_dynamic_doppler_ber_point.m`
- Modify: `test_lora_dynamic_doppler_ber.m`

**Interfaces:**
- Consumes: 单符号结果中的 `linearDopplerHz`、`exactDopplerHz`、`linearPhaseRad`、`exactPhaseRad`。
- Produces: 两模型一致接口和跨批保持相位状态的 continuous diagnostic。

- [ ] **Step 1: 写 exact 字段选择 RED 测试**

```matlab
function testExactAndLinearModelsUseExistingTraceFields(testCase)
config = tiny_config();
config.targetBitErrors = 1;
config.maxBitsPerPoint = 5;
linear = simulate_lora_dynamic_doppler_ber_point( ...
    config.profile, "high_doppler_rate", ...
    "fixed_orbit_start_independent_symbols", ...
    "paper_piecewise_linear", 5, 10, config);
exact = simulate_lora_dynamic_doppler_ber_point( ...
    config.profile, "high_doppler_rate", ...
    "fixed_orbit_start_independent_symbols", ...
    "exact_orbit_sampled", 5, 10, config);
verifyEqual(testCase, linear.doppler_model, "paper_piecewise_linear");
verifyEqual(testCase, exact.doppler_model, "exact_orbit_sampled");
verifyEqual(testCase, linear.orbit_start_time_s, exact.orbit_start_time_s);
end
```

- [ ] **Step 2: 写 continuous 时间与相位 RED 测试**

给单点函数增加可选诊断输出：

```matlab
[result, diagnostics] = simulate_lora_dynamic_doppler_ber_point(...)
```

并测试：

```matlab
function testContinuousModeAdvancesTimeAndPhase(testCase)
config = tiny_config();
config.targetBitErrors = intmax("int32");
config.maxBitsPerPoint = 5*4;
config.maxSymbolsPerBatch = 2;
[~, diagnostics] = simulate_lora_dynamic_doppler_ber_point( ...
    config.profile, "high_doppler_rate", ...
    "continuous_symbol_sequence", ...
    "exact_orbit_sampled", 5, Inf, config);
ts = 2^5/config.bandwidthHz;
verifyEqual(testCase, diff(diagnostics.symbolStartTimeSec), ...
    repmat(ts, 1, numel(diagnostics.symbolStartTimeSec)-1), ...
    "AbsTol", 1e-14);
verifyEqual(testCase, diagnostics.phaseBoundaryResidualRad, ...
    zeros(size(diagnostics.phaseBoundaryResidualRad)), ...
    "AbsTol", 1e-12);
verifyEqual(testCase, diagnostics.timeModeLabel, ...
    "continuous-sequence diagnostic");
end

function testFixedModeKeepsTimeAndResetsInitialPhase(testCase)
config = tiny_config();
config.targetBitErrors = intmax("int32");
config.maxBitsPerPoint = 5*4;
[result, diagnostics] = simulate_lora_dynamic_doppler_ber_point( ...
    config.profile, "high_doppler_shift", ...
    "fixed_orbit_start_independent_symbols", ...
    "paper_piecewise_linear", 5, Inf, config);
verifyEqual(testCase, diagnostics.symbolStartTimeSec, ...
    repmat(result.orbit_start_time_s, ...
        size(diagnostics.symbolStartTimeSec)), "AbsTol", 1e-14);
verifyEqual(testCase, diagnostics.symbolInitialPhaseRad, ...
    zeros(size(diagnostics.symbolInitialPhaseRad)), "AbsTol", 1e-14);
end

function testSeparateSeedsPreserveSymbolsAndChangeNoise(testCase)
configA = tiny_config();
configA.targetBitErrors = intmax("int32");
configA.maxBitsPerPoint = 5*16;
configB = configA;
configB.baseSeedNoise = configA.baseSeedNoise + 1;
[~, first] = simulate_lora_dynamic_doppler_ber_point( ...
    configA.profile, "high_doppler_rate", ...
    "fixed_orbit_start_independent_symbols", ...
    "paper_piecewise_linear", 5, -10, configA);
[~, second] = simulate_lora_dynamic_doppler_ber_point( ...
    configB.profile, "high_doppler_rate", ...
    "fixed_orbit_start_independent_symbols", ...
    "paper_piecewise_linear", 5, -10, configB);
verifyEqual(testCase, first.transmittedSymbols, ...
    second.transmittedSymbols);
verifyNotEqual(testCase, first.noiseChecksum, second.noiseChecksum);
end
```

测试专用 diagnostics 仅在请求第二输出时保存短测试序列；正式 smoke 不长期
保存逐符号波形。

- [ ] **Step 3: 运行 RED**

Run:

```powershell
& 'E:\Matlab2022\MATLAB2022\bin\matlab.exe' -batch `
  "r=run(matlab.unittest.TestSuite.fromFile('test_lora_dynamic_doppler_ber.m')); fprintf('CONTINUOUS_RED failed=%d incomplete=%d\n',sum([r.Failed]),sum([r.Incomplete])); assert(any([r.Failed]));"
```

Expected: continuous 模式或第二输出未实现导致失败。

- [ ] **Step 4: 实现统一频率/相位字段选择**

本地函数：

```matlab
function [frequencyHz, phaseRad] = select_trace(trace, model)
if model == "paper_piecewise_linear"
    frequencyHz = trace.linearDopplerHz;
    phaseRad = trace.linearPhaseRad;
elseif model == "exact_orbit_sampled"
    frequencyHz = trace.exactDopplerHz;
    phaseRad = trace.exactPhaseRad;
else
    error("lora:InvalidDopplerModel", "Unsupported Doppler model.");
end
end
```

- [ ] **Step 5: 实现 continuous 相位状态**

对第一个符号使用零相位偏置。后续符号：

```matlab
startTimeSec = t0 + globalSymbolIndex*ts;
boundaryIncrement = pi/config.bandwidthHz*( ...
    previousLastFrequencyHz + frequencyHz(1));
firstPhaseRad = previousLastPhaseRad + boundaryIncrement;
phaseRad = phaseRad + firstPhaseRad;
boundaryResidual = phaseRad(1) - ...
    (previousLastPhaseRad + boundaryIncrement);
previousLastFrequencyHz = frequencyHz(end);
previousLastPhaseRad = phaseRad(end);
```

状态必须跨批保存。fixed 模式仍对每个符号重置相位且不推进 `t0`。
仅在调用者请求第二输出时，diagnostics 保存短测试运行的
`transmittedSymbols`、`symbolStartTimeSec`、`symbolInitialPhaseRad`、
`phaseBoundaryResidualRad` 和 `noiseChecksum`；正式 smoke 只请求第一输出。

- [ ] **Step 6: 增加 no-Doppler 原检测器一致性和 bit 映射测试**

构造 `omegaFixed=0` 的测试轨道：

```matlab
function testZeroVelocityUsesOriginalDetectorAndBitMapping(testCase)
config = tiny_config();
orbit = config.geometry.configA;
radius = orbit.earthRadiusM + orbit.orbitHeightM;
omegaSatellite = sqrt(orbit.gravityMps2*orbit.earthRadiusM^2/radius^3);
orbit.earthRotationRadPerSec = omegaSatellite/cos(orbit.inclinationRad);
symbols = uint32([0, 1, 7, 15, 31]);
tx = lora_css_modulate(symbols, 5);
for index = 1:numel(symbols)
    trace = lora_doppler_piecewise_linear( ...
        symbols(index), 5, 0, orbit, BandwidthHz=config.bandwidthHz);
    verifyEqual(testCase, trace.exactPhaseRad, zeros(32, 1), ...
        "AbsTol", 1e-14);
end
verifyEqual(testCase, lora_css_demodulate(tx, 5), symbols);
xorValues = bitxor(uint32([0, 3]), uint32([3, 1]));
manualErrors = nnz(bitget(xorValues, 1)) + nnz(bitget(xorValues, 2));
verifyEqual(testCase, manualErrors, 3);
end
```

- [ ] **Step 7: 运行 GREEN 与前四轮回归**

Run:

```powershell
& 'E:\Matlab2022\MATLAB2022\bin\matlab.exe' -batch `
  "files={'test_lora_dynamic_doppler.m','test_lora_dynamic_channel.m','test_lora_doppler_approximation.m','test_lora_dynamic_doppler_ber.m'}; parts=cell(size(files)); for k=1:numel(files), parts{k}=matlab.unittest.TestSuite.fromFile(files{k}); end; r=run([parts{:}]); fprintf('MODELS total=%d passed=%d failed=%d incomplete=%d\n',numel(r),sum([r.Passed]),sum([r.Failed]),sum([r.Incomplete])); assert(all([r.Passed]));"
```

Expected: 全部通过。

- [ ] **Step 8: 提交模型与连续模式**

```powershell
git add -- simulate_lora_dynamic_doppler_ber_point.m test_lora_dynamic_doppler_ber.m
git commit -m "feat: support exact and continuous Doppler BER modes"
```

---

### Task 5: Smoke runner、CSV 与中文报告

**Files:**
- Create: `run_lora_dynamic_doppler_ber_smoke.m`
- Modify: `test_lora_dynamic_doppler_ber.m`
- Generate: `dynamic_doppler_ber_smoke.csv`
- Generate: `dynamic_doppler_ber_smoke_report.md`

**Interfaces:**
- Consumes: BER config 与单点仿真函数。
- Produces: 24 行 CSV、中文报告和 runner outputs 结构。

- [ ] **Step 1: 写 runner RED 测试**

```matlab
function testSmokeRunnerCreatesArtifactsWithoutFigure17(testCase)
outputDirectory = string(tempname);
mkdir(outputDirectory);
cleanup = onCleanup(@() rmdir(outputDirectory, "s"));
config = lora_dynamic_doppler_ber_config();
config.spreadingFactors = 5;
config.snrDb = 0;
config.targetBitErrors = 4;
config.maxBitsPerPoint = 200;
config.maxComplexSamplesPerBatch = 1024;
config.maxSymbolsPerBatch = 8;
outputs = run_lora_dynamic_doppler_ber_smoke( ...
    OutputDirectory=outputDirectory, Config=config);
verifyEqual(testCase, height(outputs.results), 2);
verifyTrue(testCase, isfile(fullfile(outputDirectory, ...
    "dynamic_doppler_ber_smoke.csv")));
verifyTrue(testCase, isfile(fullfile(outputDirectory, ...
    "dynamic_doppler_ber_smoke_report.md")));
verifyFalse(testCase, any(contains( ...
    string({dir(outputDirectory).name}), "figure17", ...
    "IgnoreCase", true)));
verifyTrue(testCase, all(outputs.results.time_mode == ...
    "fixed_orbit_start_independent_symbols"));
end
```

- [ ] **Step 2: 运行 RED**

Run:

```powershell
& 'E:\Matlab2022\MATLAB2022\bin\matlab.exe' -batch `
  "r=run(matlab.unittest.TestSuite.fromFile('test_lora_dynamic_doppler_ber.m')); fprintf('RUNNER_RED failed=%d incomplete=%d\n',sum([r.Failed]),sum([r.Incomplete])); assert(any([r.Failed]));"
```

Expected: runner 未定义导致失败。

- [ ] **Step 3: 实现 24 点 runner**

`run_lora_dynamic_doppler_ber_smoke.m`：

```matlab
function outputs = run_lora_dynamic_doppler_ber_smoke(options)
arguments
    options.OutputDirectory (1, 1) string = string(pwd)
    options.Config (1, 1) struct = lora_dynamic_doppler_ber_config()
end
config = options.Config;
rows = repmat(struct(), 0, 1);
for scenario = string({config.orbitScenarios.name})
    for sf = config.spreadingFactors
        for snrDb = config.snrDb
            rows(end + 1, 1) = simulate_lora_dynamic_doppler_ber_point( ...
                config.profile, scenario, config.timeMode, ...
                config.dopplerModel, sf, snrDb, config); %#ok<AGROW>
        end
    end
end
results = struct2table(rows);
writetable(results, fullfile(options.OutputDirectory, ...
    "dynamic_doppler_ber_smoke.csv"));
write_chinese_report(results, config, options.OutputDirectory);
outputs = struct("results", results, "berSweepRun", true, ...
    "finalFigure17Generated", false);
end
```

- [ ] **Step 4: 实现中文报告**

用：

```matlab
function write_chinese_report(results, config, outputDirectory)
reportPath = fullfile(outputDirectory, ...
    "dynamic_doppler_ber_smoke_report.md");
fileId = fopen(reportPath, "w", "n", "UTF-8");
if fileId < 0
    error("lora:ReportOpenFailed", ...
        "Cannot open smoke report for writing.");
end
cleanup = onCleanup(@() fclose(fileId));
fprintf(fileId, "# 动态 Doppler BER Smoke 报告\n\n");
fprintf(fileId, "- 模型：`%s`\n", config.dopplerModel);
fprintf(fileId, "- 时间模式：`%s`\n", config.timeMode);
fprintf(fileId, "- 接收机：%s\n", config.receiver);
fprintf(fileId, "- 复采样批上限：%d\n\n", ...
    config.maxComplexSamplesPerBatch);
fprintf(fileId, ["论文没有完整公开 Figure 17 的接收机与 SNR 细节；" ...
    "本报告采用项目已验证的单位功率复基带 AWGN、理想符号边界、" ...
    "无 Doppler 补偿和非相干 dechirp-FFT 判决。\n\n"]);
fprintf(fileId, ...
    "| 场景 | SF | SNR(dB) | BER | SER | 秒 | MATLAB峰值(MiB) | 估算峰值(MiB) | 停止原因 |\n");
fprintf(fileId, ...
    "|---|---:|---:|---:|---:|---:|---:|---:|---|\n");
for rowIndex = 1:height(results)
    row = results(rowIndex, :);
    fprintf(fileId, ...
        "| %s | %d | %.1f | %.6g | %.6g | %.3f | %.2f | %.2f | %s |\n", ...
        row.orbit_scenario, row.sf, row.snr_db, row.ber, row.ser, ...
        row.elapsed_seconds, row.peak_matlab_memory_bytes/2^20, ...
        row.estimated_peak_memory_bytes/2^20, row.stop_reason);
end
hasInvalid = any(~isfinite(results.ber)) || ...
    any(~isfinite(results.ser)) || ...
    any(results.monte_carlo_batches < 1) || ...
    any(results.total_symbols < 1);
fprintf(fileId, "\n## 完整性审查\n\n");
fprintf(fileId, "- NaN、Inf 或空批次：%s\n", ...
    string(hasInvalid));
fprintf(fileId, "- FFT bin 映射全部有效：%s\n", ...
    string(all(results.fft_bin_mapping_valid)));
fprintf(fileId, "- 最终 Figure 17 已生成：否\n");
clear cleanup
end
```

写入：

- 模型和接收机假设；
- fixed 模式含义；
- 24 点逐行 BER、SER、运行时间、MATLAB 峰值内存和估算峰值内存；
- shared-window 公式推导时刻；
- 停止原因汇总；
- NaN、Inf、空批次、检测 bin 映射审查；
- 未生成最终 Figure 17；
- 论文未完整公开 Figure 17 接收机和 SNR 细节的说明。

- [ ] **Step 5: 运行 runner GREEN 测试**

Run:

```powershell
& 'E:\Matlab2022\MATLAB2022\bin\matlab.exe' -batch `
  "r=run(matlab.unittest.TestSuite.fromFile('test_lora_dynamic_doppler_ber.m')); disp(r); assert(all([r.Passed]));"
```

Expected: runner 临时输出测试通过。

- [ ] **Step 6: 提交 runner**

```powershell
git add -- run_lora_dynamic_doppler_ber_smoke.m test_lora_dynamic_doppler_ber.m
git commit -m "feat: run dynamic Doppler BER smoke grid"
```

---

### Task 6: 实际 smoke、测试报告和最终验证

**Files:**
- Generate: `dynamic_doppler_ber_smoke.csv`
- Generate: `dynamic_doppler_ber_smoke_report.md`
- Generate: `test_dynamic_doppler_ber_results.txt`
- Modify: `.planning/dynamic_doppler_ber_smoke/task_plan.md`
- Modify: `.planning/dynamic_doppler_ber_smoke/findings.md`
- Modify: `.planning/dynamic_doppler_ber_smoke/progress.md`

**Interfaces:**
- Consumes: 全部测试和正式 smoke 配置。
- Produces: 最终 24 点数据、中文审查证据和可复现状态。

- [ ] **Step 1: 实际运行正式 smoke**

Run:

```powershell
& 'E:\Matlab2022\MATLAB2022\bin\matlab.exe' -batch `
  "outputs=run_lora_dynamic_doppler_ber_smoke(OutputDirectory=string(pwd)); fprintf('SMOKE rows=%d figure17=%d\n',height(outputs.results),outputs.finalFigure17Generated); assert(height(outputs.results)==24); assert(~outputs.finalFigure17Generated);"
```

Expected: `SMOKE rows=24 figure17=0`。

- [ ] **Step 2: 验证 CSV 完整性**

Run:

```powershell
$rows = Import-Csv -LiteralPath 'dynamic_doppler_ber_smoke.csv'
if ($rows.Count -ne 24) { throw 'Smoke row count is not 24.' }
$bad = $rows | Where-Object {
  [double]::IsNaN([double]$_.ber) -or
  [double]::IsInfinity([double]$_.ber) -or
  [int]$_.monte_carlo_batches -lt 1 -or
  [int]$_.total_symbols -lt 1
}
if ($bad) { throw 'NaN, Inf, or empty batch found.' }
```

Expected: 24 行且没有 NaN、Inf 或空批次。

- [ ] **Step 3: 运行全部 MATLAB 测试**

Run:

```powershell
& 'E:\Matlab2022\MATLAB2022\bin\matlab.exe' -batch `
  "files={'test_lora_css_awgn.m','test_lora_dynamic_doppler.m','test_lora_dynamic_channel.m','test_lora_doppler_approximation.m','test_lora_dynamic_doppler_ber.m'}; parts=cell(size(files)); for k=1:numel(files), parts{k}=matlab.unittest.TestSuite.fromFile(files{k}); end; r=run([parts{:}]); fprintf('FINAL total=%d passed=%d failed=%d incomplete=%d\n',numel(r),sum([r.Passed]),sum([r.Failed]),sum([r.Incomplete])); assert(all([r.Passed]));"
```

Expected: 原 AWGN、33 项动态 Doppler 和新 BER 测试全部通过。

- [ ] **Step 4: 运行 Code Analyzer**

Run:

```powershell
& 'E:\Matlab2022\MATLAB2022\bin\matlab.exe' -batch `
  "files={'lora_dynamic_doppler_ber_config.m','simulate_lora_dynamic_doppler_ber_point.m','run_lora_dynamic_doppler_ber_smoke.m','test_lora_dynamic_doppler_ber.m'}; total=0; for k=1:numel(files), msg=checkcode(files{k},'-id'); fprintf('%s messages=%d\n',files{k},numel(msg)); total=total+numel(msg); end; fprintf('ANALYZER total=%d\n',total); assert(total==0);"
```

Expected: `ANALYZER total=0`。

- [ ] **Step 5: 生成中文测试结果**

用 MATLAB `fopen(...,"w","n","UTF-8")` 写
`test_dynamic_doppler_ber_results.txt`，逐项记录：

- 测试名称、通过/失败/未完成、运行时间；
- 24 点 smoke 数量；
- Code Analyzer 结果；
- 每点运行时间与两种峰值内存；
- 接口和单位审查；
- NaN、Inf、空批次、越界 FFT bin 检查；
- AWGN 基准文件 SHA-256。

- [ ] **Step 6: 需求扫描**

Run:

```powershell
$newFiles = @(
  'lora_dynamic_doppler_ber_config.m',
  'simulate_lora_dynamic_doppler_ber_point.m',
  'run_lora_dynamic_doppler_ber_smoke.m'
)
Select-String -LiteralPath $newFiles -Pattern `
  'simulate_lora_css_awgn_point|circshift|bin.shift|doppler.compensat'
```

Expected: 0 条生产代码匹配。

- [ ] **Step 7: 更新中文计划记录并提交产物**

```powershell
git add -- `
  dynamic_doppler_ber_smoke.csv `
  dynamic_doppler_ber_smoke_report.md `
  test_dynamic_doppler_ber_results.txt `
  .planning/dynamic_doppler_ber_smoke
git commit -m "test: verify dynamic Doppler BER smoke sweep"
```

- [ ] **Step 8: 最终 Git 审查**

Run:

```powershell
git status --short --branch
git log --oneline --decorate -8
git diff main...HEAD --stat
```

Expected: 工作树干净；分支包含设计、迁入、配置、仿真、runner 和验证提交。
