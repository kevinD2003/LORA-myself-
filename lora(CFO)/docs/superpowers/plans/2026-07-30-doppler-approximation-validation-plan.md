# Doppler 近似验证实施计划

> **供执行代理：** 必须逐任务使用 `executing-plans`；每项均采用复选框跟踪。新增生产函数必须遵循 TDD：先编写并观察失败测试，再写最小实现。

**目标：** 实现论文式（18）至式（20）的单符号及逐符号 Doppler 近似验证，实际生成全部 MATLAB 图、CSV、JSON 和测试记录，不运行 BER。

**架构：** 用独立 Figure 17 几何函数提供公式推导的场景时刻，用独立分段线性函数同时返回 exact 与 linear 频率、相位和误差。运行器只负责批量组合、FFT 诊断和文件输出，不改变现有动态信道或原 AWGN 函数。

**技术栈：** MATLAB R2022a、`matlab.unittest`、MATLAB Code Analyzer、MATLAB `exportgraphics`、CSV/JSON。

## 全局约束

- 目标目录：`D:\codex\lora(CFO)`。
- 原始依赖目录：`D:\codex\Lora(theory)`，只读使用。
- 不运行 BER、干扰、FEC、衰落、多径、CFO、STO 或帧仿真。
- 不修改原 `lora_css_modulate.m` 和 `lora_css_demodulate.m`。
- exact 路径必须使用完整 RF 瞬时频率和逐采样轨道速度。
- exact 与 linear 相位均采用梯形积分。
- 不加入 Doppler 补偿或人工 FFT-bin 平移。
- 审核文件、计划和交付说明均使用中文。
- 目标目录不是 Git 仓库，因此没有提交步骤。

---

### 任务 1：先建立 Figure 17 几何和 approximation 的失败测试

**文件：**

- 新建：`D:\codex\lora(CFO)\test_lora_doppler_approximation.m`
- 待新建：`D:\codex\lora(CFO)\lora_figure17_geometry.m`
- 待新建：`D:\codex\lora(CFO)\lora_doppler_piecewise_linear.m`

**接口：**

- 输入：现有轨道配置、轨道轨迹、可见窗口和 LoRa 瞬时频率函数。
- 输出：能捕获缺失几何函数和缺失分段线性函数的测试。

- [ ] **步骤 1：写 Figure 17 几何失败测试**

测试调用：

```matlab
geometry = lora_figure17_geometry();
```

使用独立字面值断言：

```matlab
verifyEqual(testCase, geometry.deltaTimeABSec, ...
    1.507287527200, "AbsTol", 0.01);
verifyEqual(testCase, geometry.singleDeviceAFirstSec, ...
    [-254.870648405068, -2.344896842552], ...
    "AbsTol", 0.05);
verifyEqual(testCase, geometry.sharedFirstSec, ...
    [-253.364624963310, -2.344896842552], ...
    "AbsTol", 0.05);
```

- [ ] **步骤 2：写四种单符号组合失败测试**

遍历：

```matlab
scenarioNames = ["high_shift", "high_rate"];
spreadingFactors = [7, 12];
```

使用 `symbol=2^(sf-1)`，调用：

```matlab
result = lora_doppler_piecewise_linear( ...
    symbol, sf, startTimeSec, geometry.configA, ...
    BandwidthHz=250e3);
```

逐组合断言：

```matlab
verifyLessThanOrEqual(testCase, result.meanAbsErrorHz, 5e-4);
verifyLessThanOrEqual(testCase, result.maxAbsErrorHz, 1e-3);
verifyLessThanOrEqual(testCase, result.rmseHz, 6e-4);
verifyLessThanOrEqual(testCase, result.phaseRmseRad, 2e-5);
```

- [ ] **步骤 3：写相位积分一致性测试**

独立重构：

```matlab
expectedPhase = [0; cumsum(pi/result.sampleRateHz*( ...
    result.exactDopplerHz(1:end-1) + ...
    result.exactDopplerHz(2:end)))];
verifyEqual(testCase, result.exactPhaseRad, ...
    expectedPhase, "AbsTol", 1e-12);
```

linear 相位采用相同方式独立重构。

- [ ] **步骤 4：写 FFT 峰值一致性测试**

测试使用原调制器，分别施加 exact 和 linear 相位：

```matlab
tx = lora_css_modulate(uint32(symbol), sf);
exactRx = tx.*exp(1i*result.exactPhaseRad);
linearRx = tx.*exp(1i*result.linearPhaseRad);
exactBin = lora_css_demodulate(exactRx, sf);
linearBin = lora_css_demodulate(linearRx, sf);
verifyEqual(testCase, exactBin, linearBin);
```

FFT 向量相对差异必须不超过 `1e-4`。

- [ ] **步骤 5：写 50 符号连续性测试**

对两个场景和 SF7/SF12 生成 50 个连续符号，断言：

```matlab
verifyEqual(testCase, diff(vdHz), expectedVdStepHz, ...
    "AbsTol", 1e-4);
verifyLessThanOrEqual(testCase, max(abs(diff(cdHzPerSec))), 5);
verifyLessThanOrEqual(testCase, ...
    max(abs(diff(appliedDeltaFkHz))), 0.01);
```

每个符号继续检查四项 approximation 误差上限。失败诊断字符串中写入
scenario、SF 和 symbol index。

- [ ] **步骤 6：运行测试并观察 RED**

使用：

```matlab
suite = matlab.unittest.TestSuite.fromFile( ...
    "test_lora_doppler_approximation.m");
results = run(suite);
```

预期：测试因 `lora_figure17_geometry` 或
`lora_doppler_piecewise_linear` 未定义而失败。

---

### 任务 2：实现 Figure 17 几何函数并通过几何测试

**文件：**

- 新建：`D:\codex\lora(CFO)\lora_figure17_geometry.m`
- 测试：`D:\codex\lora(CFO)\test_lora_doppler_approximation.m`

**接口：**

- 消费：`lora_orbit_doppler_config`、`lora_visibility_window`。
- 产出：`geometry` 标量结构体。

- [ ] **步骤 1：实现参数配置**

以 `lora_orbit_doppler_config()` 为基础，设置 A/B 的
`theta_c`、`theta_min`、`theta_max` 和 `t_cv_A=0`，角度立即转换为弧度。

- [ ] **步骤 2：实现式（16）**

使用：

```matlab
deltaTimeABSec = acos(clamp(( ...
    cos(d/R) - sin(gammaB)*sin(gammaA))/ ...
    (cos(gammaB)*cos(gammaA))))/omegaFixed;
```

设置 `configB.centralVisibilityTimeSec=deltaTimeABSec`。

- [ ] **步骤 3：实现窗口交集**

```matlab
sharedFirstSec = [ ...
    max(windowA.intervalsSec(1,1), windowB.intervalsSec(1,1)), ...
    min(windowA.intervalsSec(1,2), windowB.intervalsSec(1,2))];
```

结构体至少返回 `configA`、`configB`、`windowA`、`windowB`、
`deltaTimeABSec`、`singleDeviceAFirstSec`、`sharedFirstSec`、
`highShiftTimeSec` 和 `highRateTimeSec`。

- [ ] **步骤 4：运行聚焦测试**

预期：几何测试通过，其余测试仍因 approximation 函数缺失而失败。

---

### 任务 3：实现论文分段线性 approximation 并完成 GREEN

**文件：**

- 新建：`D:\codex\lora(CFO)\lora_doppler_piecewise_linear.m`
- 测试：`D:\codex\lora(CFO)\test_lora_doppler_approximation.m`

**接口：**

- 消费：`lora_symbol_instantaneous_frequency`、
  `lora_orbit_doppler_trajectory`。
- 产出：包含 exact、linear、相位、公式参数和误差统计的 `result`。

- [ ] **步骤 1：实现输入验证和时间轴**

验证 symbol、SF、带宽、起始时刻和配置字段，建立：

```matlab
m = 2^sf;
sampleRateHz = options.BandwidthHz;
sampleIndex = (0:m-1).';
timeWithinSymbolSec = sampleIndex/sampleRateHz;
sampleTimeSec = startTimeSec + timeWithinSymbolSec;
```

- [ ] **步骤 2：实现 exact 完整 RF Doppler**

```matlab
basebandHz = lora_symbol_instantaneous_frequency( ...
    symbol, sf, sampleRateHz);
orbit = lora_orbit_doppler_trajectory(sampleTimeSec, orbitConfig);
exactDopplerHz = -(orbitConfig.carrierFrequencyHz + basebandHz).* ...
    orbit.radialVelocityMps/orbitConfig.speedOfLightMps;
```

- [ ] **步骤 3：实现式（19）和式（20）的斜率**

对于中点符号：

```matlab
wrapIndex = m - double(symbol) + 1;
slopeFirstIndex = wrapIndex;
slopeSecondIndex = wrapIndex + 1;
cdHzPerSec = (exactDopplerHz(slopeSecondIndex) - ...
    exactDopplerHz(slopeFirstIndex))*sampleRateHz;
vdHz = exactDopplerHz(1);
```

一般 symbol 必须选择同一非回绕分段内的两个有效相邻样点，不能跨越
wrap。

- [ ] **步骤 4：实现带显式符号约定的回绕项**

```matlab
wrapTimeSec = startTimeSec + (wrapIndex-1)/sampleRateHz;
wrapVelocityMps = lora_orbit_doppler_trajectory( ...
    wrapTimeSec, orbitConfig).radialVelocityMps;
paperPrintedBvOverCHz = ...
    sampleRateHz*wrapVelocityMps/orbitConfig.speedOfLightMps;
appliedDeltaFkHz = -paperPrintedBvOverCHz;

linearDopplerHz = vdHz + cdHzPerSec*timeWithinSymbolSec;
linearDopplerHz(wrapIndex:end) = ...
    linearDopplerHz(wrapIndex:end) - appliedDeltaFkHz;
```

- [ ] **步骤 5：实现相位与误差**

exact、linear 均用同一梯形积分。计算并返回：

```matlab
meanAbsErrorHz
maxAbsErrorHz
rmseHz
phaseRmseRad
```

同时返回 `paperPrintedBvOverCHz`、`appliedDeltaFkHz` 和
`velocityConvention="range_rate_positive_receding"`。

- [ ] **步骤 6：运行 approximation 测试并完成 GREEN**

预期：全部新增测试通过，四种组合的 `maxAbsErrorHz` 均小于
`1e-3 Hz`。

---

### 任务 4：实现 MATLAB 批量运行器和全部输出

**文件：**

- 新建：`D:\codex\lora(CFO)\run_lora_doppler_approx_validation.m`
- 生成：规范第十三节列出的图、CSV、JSON。

**接口：**

- 消费：几何函数、approximation 函数、原 LoRa 调制器和解调器。
- 产出：稳定命名的 Part A、Part B 文件。

- [ ] **步骤 1：实现四种 Part A 组合**

保存包含 scenario、SF、symbol、`v_d`、`c_d`、两个回绕符号值、
四项误差、FFT 相对误差及两个 detected bin 的表。

- [ ] **步骤 2：绘制 Figure 5 风格图**

exact 使用蓝色实线；linear 使用红色空心圆且不连线。SF12 的标记最多
约 80 个，但必须额外保留 wrap 前后样点。每图导出 PNG 和矢量 PDF。

- [ ] **步骤 3：实现 200 行 Part B 数据**

遍历两个场景、SF7/SF12、`m=0:49`，计算
`t_m=t0+m*T_s`，保存规范列出的字段。

- [ ] **步骤 4：绘制 drift 和 error 图**

drift 图使用 `yyaxis`：左轴 `v_d`，右轴 `c_d`。error 图使用
`yyaxis`：左轴 `mean_abs_error_hz`，右轴 `phase_rmse_rad`。

- [ ] **步骤 5：写 CSV 和 JSON**

生成：

```text
doppler_approx_single_symbol_metrics.csv
doppler_approx_single_symbol_metrics.json
doppler_symbolwise_validation.csv
doppler_symbolwise_validation.json
```

JSON 同时包含公式推导值、论文近似值、容差、velocity convention 和
`ber_sweep_run=false`。

- [ ] **步骤 6：实际运行 MATLAB 生成文件**

在运行前临时将 `D:\codex\Lora(theory)` 加入 MATLAB path，结束后恢复。
若任意组合超过容差，运行器必须立即报告具体 scenario、SF 和 symbol
index。

---

### 任务 5：完整回归、结果记录和视觉验收

**文件：**

- 生成：`D:\codex\lora(CFO)\test_doppler_approximation_results.txt`
- 验证：全部新增 MATLAB 文件及现有测试。

**接口：**

- 消费：三个 MATLAB 测试套件和 Code Analyzer。
- 产出：无警告、可复核的最终证据。

- [ ] **步骤 1：运行三个测试套件**

运行：

```matlab
test_lora_dynamic_doppler.m
test_lora_dynamic_channel.m
test_lora_doppler_approximation.m
```

结果文件逐项写入 test name、passed、failed、incomplete 和 duration，并
明确写入 `BER_SWEEP_RUN=false`。

- [ ] **步骤 2：运行 Code Analyzer**

至少检查四个新增文件，并对每个文件记录 message count。最终
`ANALYZER_SUMMARY messages=0`。

- [ ] **步骤 3：检查输出完整性**

核对 8 个 Part A 图文件、8 个 Part B PNG、4 个 CSV/JSON 数据文件和
测试记录均存在且非空。

- [ ] **步骤 4：回渲染和视觉检查 PDF**

用 Poppler 将四个 PDF 渲染为 PNG，检查图例、坐标、回绕、裁切和标签。
同时检查 drift/error PNG。

- [ ] **步骤 5：核对原 AWGN 文件哈希**

预期：

```text
lora_css_modulate.m
A054534381C522EFCA0106DB05F08F19F62D4AF38C4CDAE53B791223CA5DDFA2

lora_css_demodulate.m
E631495EE0D082453A61062D820D5B024470500BD37312A69E6B498EC30C8609
```

- [ ] **步骤 6：最终需求扫描**

确认没有 BER 循环、Doppler 补偿、人工 FFT-bin 移位或对原 AWGN
函数的修改。
