# Figure 17 动态 Doppler BER 粗网格预检 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use \`executing-plans\` to implement this plan task-by-task. Steps use checkbox (\`- [ ]\`) syntax for tracking.

**Goal:** 复用已验证的动态 Doppler BER 引擎，运行可续跑的 336 点论文参考粗网格并输出原始结果、趋势诊断与两 panel 预检图。

**Architecture:** 新配置函数仅派生现有 BER 配置，绝不复制物理模型。新 runner 将每个网格点交给 \`simulate_lora_dynamic_doppler_ber_point\`，每点写 checkpoint；独立诊断函数从原始表归并指标与趋势。绘图只读取原始 Monte Carlo 表。

**Tech Stack:** MATLAB R2022、现有 LoRa CSS 调制/检测、现有轨道与动态 Doppler 模块、MATLAB Unit Test Framework、CSV、PNG。

## 全局约束

- profile 必须为 \`paper_figure17_reference\`。
- 只能使用 \`fixed_orbit_start_independent_symbols\` 和 \`paper_piecewise_linear\` 作为正式 pilot 结果。
- 场景时刻必须来自 \`lora_figure17_geometry\` 的 shared visibility window，不能硬编码时刻或 Doppler 值。
- pilot 网格为 SF \`5:12\`、SNR \`-30:2:10 dB\`、两个既有场景、每点 \`500\` bit errors 或 \`1e7\` bits。
- 不修改轨道、Doppler、AWGN 基准调制/检测器，也不使用 order-statistic、人工 bin 平移或 Doppler 补偿。
- 所有审核报告使用中文；图只显示未平滑的原始 Monte Carlo 点。

---

### Task 1: Pilot 配置与配置回归测试

**Files:**

- Create: \`lora_dynamic_doppler_figure17_pilot_config.m\`
- Create: \`test_lora_dynamic_doppler_figure17_pilot.m\`

**Interfaces:**

- Consumes: \`lora_dynamic_doppler_ber_config()\`、\`lora_figure17_geometry()\`。
- Produces: \`config = lora_dynamic_doppler_figure17_pilot_config()\`；config 含既有 BER 字段、\`profile\`、网格、停止条件、输出文件名和 \`resume\`。

- [ ] **Step 1: 写入失败测试**

\`\`\`matlab
function testPilotConfigUsesRequiredReferenceGrid(testCase)
config = lora_dynamic_doppler_figure17_pilot_config();
verifyEqual(testCase, config.profile, "paper_figure17_reference");
verifyEqual(testCase, config.spreadingFactors, 5:12);
verifyEqual(testCase, config.snrDb, -30:2:10);
verifyEqual(testCase, config.targetBitErrors, 500);
verifyEqual(testCase, config.maxBitsPerPoint, 1e7);
verifyEqual(testCase, config.dopplerModel, "paper_piecewise_linear");
verifyEqual(testCase, config.timeMode, ...
    "fixed_orbit_start_independent_symbols");
end
\`\`\`

- [ ] **Step 2: 运行测试并确认失败**

Run: \`matlab -batch "results=runtests('test_lora_dynamic_doppler_figure17_pilot'); assert(all([results.Failed]==0))"\`

Expected: 失败原因是 \`lora_dynamic_doppler_figure17_pilot_config\` 尚不存在。

- [ ] **Step 3: 最小实现配置函数**

\`\`\`matlab
function config = lora_dynamic_doppler_figure17_pilot_config()
config = lora_dynamic_doppler_ber_config();
geometry = lora_figure17_geometry();
config.profile = "paper_figure17_reference";
config.spreadingFactors = 5:12;
config.snrDb = -30:2:10;
config.targetBitErrors = 500;
config.maxBitsPerPoint = 1e7;
config.orbitScenarios(1).startTimeSec = geometry.highRateTimeSec;
config.orbitScenarios(2).startTimeSec = geometry.highShiftTimeSec;
config.resume = true;
end
\`\`\`

- [ ] **Step 4: 扩展测试以验证公式场景**

\`\`\`matlab
function testPilotConfigUsesFormulaDerivedScenarioTimes(testCase)
config = lora_dynamic_doppler_figure17_pilot_config();
geometry = lora_figure17_geometry();
verifyEqual(testCase, config.orbitScenarios(1).startTimeSec, ...
    geometry.highRateTimeSec, AbsTol=1e-12);
verifyEqual(testCase, config.orbitScenarios(2).startTimeSec, ...
    geometry.highShiftTimeSec, AbsTol=1e-12);
end
\`\`\`

- [ ] **Step 5: 运行测试并确认通过**

Run: \`matlab -batch "results=runtests('test_lora_dynamic_doppler_figure17_pilot'); assert(all([results.Passed]))"\`

Expected: 所有 Task 1 测试通过。

- [ ] **Step 6: 提交 Task 1**

\`\`\`powershell
git add lora_dynamic_doppler_figure17_pilot_config.m test_lora_dynamic_doppler_figure17_pilot.m
git commit -m "feat: add Figure 17 pilot configuration"
\`\`\`

### Task 2: 纯函数趋势诊断与测试

**Files:**

- Create: \`lora_dynamic_doppler_pilot_diagnostics.m\`
- Modify: \`test_lora_dynamic_doppler_figure17_pilot.m\`

**Interfaces:**

- Consumes: 结果 table，至少含 \`orbit_scenario\`、\`sf\`、\`snr_db\`、\`ber\`、\`bit_errors\`、\`total_bits\` 与 BER 点函数的轨道指标。
- Produces: \`diagnostics = lora_dynamic_doppler_pilot_diagnostics(results)\`，每个场景/SF 一行。

- [ ] **Step 1: 写入失败测试**

\`\`\`matlab
function testDiagnosticsPreserveRawTrendMetrics(testCase)
results = synthetic_pilot_results();
diagnostics = lora_dynamic_doppler_pilot_diagnostics(results);
verifyEqual(testCase, height(diagnostics), 2);
verifyTrue(testCase, diagnostics.strict_monotonic_improvement(1));
verifyEqual(testCase, diagnostics.estimated_high_snr_ber_floor(1), ...
    median([1e-3, 8e-4, 6e-4]), AbsTol=eps);
end
\`\`\`

- [ ] **Step 2: 运行测试并确认失败**

Run: \`matlab -batch "results=runtests('test_lora_dynamic_doppler_figure17_pilot'); assert(all([results.Failed]))"\`

Expected: 失败原因是 \`lora_dynamic_doppler_pilot_diagnostics\` 尚不存在。

- [ ] **Step 3: 最小实现诊断函数**

\`\`\`matlab
function diagnostics = lora_dynamic_doppler_pilot_diagnostics(results)
requiredSnr = [-30, -10, 6, 8, 10];
assert(all(ismember(requiredSnr, results.snr_db)));
keys = unique(results(:, {"orbit_scenario", "sf"}), "rows");
for index = 1:height(keys)
    subset = sortrows(results(results.orbit_scenario == ...
        keys.orbit_scenario(index) & results.sf == keys.sf(index), :), "snr_db");
    strict = all(diff(subset.ber) <= 0);
    floorEstimate = median(subset.ber(ismember(subset.snr_db, [6 8 10])));
end
end
\`\`\`

- [ ] **Step 4: 增加零错误与非单调测试**

\`\`\`matlab
function testDiagnosticsKeepZeroBerFiniteAndFlagViolation(testCase)
results = synthetic_pilot_results();
results.ber(2) = 0;
results.ber(3) = 0.01;
diagnostics = lora_dynamic_doppler_pilot_diagnostics(results);
verifyFalse(testCase, diagnostics.strict_monotonic_improvement(1));
verifyTrue(testCase, isfinite(diagnostics.estimated_high_snr_ber_floor(1)));
end
\`\`\`

- [ ] **Step 5: 运行诊断测试并确认通过**

Run: \`matlab -batch "results=runtests('test_lora_dynamic_doppler_figure17_pilot'); assert(all([results.Passed]))"\`

Expected: 诊断表字段完整，零 BER 不生成 NaN 或 Inf。

- [ ] **Step 6: 提交 Task 2**

\`\`\`powershell
git add lora_dynamic_doppler_pilot_diagnostics.m test_lora_dynamic_doppler_figure17_pilot.m
git commit -m "feat: add dynamic Doppler pilot diagnostics"
\`\`\`

### Task 3: 可续跑 runner、原始图像与集成测试

**Files:**

- Create: \`run_lora_dynamic_doppler_figure17_pilot.m\`
- Modify: \`test_lora_dynamic_doppler_figure17_pilot.m\`

**Interfaces:**

- Consumes: \`lora_dynamic_doppler_figure17_pilot_config\`、\`simulate_lora_dynamic_doppler_ber_point\`、\`lora_dynamic_doppler_pilot_diagnostics\`。
- Produces: \`outputs = run_lora_dynamic_doppler_figure17_pilot(Name=Value)\`，包含 results、diagnostics、三个绝对输出路径与 \`resumedPointCount\`。

- [ ] **Step 1: 写入失败的缩小网格集成测试**

\`\`\`matlab
function testPilotRunnerWritesCheckpointDiagnosticsAndFigure(testCase)
outputDirectory = tempname; mkdir(outputDirectory);
config = lora_dynamic_doppler_figure17_pilot_config();
config.spreadingFactors = 5;
config.snrDb = [-2, 0, 2, 4, 6, 8, 10];
config.targetBitErrors = 2;
config.maxBitsPerPoint = 200;
outputs = run_lora_dynamic_doppler_figure17_pilot( ...
    OutputDirectory=outputDirectory, Config=config);
verifyEqual(testCase, height(outputs.results), 14);
verifyTrue(testCase, isfile(outputs.resultsCsvPath));
verifyTrue(testCase, isfile(outputs.diagnosticsCsvPath));
verifyTrue(testCase, isfile(outputs.figurePath));
end
\`\`\`

- [ ] **Step 2: 运行集成测试并确认失败**

Run: \`matlab -batch "results=runtests('test_lora_dynamic_doppler_figure17_pilot'); assert(any([results.Failed]))"\`

Expected: 失败原因是 runner 尚不存在。

- [ ] **Step 3: 最小实现逐点 checkpoint 调度器**

\`\`\`matlab
for orbitScenario = string({config.orbitScenarios.name})
    for sf = config.spreadingFactors
        for snrDb = config.snrDb
            if has_completed_key(results, config, orbitScenario, sf, snrDb)
                continue
            end
            point = simulate_lora_dynamic_doppler_ber_point( ...
                config.profile, orbitScenario, config.timeMode, ...
                config.dopplerModel, sf, snrDb, config);
            results = append_result(results, point);
            writetable(results, resultsCsvPath);
        end
    end
end
\`\`\`

实现绘图时：用 \`ber\` 绘制非零点；对零错误点改用 \`ber_upper_bound\` 与空心下三角，并添加“零错误上界”说明。不得改变 CSV 中的 \`ber=0\`。

- [ ] **Step 4: 加入续跑与原始计数测试**

\`\`\`matlab
function testPilotRunnerResumeSkipsCompletedKeys(testCase)
outputDirectory = tempname; mkdir(outputDirectory);
config = lora_dynamic_doppler_figure17_pilot_config();
config.spreadingFactors = 5;
config.snrDb = [-2 0 2 4 6 8 10];
config.targetBitErrors = 2;
config.maxBitsPerPoint = 200;
first = run_lora_dynamic_doppler_figure17_pilot( ...
    OutputDirectory=outputDirectory, Config=config);
second = run_lora_dynamic_doppler_figure17_pilot( ...
    OutputDirectory=outputDirectory, Config=config);
verifyEqual(testCase, second.resumedPointCount, height(first.results));
verifyEqual(testCase, second.results.bit_errors, first.results.bit_errors);
verifyEqual(testCase, second.results.total_bits, first.results.total_bits);
end
\`\`\`

- [ ] **Step 5: 运行所有 pilot 测试并确认通过**

Run: \`matlab -batch "results=runtests('test_lora_dynamic_doppler_figure17_pilot'); assert(all([results.Passed]))"\`

Expected: 配置、诊断、checkpoint、续跑、图像与原始计数测试全部通过。

- [ ] **Step 6: 提交 Task 3**

\`\`\`powershell
git add run_lora_dynamic_doppler_figure17_pilot.m test_lora_dynamic_doppler_figure17_pilot.m
git commit -m "feat: run resumable Figure 17 BER pilot"
\`\`\`

### Task 4: 完整验证、336 点 MATLAB 运行与中文审核

**Files:**

- Create: \`dynamic_doppler_ber_pilot_results.csv\`
- Create: \`dynamic_doppler_ber_pilot_diagnostics.csv\`
- Create: \`dynamic_doppler_ber_figure17_pilot.png\`
- Create: \`dynamic_doppler_ber_pilot_report.md\`
- Create: \`test_dynamic_doppler_ber_pilot_results.txt\`
- Modify: \`.planning/dynamic_doppler_figure17_pilot/progress.md\`

**Interfaces:**

- Consumes: 全部 pilot 生产函数和既有回归测试。
- Produces: 可审计的原始结果、诊断、图像、中文报告和最新 MATLAB 证据。

- [ ] **Step 1: 运行完整 pilot 单元测试并保存 MATLAB 结果**

Run: \`matlab -batch "results=runtests('test_lora_dynamic_doppler_figure17_pilot'); assert(all([results.Passed]));"\`

Expected: 所有新测试通过；结果文件记录测试数、失败数和警告。

- [ ] **Step 2: 运行既有完整回归**

Run: \`matlab -batch "results=runtests({'test_lora_css_awgn','test_lora_dynamic_doppler','test_lora_dynamic_channel','test_lora_doppler_approximation','test_lora_dynamic_doppler_ber','test_lora_dynamic_doppler_figure17_pilot'}); assert(all([results.Passed]));"\`

Expected: 原 AWGN 行为未被修改，所有回归通过。

- [ ] **Step 3: 启动完整 336 点 runner，并保留 checkpoint**

Run: \`matlab -batch "run_lora_dynamic_doppler_figure17_pilot(OutputDirectory=pwd)"\`

Expected: 完成 336 个唯一键；中断后以同一命令续跑。

- [ ] **Step 4: 审核表、趋势与禁用项**

\`\`\`matlab
results = readtable("dynamic_doppler_ber_pilot_results.csv");
assert(height(results) == 336);
assert(all(results.bit_errors >= 0 & results.total_bits > 0));
assert(all(isfinite(results.ber)));
assert(all(results.fft_bin_mapping_valid));
\`\`\`

在中文报告中列出每点耗时、最大内存、最大批复采样数、NaN/Inf、空批、FFT 映射、趋势状态与触发的排查清单。若趋势异常，明确写 \`investigate_before_final_scan\`，不执行最终 Figure 17 扫描。

- [ ] **Step 5: 执行 MATLAB Code Analyzer 与文件检查**

Run: \`matlab -batch "checkcode('lora_dynamic_doppler_figure17_pilot_config.m','run_lora_dynamic_doppler_figure17_pilot.m','lora_dynamic_doppler_pilot_diagnostics.m','test_lora_dynamic_doppler_figure17_pilot.m')"\`

Expected: 没有 Code Analyzer 问题；三份 CSV/PNG 均存在。

- [ ] **Step 6: 提交 Task 4**

\`\`\`powershell
git add dynamic_doppler_ber_pilot_results.csv dynamic_doppler_ber_pilot_diagnostics.csv dynamic_doppler_ber_figure17_pilot.png dynamic_doppler_ber_pilot_report.md test_dynamic_doppler_ber_pilot_results.txt .planning/dynamic_doppler_figure17_pilot/progress.md
git commit -m "test: verify Figure 17 dynamic Doppler BER pilot"
\`\`\`

## 计划自审

- 规格覆盖：四个任务分别覆盖配置、场景推导、原始数据保存、checkpoint、诊断、原始图像、趋势暂停、内存批处理、单元测试、完整 MATLAB 执行和 AWGN 回归。
- 占位符扫描：没有发现未定义的后续工作标记或空缺步骤。
- 接口一致性：所有 runner 只调用既有 BER 点函数；配置、诊断和输出路径在相邻任务中使用同一名称。
