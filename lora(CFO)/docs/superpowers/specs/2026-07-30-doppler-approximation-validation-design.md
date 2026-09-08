# Doppler 近似验证设计规范

## 一、范围

本轮增加论文式（18）至式（20）的非 BER 验证，将
`paper_piecewise_linear` 与现有逐采样精确轨道、完整 RF LoRa
Doppler 模型进行比较。

验证分为：

- Part A：Figure 5 风格的单符号验证；
- Part B：逐符号 Doppler 漂移验证。

不得改变现有 AWGN 调制器、解调器、检测器定义、Figure 3 输出和动态信道
默认行为。

## 二、文件及职责

### `lora_figure17_geometry.m`

建立论文 Figure 17 的设备 A、设备 B 轨道配置，根据式（16）推导两个设备
中心可见时刻之差，计算两个单设备可见窗口及其第一段共享可见窗口。

输出中必须分别保存：

- single-device-A 端点；
- 第一段 shared-window 端点；
- high Doppler shift 候选点：shared-window 左端点；
- high Doppler rate 候选点：shared-window 右端点。

模型输入不得硬编码端点时刻。论文近似时刻只能作为 metadata。

### `lora_doppler_piecewise_linear.m`

针对一个 LoRa 符号计算：

- 带回绕的复基带瞬时频率；
- 逐采样精确轨道、完整 RF Doppler 频率；
- 论文分段线性 Doppler 频率；
- 采用梯形积分得到的 exact 和 linear 相位；
- 近似误差统计；
- 公式参数及符号约定诊断量。

公开接口：

```matlab
result = lora_doppler_piecewise_linear( ...
    symbol, sf, startTimeSec, orbitConfig, ...
    BandwidthHz=250e3)
```

### `run_lora_doppler_approx_validation.m`

运行 Part A 和 Part B 的全部组合，生成图、CSV、JSON 和 metadata。
若超过容差，错误信息必须包含场景、SF 和 symbol index。

### `test_lora_doppler_approximation.m`

使用独立的字面参考值和行为断言，测试几何、频率近似、相位积分、FFT
判决和逐符号连续性。

## 三、公共参数

采用：

```text
c = 3e8 m/s
g = 9.8 m/s^2
R = 6371e3 m
omega_E = 7.292e-5 rad/s
H = 550e3 m
i = 15 degrees
fc = 868e6 Hz
B = 250e3 Hz
d = 10e3 m
theta_c_A = 89 degrees
theta_c_B = 89.2 degrees
theta_min_A = theta_min_B = 10 degrees
theta_max_A = theta_max_B = 88 degrees
t_cv_A = 0
```

数值模型内部所有角度均使用弧度。

## 四、场景起始时刻

式（16）和可见窗口交集给出：

```text
single-device-A 第一段窗口：
    [-254.870648405068, -2.344896842552] s

第一段 shared window：
    [-253.364624963310, -2.344896842552] s
```

场景起始时刻为：

- `high_doppler_shift`：第一段 shared window 左端点；
- `high_doppler_rate`：第一段 shared window 右端点。

single-device-A 外端点和论文近似值 `-254.9 s` 必须单独写入
metadata，不得与 shared-window 结果混淆。

## 五、符号选择

每个扩频因子使用：

```text
M = 2^SF
symbol = M/2
```

因此：

- SF7 使用 symbol 64；
- SF12 使用 symbol 2048。

chirp 在半个 symbol period 处发生回绕，使分段线性模型的两段具有相同
长度，能够充分检查回绕项。

## 六、精确逐采样 Doppler

定义：

```text
n = 0,...,M-1
Fs = B
t[n] = t0 + n/Fs
```

计算：

```text
f_bb[n] = B*(mod(n+symbol,M)/M - 1/2)
f_D,exact[n] = -(fc + f_bb[n])*v(t[n])/c
```

每个采样时刻的径向速度均通过
`lora_orbit_doppler_trajectory` 独立计算。

## 七、论文分段线性 Doppler

第一个回绕后采样点的 MATLAB 一基索引为：

```text
wrapIndex = M - symbol + 1
```

初始 Doppler 为：

```text
v_d = f_D,exact[0]
```

按照式（19）和式（20），从完全位于同一非回绕分段内的两个相邻 exact
Doppler 样点估计 `c_d`。对于已确认的中点符号，使用从
`wrapIndex` 开始的回绕后样点对：

```text
c_d = (f_D,exact[wrapIndex+1] -
       f_D,exact[wrapIndex])*Fs
```

`c_d` 单位为 Hz/s。未施加回绕修正的线性基线为：

```text
f_baseline[n] = v_d + c_d*n/Fs
```

## 八、chirp 回绕符号约定

论文印刷式（18）为：

```text
f_D,linear = v_d + c_d*t - Delta_f_k
```

论文同时印刷：

```text
Delta_f_k = B*v(t_wrap)/c
```

本项目采用 `v=d(rho)/dt`，即距离增加时速度为正。按照这一有符号速度
约定，如果把印刷值 `B*v/c` 直接代入减法形式，会使回绕处的频率跳变
方向与 exact Doppler 相反；high-shift 场景的最大误差会达到约
`10.7 Hz`。

因此实现必须同时记录：

```text
paper_printed_Bv_over_c_hz = B*v(t_wrap)/c
applied_delta_f_k_hz = -B*v(t_wrap)/c
```

并继续使用式（18）的减法形式：

```text
回绕前：
    f_D,linear[n] = f_baseline[n]

从第一个回绕后样点开始：
    f_D,linear[n] =
        f_baseline[n] - applied_delta_f_k_hz
```

此时 `applied_delta_f_k_hz` 表示回绕前 Doppler 与回绕后 Doppler 的
修正量，能够保持 exact 频率跳变方向。velocity convention 和两个有符号
数值必须写入 CSV/JSON metadata，不得隐藏。

## 九、相位、时域波形和 FFT 诊断

两组 Doppler 序列均使用相同的梯形积分：

```text
phi[0] = 0
phi[n] = phi[n-1] +
         pi/Fs*(f_D[n-1] + f_D[n])
```

对于选定的 LoRa 符号：

```text
r_exact[n] = x[n]*exp(j*phi_exact[n])
r_linear[n] = x[n]*exp(j*phi_linear[n])
```

不加入噪声，不进行 Doppler 补偿。两组波形均交给原有非相干
dechirp-FFT-argmax 检测器。

记录：

- `mean_abs_error_hz`；
- `max_abs_error_hz`；
- `rmse_hz`；
- `phase_rmse_rad`；
- FFT 向量相对差异；
- exact detected peak bin；
- linear detected peak bin。

## 十、Part A：单符号验证

运行四种组合：

| 场景 | SF | Symbol |
|---|---:|---:|
| High Doppler Shift | 7 | 64 |
| High Doppler Rate | 7 | 64 |
| High Doppler Shift | 12 | 2048 |
| High Doppler Rate | 12 | 2048 |

每张 Figure 5 风格图使用：

- x 轴：一个 symbol period 内的时间；
- y 轴：Doppler shift，单位 Hz；
- 蓝色实线：exact Doppler；
- 红色空心圆，不连接：linear approximation。

SF12 的红色标记为保证可读性可以抽取显示，但误差统计必须使用全部
采样点。回绕点前后的标记必须保留。

## 十一、Part B：逐符号漂移验证

对于两个场景和 SF7、SF12：

```text
Nsym = 50
t_m = t0 + m*T_s, m = 0,...,49
```

CSV/JSON 共包含 200 行。

每行记录：

- scenario；
- SF；
- symbol index；
- symbol start time；
- exact 初始 Doppler `v_d`；
- 式（20）斜率 `c_d`；
- carrier-only 轨道 Doppler rate；
- 论文印刷的 `B*v/c`；
- 实际施加的 `Delta_f_k`；
- mean、maximum、RMS 频率误差；
- phase RMSE；
- exact 和 linear detected bin。

drift 图左轴绘制 `v_d`，右轴绘制 `c_d`。error 图同时绘制平均绝对频率
误差和 phase RMSE。

## 十二、数值验收标准

### Part A 单符号一致性

每个组合必须满足：

```text
mean_abs_error_hz <= 5e-4
max_abs_error_hz  <= 1e-3
rmse_hz           <= 6e-4
phase_rmse_rad    <= 2e-5
FFT relative difference <= 1e-4
```

exact 和 linear detected peak bin 必须为完全相等的整数。

使用已记录 Doppler 频率和规定梯形积分重构 exact 或 linear 相位时：

```text
AbsTol = 1e-12 rad
```

### Part B 逐符号连续性

对每个场景和 SF，`diff(v_d)` 必须与相邻两个 symbol start 的
carrier-only 轨道 Doppler rate 梯形预测一致：

```text
AbsTol = 1e-4 Hz
```

同时要求：

```text
max(abs(diff(c_d))) <= 5 Hz/s
max(abs(diff(applied_delta_f_k_hz))) <= 0.01 Hz
```

每一个 symbol 仍须满足 Part A 的近似误差上限。

任何失败信息都必须包含 scenario、SF 和 symbol index。

## 十三、输出文件

### Part A 图

以下每个文件名均生成 PNG 和 PDF：

- `doppler_approx_figure5_like_high_shift_sf7`
- `doppler_approx_figure5_like_high_rate_sf7`
- `doppler_approx_figure5_like_high_shift_sf12`
- `doppler_approx_figure5_like_high_rate_sf12`

同时生成：

- `doppler_approx_single_symbol_metrics.csv`
- `doppler_approx_single_symbol_metrics.json`

### Part B 图

生成 PNG：

- `doppler_symbol_to_symbol_drift_high_shift_sf7.png`
- `doppler_symbol_to_symbol_drift_high_rate_sf7.png`
- `doppler_symbol_to_symbol_error_high_shift_sf7.png`
- `doppler_symbol_to_symbol_error_high_rate_sf7.png`
- 对应的四个 SF12 PNG 文件。

同时生成：

- `doppler_symbolwise_validation.csv`
- `doppler_symbolwise_validation.json`

### 验证输出

生成：

- `test_doppler_approximation_results.txt`

测试记录必须明确写明未运行 BER，并包含完整测试统计和 Code Analyzer
统计。

## 十四、图形检查

所有图和表必须由 MATLAB 实际生成。四个 PDF 必须重新渲染为图片并检查：

- exact/linear 图例映射正确；
- 坐标轴和单位清晰；
- 回绕行为可见；
- 标签不存在裁切或重叠。

所有 drift/error PNG 也必须进行视觉检查。

## 十五、回归要求

- 运行新增 approximation 测试；
- 运行全部现有轨道及动态信道测试；
- 对全部新增或修改的 MATLAB 文件运行 Code Analyzer；
- 核对原 AWGN 调制器、解调器哈希仍与实施前基准相同；
- 不得改变原检测器，不得加入 Doppler 补偿。

## 十六、审核文件语言

本设计规范及后续实施计划、审查记录和交付说明均使用中文。MATLAB
函数名、字段名、公式变量和输出文件名保留英文，以保证代码接口稳定。
