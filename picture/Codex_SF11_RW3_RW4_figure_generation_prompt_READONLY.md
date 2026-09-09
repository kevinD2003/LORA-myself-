# Codex 提示词：SF11 研究工作三、四正确图形生成与审计

## 零、强制只读与集中输出要求

**这是最高优先级要求。**

1. 原项目必须保持只读，禁止修改、覆盖、重命名、删除任何原有文件。
2. 禁止在原项目目录中新增 `.m`、`.mat`、`.fig`、`.png`、`.md`、`.csv` 或任何临时文件。
3. 禁止修改以下规范工程中的任何 MATLAB 代码：
   ```text
   Lora(eg)/project/orbit_doppler/satellite_fig3_rolling8
   ```
4. 如果为了出图需要新增 MATLAB 脚本，只允许在独立输出目录中创建；该脚本只能调用原项目函数和读取原项目结果，不得回写原项目。
5. 所有新生成的结果必须集中放入**一个独立输出文件夹**，例如：
   ```text
   RW3_RW4_SF11_PPT_FIGURES
   ```
6. 该输出文件夹必须放在原项目之外，建议：
   ```text
   D:\codex_output\RW3_RW4_SF11_PPT_FIGURES
   ```
   如果该路径不存在，可创建；但不得在原项目树内创建输出目录。
7. 所有结果，包括：
   - PNG
   - FIG
   - MAT
   - 审计 MD
   - 新增绘图脚本
   - 必要的 CSV/JSON
   - 运行日志
   都必须放入上述同一个独立输出文件夹。
8. 不允许把结果分散写到原项目的 `results`、`figures`、`output` 或其他已有目录。
9. 原项目只允许：
   - 读取源码；
   - 调用已有函数；
   - 读取已有结果；
   - 执行只读式仿真。
10. 如果现有运行入口会默认向原项目写文件，禁止直接运行该入口；应在独立输出目录中写一个包装脚本，将所有输出重定向到独立输出目录后再运行。
11. 最终必须额外生成：
   ```text
   PROJECT_READONLY_AUDIT.md
   ```
   其中明确记录：
   - 原项目路径；
   - 原项目在任务前后的 Git status / 文件哈希检查结果；
   - 是否有原文件被修改；
   - 是否有新文件写入原项目；
   - 结论必须为：`NO PROJECT FILE MODIFIED`。
12. 如果无法保证原项目不被修改，则停止执行，不要生成结果。

最终交付应是**一个文件夹**：
```text
RW3_RW4_SF11_PPT_FIGURES/
```

其中包含全部新生成内容，不修改原项目。

请只基于当前 SF11 规范 Stage55 工程，重新审计并生成我的硕士开题 PPT 中“研究工作三”和“研究工作四”的正确图像。

## 一、唯一允许使用的工程基线

项目根目录：

```text
Lora(eg)/project/orbit_doppler/satellite_fig3_rolling8
```

禁止：

1. 使用 SF12 工程来定义主研究内容；
2. 使用旧 orbit_doppler demo 图冒充该规范工程结果；
3. 为了适配 PPT 而修改算法逻辑；
4. 造数据、平滑、插值、重绘假曲线。

我需要的主研究基线必须是 SF11 规范工程。

## 二、先固定当前真实配置

请首先从 `satelliteFig3Config.m` 验证并记录以下参数：

- SF = 11
- BW = Fs = 250 kHz
- fc = 868 MHz
- CR = 3
- bootstrapPilotCount = 8
- payloadSymbolCount = 112
- virtualPilotHistoryLength = 8
- maxSenLoRaIterations = 5
- confidenceAlpha = 0.8
- confidenceThresholdScale = 1.0
- amendLlrMix = 0.5
- senloraMinimumMarginRatio = 0.15
- senloraRequireSoftHardAgreement = true
- senloraUseSoftDecodedPilotLabels = false
- senloraUseCausalConfidenceTiming = true
- residualPeakRatioThreshold = 1.05
- decisionPeakRatioThreshold = 1.05
- historyDecay = 0.85
- huberThresholdBins = 0.15
- residualSearchBins = -0.5:0.1:0.5
- maxRateBinsPerSec = 2.0
- senloraRateReleasePilotCount = 2
- senloraRateTrackingDeviationLimitBinsPerSec = 0.1
- senloraVirtualPilotInnovationGain = 0.35
- senloraPhasePairInnovationGain = 0.60
- senloraVirtualPilotCfoStdBins = 0.075
- senloraPhasePairInnovationLimitBins = 0.10
- senloraPhasePairAgreementLimitBins = 0.15
- senloraVirtualPilotRateStdLimitBinsPerSec = 0.10

生成一份：

```text
RW3_RW4_SF11_FIGURE_AUDIT.md
```

在该审计文件中写清楚以上参数的代码来源。

## 三、研究工作三的正确含义

研究工作三标题固定为：

> 基于软译码置信信息的可靠虚拟导频构造方法

必须严格按以下函数的真实实现来理解和出图：

1. `satelliteFig3SenLoRaConfidence.m`
2. `satelliteFig3SenLoRaIterativeDecode.m`
3. `satelliteFig3SenLoRaVirtualPilotDecode.m`

必须在审计中明确说明以下真实链路：

1. 对补偿后的每个 symbol 做 FFT；
2. 由 FFT energy 构造 log-probability；
3. 由 Gray 映射构造每个 bit 的 LLR；
4. 进行 soft Hamming(7,4) 译码；
5. 由最佳和次佳码字评分差构造 codeword margin；
6. 由 amended LLR 构造 symbol confidence；
7. 用 block threshold 和 EMA global threshold 判断 confident symbol；
8. proposed candidate 不是 final VP；
9. 还需要 margin ratio 约束；
10. 还需要 soft-hard agreement；
11. 还需要 two-pass stability；
12. 注意：`senloraUseSoftDecodedPilotLabels = false`，
    所以 soft Hamming 只决定“是否可信”，
    真正送入 VP tracker 的标签来自补偿后的 hard LoRa decision，
    不能把 soft-decoded label 误写成 VP 实际标签。

## 四、研究工作三需要生成的图

请生成图 1：

```text
fig_rw3_sf11_confidence_timeline.png
fig_rw3_sf11_confidence_timeline.fig
fig_rw3_sf11_confidence_timeline.mat
```

要求：

- 必须来自真实运行数据；
- 不允许手工构造；
- 白底，适合 16:9 PPT，坐标轴清晰，字体 >= 12 pt；
- 采用 3~4 个 panel。

建议内容：

### Panel A
`confidence C_m` 随 payload symbol index 的变化；  
同时画 `tauBlock` 与 `tauGlobal`（或用最合适方式可视化阈值）。

### Panel B
`proposed symbols` 与 `stable symbols` 的时间位置；  
明确标出：

- confident/proposed
- stable after two-pass confirmation

### Panel C
`margin ratio` 或 `soft-hard agreement` 的通过情况；  
必须使用当前真实变量，不允许自造逻辑。

### Panel D（可选）
最终进入 tracker 的 `requested mask / accepted mask` 对比。

请在图注和保存的 mat 中记录：

- symbol index
- confidence
- tauBlock
- tauGlobal
- proposed mask
- stable mask
- accepted mask
- decoded waveform bin / hard waveform bin（如果图中使用）

请生成图 2：

```text
fig_rw3_sf11_vp_admission_waterfall.png
fig_rw3_sf11_vp_admission_waterfall.fig
fig_rw3_sf11_vp_admission_waterfall.mat
```

要求：

做一个真实的逐级筛选统计图，表示 112 个 payload symbols 如何一步步筛成最终可用 VP。

请统计至少以下各阶段的数量：

1. total payload symbols = 112
2. confidence pass
3. margin-ratio pass
4. soft-hard agreement pass
5. two-pass stable
6. tracker finally accepted

说明：

- 所有数量必须由真实运行结果统计；
- 不能凭感觉填写；
- 如果一个条件已经隐含在前一步，请仍然明确统计；
- 图形可用 waterfall、bar chart 或 funnel chart；
- 在 mat 文件中保存各阶段名称和数量。

## 五、研究工作四的正确含义

研究工作四标题固定为：

> 基于可靠虚拟导频的 Rolling-8 因果动态多普勒跟踪与补偿

必须严格按以下函数的真实实现理解和出图：

1. `satelliteFig3RollingPilotTracker.m`
2. `satelliteFig3PhaseRotationEstimate.m`
3. `satelliteFig3CrossFrameRateUpdate.m`
4. `satelliteFig3SenLoRaVirtualPilotDecode.m`

必须在审计中明确说明以下事实：

1. 前 8 个已知前导首先填满 rolling history；
2. 后续每接受一个 VP，只替换最旧槽位；
3. active history 始终不超过 8；
4. residual CFO 搜索范围真实为 `-0.5:0.1:0.5 bin`；
5. innovation limit 实际为 `0.22 bin`；
6. residual 和 decision peak ratio threshold 都是 `1.05`；
7. `historyDecay = 0.85`；
8. `huberThresholdBins = 0.15`；
9. isolated frame 的初始 rate 来自 known-preamble phase fit；
10. continuous pass 可由 preceding-frame preamble CFO 提供 causal rate；
11. receiver 不能读取 orbit truth / payload truth；
12. truth 只允许作为离线评价叠加曲线。

## 六、研究工作四需要生成的图

请生成图 3：

```text
fig_rw4_sf11_causal_tracking.png
fig_rw4_sf11_causal_tracking.fig
fig_rw4_sf11_causal_tracking.mat
```

要求：

- 必须来自真实运行结果；
- 采用 3 个 panel；
- 白底，适合 16:9 PPT。

### Panel A
true CFO trajectory vs receiver predicted/estimated CFO trajectory。

必须标出：

- 8 preamble observations
- accepted VP update locations
- rejected candidates（若有合适变量）
- truth 只是 evaluation overlay，不得参与 receiver

### Panel B
true Doppler rate vs estimated/predicted Doppler rate。

必须严格对应当前真实实现。  
如果该图的 rate 来源分 isolated / continuous 两类，请在图注中说明。

### Panel C
active rolling history count 或 rolling history index evolution。

目标是直接证明：

- rolling history 是真的；
- history 长度不超过 8；
- VP 进入后在替换最旧观测，而不是无限累积。

mat 文件中至少保存：

- symbol indices / time axis
- true CFO
- predicted CFO
- true Doppler rate
- predicted Doppler rate
- accepted VP mask
- active history count
- relevant history index trace（若可导出）

请生成图 4：

```text
fig_rw4_sf11_residual_rolling8.png
fig_rw4_sf11_residual_rolling8.fig
fig_rw4_sf11_residual_rolling8.mat
```

要求：

采用 2 个 panel。

### Panel A
true CFO - predicted CFO 的误差轨迹，优先单位用 FFT bin：

```text
error_bin[m] = trueCfo[m] - predictedCfo[m]
```

如果当前 `predictedCfo` 与 `trueCfo` 已经在 bin 单位，则直接画 bin；  
不要再换算成 Hz，除非另存一版附图。

请同时画参考线：

```text
+0.5 bin
-0.5 bin
```

并标出 accepted VP update locations。

### Panel B
rolling-8 窗口演化图。

可选方式：

1. 画 active history count；
2. 或画 8 个槽位中的观测索引随 symbol 更新的变化；
3. 或用 image/heatmap 展示 ring buffer 内容更新。

目标是让人一眼看出：

- 8前导先填满；
- VP 一来只替换最旧一个；
- 始终保持 rolling-8。

## 七、运行与复现要求

在 `RW3_RW4_SF11_FIGURE_AUDIT.md` 中，对每一张图必须写清楚：

1. Git commit SHA
2. project root
3. run command
4. 调用的主函数
5. 输入 MAT / workspace / result struct
6. 每条曲线对应的 MATLAB variable name
7. 每条 threshold 的代码来源
8. 每个 proposed/stable/accepted marker 的变量来源
9. truth 是否被使用，使用位置是什么
10. receiver 是否读取 truth（必须明确写 NO）
11. 输出 PNG/FIG/MAT 路径

## 八、图像样式要求

- MATLAB 原生绘图，不要 Python 重绘实验曲线；
- 白色背景；
- 线宽 >= 1.5；
- marker 清晰；
- 字体 >= 12 pt；
- 坐标轴标签 >= 11 pt；
- 图例不要遮挡主要曲线；
- 保存 PNG 分辨率 300 dpi；
- 同时保存 FIG 和 MAT；
- 标题不要夸大，比如不要写 “formal superiority”，除非代码目录中已经存在正式独立验证结果。

## 九、失败处理

如果当前工程没有足够的真实变量直接支撑我要求的某张图，不要造数据。

请在 `RW3_RW4_SF11_FIGURE_AUDIT.md` 中明确写：

```text
当前项目不足以直接生成该图
```

并说明：

- 还缺哪一个变量；
- 需要从哪一个运行入口补采；
- 推荐如何最小化增量生成。

## 十、最终输出

最终只允许交付一个独立文件夹：

```text
RW3_RW4_SF11_PPT_FIGURES/
```

该文件夹中至少包含：

1. `RW3_RW4_SF11_FIGURE_AUDIT.md`
2. `PROJECT_READONLY_AUDIT.md`
3. 4 张主图的 PNG / FIG / MAT
4. 所有为本任务新增的绘图/包装 MATLAB 脚本
5. 必要的运行日志或中间结果文件
6. 一段 summary，说明：
   - 哪一张适合放研究工作三第一页
   - 哪一张适合放研究工作三第二页
   - 哪一张适合放研究工作四第一页
   - 哪一张适合放研究工作四第二页
   - 哪些属于 mechanism figure
   - 哪些属于 result figure

## 最终一致性标准

我的标准不是“图看起来合理”，而是必须满足：

```text
公式定义 = MATLAB代码实现 = 导出变量 = 最终图像含义
```
