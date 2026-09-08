# Figure 17 正式动态 Doppler BER 扫描 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use \`executing-plans\` to implement this plan task-by-task. Steps use checkbox (\`- [ ]\`) syntax for tracking.

**Goal:** 生成可审计的 656 点正式 Figure 17 BER 结果、两 panel PNG/PDF、metadata、中文报告和 24 点 paired exact 复核。

**Architecture:** 物理链路继续委托给既有 BER 点函数；仅为该函数增加可选的随机流覆盖和批级诊断。正式 runner 负责输出层零错误编码、checkpoint、绘图和 metadata；paired runner 驱动两个模型的共同批次并报告差异。

**Tech Stack:** MATLAB R2022、现有 LoRa CSS/轨道/Doppler 模块、MATLAB Unit Test Framework、CSV、JSON、PNG/PDF。

## Global Constraints

- 主网格为 SF \`5:12\`、SNR \`-30:1:10 dB\`、两个既有场景，共 656 点。
- 主模型固定为 \`paper_piecewise_linear\` 和 \`fixed_orbit_start_independent_symbols\`。
- 每点停止条件为 2000 bit errors 或 \`5e7\` bits，均可配置。
- 不修改 AWGN 基准、轨道或 Doppler 物理模块；不使用 order-statistic、人工 bin shift 或 Doppler 补偿。
- 结果的零错误 \`ber=NaN\`，并写出 \`one_count_level\` 与 \`upper_95_approx\`。
- paired exact 子集为两场景、SF \`[5,7,8,12]\`、SNR \`[-10,0,10]\`，共同批次直到双方均停止。
- 所有审查报告使用中文；图中只画本项目未平滑的原始结果。

---

### Task 1: 正式配置、零错误输出映射与测试

**Files:**

- Create: \`lora_dynamic_doppler_figure17_config.m\`
- Create: \`lora_dynamic_doppler_formalize_result.m\`
- Create: \`test_lora_dynamic_doppler_figure17_final.m\`

**Interfaces:**

- Produces \`config = lora_dynamic_doppler_figure17_config()\` 和 \`formal = lora_dynamic_doppler_formalize_result(raw)\`。
- \`formal\` 保留 raw 的所有字段，并新增 \`one_count_level\`、\`upper_95_approx\`、\`raw_ber\`；零错误时仅 \`formal.ber\` 为 NaN。

- [ ] **Step 1: 写失败测试**

\`\`\`matlab
config = lora_dynamic_doppler_figure17_config();
verifyEqual(testCase, config.snrDb, -30:1:10);
verifyEqual(testCase, config.targetBitErrors, 2000);
verifyEqual(testCase, config.maxBitsPerPoint, 5e7);
raw = struct("bit_errors",0,"total_bits",1e6,"ber",0);
formal = lora_dynamic_doppler_formalize_result(raw);
verifyTrue(testCase, isnan(formal.ber));
verifyEqual(testCase, formal.one_count_level, 1e-6);
verifyEqual(testCase, formal.upper_95_approx, -log(0.05)/1e6);
\`\`\`

- [ ] **Step 2: 运行并确认红灯**

Run: MATLAB \`TestSuite.fromFile\` 执行新测试文件。

Expected: 缺少正式配置和输出映射函数。

- [ ] **Step 3: 最小实现**

\`\`\`matlab
config = lora_dynamic_doppler_figure17_pilot_config();
config.snrDb = -30:1:10;
config.targetBitErrors = 2000;
config.maxBitsPerPoint = 5e7;
config.profile = "paper_figure17_reference";
\`\`\`

输出映射必须只基于 \`bit_errors\` 与 \`total_bits\`，不能由 BER 小数值推断零错误。

- [ ] **Step 4: 运行绿灯并提交**

Run: 新测试通过；再运行 \`test_lora_dynamic_doppler_ber\`。

\`\`\`powershell
git add lora_dynamic_doppler_figure17_config.m lora_dynamic_doppler_formalize_result.m test_lora_dynamic_doppler_figure17_final.m
git commit -m "feat: add formal Figure 17 configuration"
\`\`\`

### Task 2: 分层种子覆盖与 paired exact 内核

**Files:**

- Modify: \`simulate_lora_dynamic_doppler_ber_point.m\`
- Create: \`simulate_lora_dynamic_doppler_paired_point.m\`
- Modify: \`test_lora_dynamic_doppler_figure17_final.m\`

**Interfaces:**

- BER 点函数接受可选 \`config.seedOverrideSymbols\` 与 \`config.seedOverrideNoise\`，缺省时保留原有模型索引种子公式。
- \`paired = simulate_lora_dynamic_doppler_paired_point(scenario,sf,snrDb,config)\` 返回 paper/exact 原始计数、FFT/相位比较和 paired 一致性结果。

- [ ] **Step 1: 写失败测试**

\`\`\`matlab
paired = simulate_lora_dynamic_doppler_paired_point( ...
 "high_doppler_rate",5,0,tiny_final_config());
verifyEqual(testCase, paired.paper.seed_symbols, paired.exact.seed_symbols);
verifyEqual(testCase, paired.paper.seed_noise, paired.exact.seed_noise);
verifyEqual(testCase, paired.paper.total_bits, paired.exact.total_bits);
verifyTrue(testCase, isfinite(paired.rms_phase_error_rad));
\`\`\`

- [ ] **Step 2: 运行并确认红灯**

Expected: paired 内核不存在。

- [ ] **Step 3: 最小实现**

每批只生成一次 transmitted 和 AWGN，并分别施加 paper/exact phase；双方始终读取同一批。仅当双方均达到自身错误阈值或共同到达 \`maxBitsPerPoint\` 后停止。以完整无噪声接收链路计算 FFT peak、归一化能量向量差、最大 Doppler 频率误差和 RMS phase error。

- [ ] **Step 4: 计算一致性门限**

\`\`\`matlab
combinedSe = sqrt(paper.ber*(1-paper.ber)/paper.total_bits + ...
                  exact.ber*(1-exact.ber)/exact.total_bits);
relativeTerm = 0;
if max(paper.ber,exact.ber) > 1e-3
    relativeTerm = 0.1*max(paper.ber,exact.ber);
end
threshold = max(3*combinedSe,relativeTerm);
consistent = abs(paper.ber-exact.ber) < threshold;
\`\`\`

- [ ] **Step 5: 运行绿灯与既有动态 BER 测试并提交**

\`\`\`powershell
git add simulate_lora_dynamic_doppler_ber_point.m simulate_lora_dynamic_doppler_paired_point.m test_lora_dynamic_doppler_figure17_final.m
git commit -m "feat: add paired exact Doppler validation"
\`\`\`

### Task 3: 正式 runner、图、metadata、报告与测试

**Files:**

- Create: \`run_lora_dynamic_doppler_figure17.m\`
- Modify: \`test_lora_dynamic_doppler_figure17_final.m\`

**Interfaces:**

- \`outputs = run_lora_dynamic_doppler_figure17(OutputDirectory=...,Config=...)\`。
- Produces requested CSV/PNG/PDF/JSON/Markdown plus \`dynamic_doppler_ber_exact_validation.csv\`。

- [ ] **Step 1: 写缩小网格失败集成测试**

\`\`\`matlab
config = tiny_final_config();
outputs = run_lora_dynamic_doppler_figure17(OutputDirectory=tempdir,Config=config);
verifyTrue(testCase, isfile(outputs.resultsCsvPath));
verifyTrue(testCase, isfile(outputs.figurePngPath));
verifyTrue(testCase, isfile(outputs.figurePdfPath));
verifyTrue(testCase, isfile(outputs.metadataJsonPath));
verifyEqual(testCase, height(outputs.results), 10);
\`\`\`

- [ ] **Step 2: 运行并确认红灯**

Expected: 正式 runner 不存在。

- [ ] **Step 3: 最小实现**

逐点调用既有 BER 点函数、立即 checkpoint raw/formal result CSV；复用场景起始时刻。图严格为两 panel、对数 y 轴、SF5-SF12、标题含 no interference/no Doppler compensation。零错误在图上以 \`upper_95_approx\` 下三角显示，CSV 的 BER 保持 NaN。metadata 写出项目选择的 1 dB 网格依据，而不声称论文公开此步长。

- [ ] **Step 4: 运行绿灯并提交**

\`\`\`powershell
git add run_lora_dynamic_doppler_figure17.m test_lora_dynamic_doppler_figure17_final.m
git commit -m "feat: run formal Figure 17 BER scan"
\`\`\`

### Task 4: 完整 MATLAB 验证和正式扫描

**Files:**

- Create: \`dynamic_doppler_ber_results.csv\`
- Create: \`dynamic_doppler_ber_figure17.png\`
- Create: \`dynamic_doppler_ber_figure17.pdf\`
- Create: \`dynamic_doppler_ber_metadata.json\`
- Create: \`dynamic_doppler_ber_report.md\`
- Create: \`dynamic_doppler_ber_exact_validation.csv\`
- Create: \`test_dynamic_doppler_ber_figure17_results.txt\`

- [ ] **Step 1: 执行完整单元和回归测试**

Run: 合并所有既有测试与新正式测试的 \`matlab.unittest.TestSuite\`。

Expected: 通过数为原 57 加上新测试数，失败为 0。

- [ ] **Step 2: 运行正式 656 点与 24 点 exact 抽查**

Run: \`run_lora_dynamic_doppler_figure17(OutputDirectory=pwd)\`。

Expected: 可由 checkpoint 续跑；不因曲线外观提前停止。

- [ ] **Step 3: 审核输出**

\`\`\`matlab
results = readtable("dynamic_doppler_ber_results.csv",TextType="string");
assert(height(results) == 656);
assert(all(results.total_bits > 0));
assert(all(results.bit_errors >= 0));
assert(all(isnan(results.ber) == (results.bit_errors == 0)));
assert(all(results.fft_bin_mapping_valid));
paired = readtable("dynamic_doppler_ber_exact_validation.csv");
assert(height(paired) == 24);
\`\`\`

- [ ] **Step 4: Code Analyzer、中文报告与提交**

Run \`checkcode\` 检查全部新增/修改 MATLAB 文件。报告所有 paired 不一致点、资源峰值、NaN 范围和任何与论文趋势的差异；不调整结果。

\`\`\`powershell
git add dynamic_doppler_ber_results.csv dynamic_doppler_ber_figure17.png dynamic_doppler_ber_figure17.pdf dynamic_doppler_ber_metadata.json dynamic_doppler_ber_report.md dynamic_doppler_ber_exact_validation.csv test_dynamic_doppler_ber_figure17_results.txt
git commit -m "test: run formal Figure 17 Doppler BER scan"
\`\`\`

## 自审

- 覆盖主配置、停止条件、零错误、种子、paired exact、原始计数、图/metadata/报告及真实 MATLAB 执行。
- 文件职责分离：配置、正式化、paired 内核、runner、测试。
- 未包含空缺工作标记；所有后续接口均在前置任务定义。

