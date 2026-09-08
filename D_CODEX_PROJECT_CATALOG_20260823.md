# D:\codex 项目目录与代码说明报告

生成日期：2026-08-23  
适用环境：MATLAB R2022a / Windows 11

## 1. 总览

`D:\codex` 当前约 207.9 MiB，包含一条主要研究链和两套独立复现实验：

```text
参考论文
   ├─ Orthogonality Analysis：轨道、可见窗口、动态 Doppler
   ├─ SenLoRa：LLR、软 Hamming、置信符号
   ├─ 黄鹏论文与师兄代码：PREC/PRC 相位旋转频偏估计
   └─ Farhat 等：Point / Midamble-Point Doppler 补偿
             │
             ├──────────────┐
             ▼              ▼
lora(CFO)              师兄代码
轨道与 Doppler 基础      原始 PREC/PRC 来源
             │              │
             └──────┬───────┘
                    ▼
               Lora(eg)
      当前 SenLoRa / Stage55 规范项目
                    │
                    ├─ Huang-PREC 与 SenLoRa 公平比较
                    └─ fuxianduibi：Midamble-Point 三方法复现

独立复现：Doppler Estimation and Compensation Techniques
历史实验：Lora(theory)
```

### 1.1 一级目录状态

| 文件夹 | 大小 | 定位 | 当前建议 |
|---|---:|---|---|
| `Lora(eg)` | 104.5 MiB | 当前 SenLoRa 与 Stage55 主项目 | **主要开发入口** |
| `lora(CFO)` | 4.9 MiB | 轨道、多普勒、基础 CSS/AWGN 模型 | 作为物理模型参考 |
| `Lora(theory)` | 34.4 MiB | 理论 BER、早期调试与旧 Stage 副本 | 历史参考，不继续开发 |
| `Doppler Estimation and Compensation Techniques` | 15.7 MiB | Farhat Midamble-Point 独立复现 | 独立项目，可单独运行 |
| `师兄代码` | 28.3 MiB | 黄鹏论文配套/相关 MATLAB 原始代码 | 只读基线来源 |
| `参考论文` | 28.1 MiB | 7 篇论文与中文译本 | 理论依据 |
| `lora（prec）` | 0 MiB | 旧工作副本留下的空目录 | 关闭占用它的 MATLAB 后删除 |

如果只想继续当前论文工作，应从以下目录进入：

`D:\codex\Lora(eg)\senlora_orbit_doppler\satellite_fig3_rolling8`

---

## 2. `Lora(eg)` - 当前主项目

### 2.1 项目目标

该目录最初用于复现 SenLoRa 论文中的置信符号检测，后来扩展为完整的卫星动态
Doppler 接收机项目。它把以下内容连接成一条可运行链路：

1. LoRa CSS 调制、解啁啾和 FFT 检测；
2. FFT 概率到 Gray-bit LLR；
3. Hamming(7,4) 硬/软译码；
4. SenLoRa 置信符号筛选；
5. LEO 轨道、可见窗口、逐采样动态 Doppler 和连续相位；
6. Huang-PREC、SenLoRa VP-quality 和 Midamble-Point 公平比较；
7. BER、SER、CFO RMSE、PER、goodput 与复杂度审计。

### 2.2 根目录代码链

#### LoRa 波形与检测

- `loraBaseUpchirp.m`：生成基础上啁啾。
- `modulateLoRaSymbol.m`：生成指定 LoRa 符号波形。
- `synthesizeLoRaSignalSequence.m`：构造前导和载荷连续 IQ。
- `dechirpLoRaSignalSequence.m`：按符号解啁啾并计算单位化 FFT。
- `detectLoRaSignalSequence.m`：从 IQ 到符号判决的外层接口。
- `hardDemodLoRaWithCfo.m`：给定 CFO 补偿量进行硬判决。

#### SenLoRa 软信息与置信度

- `fftToBinLogProb.m`：FFT 频点功率转对数概率。
- `loraGrayBits.m`：LoRa Gray 映射。
- `binLogProbToLlr.m`：频点概率转 bit LLR。
- `softHammingDecodeOne.m` / `softHammingDecodeBlock.m`：ML 软 Hamming 译码。
- `symbolConfidence.m`：形成符号置信度。
- `updateConfidenceThreshold.m`：块阈值与全局 EMA 阈值。
- `detectConfidentSymbolsFromFft.m`：单块置信符号检测主链。
- `iterativeSoftDemodBlockFromFft.m`：最多多轮软判决与置信更新。
- `stepSenLoRaSymbolDetector.m` / `detectContinuousSymbolSequence.m`：流式和序列接口。

#### 早期预测 Doppler 补偿

- `buildDopplerCfoTrajectory.m`：生成符号级 CFO 轨迹。
- `generateDopplerLoRaSymbols.m`：连续 CFO 相位加噪波形。
- `estimateResidualByPhaseRotation.m`：0.1-bin 相位旋转残差搜索。
- `predictiveDopplerCompensate.m`：利用可靠符号更新下一符号 CFO 和相位。

### 2.3 根目录可运行入口

| 入口 | 用途 |
|---|---|
| `run_senlora_confidence_demo` | 最小置信符号检测演示 |
| `run_senlora_continuous_demo` | 连续符号、正确/错误/置信标记演示 |
| `run_predictive_doppler_ber_demo` | 预测 Doppler 补偿 BER 对比 |
| `run_sf11_variable_doppler_ber` | SF11、250-750 Hz/s 动态 Doppler 实验 |
| `runSenLoRaProjectTests` | 整个规范项目统一回归 |

统一回归命令：

```matlab
cd('D:\codex\Lora(eg)')
runSenLoRaProjectTests
```

当前最终状态为 86/86 通过。

### 2.4 `senlora_orbit_doppler`

这是从根目录原型分离出来的卫星轨道工作区。主要入口包括：

- `run_senlora_orbit_model_demo.m`：单设备轨道频移和频移率。
- `run_senlora_continuous_orbit_demo.m`：连续 SF11 帧与相位边界。
- `run_senlora_virtual_pilot_demo.m`：虚拟导频跟踪机制。
- `run_senlora_confidence_orbit_demo.m`：轨道信道下 SenLoRa 置信迭代。
- `run_senlora_ber_smoke.m`：短 BER 检查。
- `runSenLoRaOrbitBer.m`：可续跑 BER 扫描。

这个目录中的早期 formal BER 入口仍可用于学习，但当前正式版本已经下沉到
`satellite_fig3_rolling8`。

### 2.5 `satellite_fig3_rolling8` - 唯一规范 Stage55

这是当前最重要的目录。

固定物理条件：

- SF=11，BW=Fs=250 kHz，fc=868 MHz；
- 550 km LEO，倾角 15 度；
- 8 个已知零前导，112 个载荷符号；
- CR=3，对应 Hamming(7,4)；
- 逐采样完整 RF Doppler；
- 跨符号、跨帧连续相位；
- 活跃导频历史固定为 8 槽。

#### 物理信道

- `satelliteFig3Config.m`：全部冻结参数。
- `satelliteFig3Trajectory.m`：轨道距离、径向速度、Doppler shift/rate。
- `satelliteFig3VisibilityWindow.m`：可见区和中央盲区。
- `satelliteFig3ContinuousPassSchedule.m`：508 帧完整过境调度。
- `generateContinuousSatelliteFrame.m`：逐采样波形、噪声、连续 Doppler 相位。

#### 编码与判决

- `satelliteFig3GeneratePayload.m`：确定性载荷、编码和交织。
- `satelliteFig3DiagonalInterleave.m` / `...Deinterleave.m`：LoRa 对角交织。
- `satelliteFig3HardDecision.m`：FFT 硬符号判决。
- `satelliteFig3HardPayloadBits.m`：硬 Hamming 载荷输出。
- `satelliteFig3SenLoRaConfidence.m`：公共 ML-soft Hamming 输出和置信特征。

#### Huang-PREC 参考接收机

- `satelliteFig3PaperPrecDecode.m`：严格保留黄鹏论文式 (4-1)-(4-7) 的原始模型。
- `satelliteFig3HuangPrecCpBootstrapEstimate.m`：连续相位下逐前导 FFT 功率合并。
- `satelliteFig3HuangPrecStaticCpDecode.m`：一次估计、载荷期固定 CFO。
- `satelliteFig3HuangPrecCpMatchedDecode.m`：与 SenLoRa 共用 ML-soft Hamming 的公平输出。

严格论文版用于模型溯源；连续相位公平正式基线使用
`satelliteFig3HuangPrecCpMatchedDecode.m`。

#### SenLoRa 接收机

- `satelliteFig3RollingPilotTracker.m`：rolling-8 CFO/速率/相位状态。
- `satelliteFig3CrossFrameRateUpdate.m`：跨帧前导 CFO 因果速率估计。
- `satelliteFig3SenLoRaIterativeDecode.m`：置信筛选、虚拟导频提议和多轮解码。
- `satelliteFig3SenLoRaVirtualPilotDecode.m`：Stage55 VP-quality 对外接口。
- `satelliteFig3PilotConfidenceFeatures.m`：虚拟导频质量特征。
- `satelliteFig3PhaseRotationEstimate.m`：接收机可见的残差 CFO 搜索。

虚拟导频标签来自补偿后的硬 LoRa 判决，最终 delivered BER 来自公共 ML-soft
Hamming；接收机接口不接收载荷真值。

#### 当前主要实验入口

| 入口 | 用途 | 运行成本 |
|---|---|---|
| `run_stage55_huang_prec_cp_fresh_replay` | Huang-PREC 公平完整重放 | 长 |
| `run_stage55_vp_mechanism_ablation` | NoVP/VP 机制消融 | 中到长 |
| `run_stage55_vp_quality_fresh_overall_report` | 生成窗口、区域和复杂度总报告 | 中 |
| `plot_stage55_senlora_prec_ser_ber_trajectory` | 仅重绘 SenLoRa/PREC 的 SER、BER 轨迹图 | 短 |
| `runStage55ProjectTests` | Stage55 与复现子项目回归 | 约 1-2 分钟 |

当前用户所需双方法图入口：

```matlab
cd('D:\codex\Lora(eg)\senlora_orbit_doppler\satellite_fig3_rolling8')
plot_stage55_senlora_prec_ser_ber_trajectory
```

图中只有 `PREC (Huang)` 和 `SenLoRa`，通信指标只有 SER 与共同 ML-soft Hamming
之后的 BER；Doppler shift/rate 作为轨迹背景。当前 SER、BER 对数纵轴均为
`10^-5` 到 `10^0`。

#### 正式保留结果

`results` 只保留九组正式或当前测试必需结果：

- Stage45 正式 BER；
- Stage53 五次完整轨次；
- Stage54 复杂度/goodput；
- Stage55 VP-quality 源记录和冻结旧报告；
- Huang-PREC 公平比较；
- 双方法 SER/BER 轨迹图；
- VP 频率质量审计；
- VP-quality 最终评估。

### 2.6 `fuxianduibi`

该子项目把 Farhat 论文的 Midamble-Point 方法移植到 Stage55 的相同 SF11、
BW250 kHz、704 信息 bit、112 数据符号、轨道、噪声和种子条件中，对比：

1. Huang-PREC-CP；
2. Stage55-VP-quality；
3. Paper-Midamble-Point。

根据论文式 (19)-(20)，在当前带宽下 `n_int=48`，在数据符号 48 和 96 后插入
两个显式纯上啁啾。Huang 与 SenLoRa 不把它们作为跟踪观测，只有论文接收机使用。

主要入口：

- `run_fuxian_smoke.m`：四帧小规模接线验证；
- `run_fuxian_stage55_three_method_replay.m`：三路共用账本重放；
- `build_fuxian_stage55_report.m`：只生成 SER、delivered BER 两张主图；
- `run_fuxian_full.m`：完整重放和报告；
- `run_fuxian_tests.m`：子项目测试。

### 2.7 使用结论

- 新代码只写入 `Lora(eg)` 的规范 Stage55 目录。
- `CANONICAL_PROJECT.md`、`PROJECT_STATE.md` 和 `VALIDATION_20260823.md` 是恢复上下文的首要文档。
- 不从 `Lora(theory)` 或旧 `lora（prec）` 目录继续累计正式结果。

---

## 3. `lora(CFO)` - 轨道和动态 Doppler 基础项目

### 3.1 项目定位

该目录是当前卫星项目的物理模型来源。它先独立复现 LoRa CSS AWGN BER，再实现
论文 Figure 3/Figure 17 的轨道、可见窗口、符号内动态 Doppler 和无补偿 BER。

### 3.2 核心代码

#### 基础 LoRa CSS

- `lora_css_modulate.m`：单位样本功率 LoRa CSS 调制。
- `lora_css_demodulate.m`：解啁啾、FFT 最大值非相干检测。
- `lora_css_theoretical_ber.m`：相同检测器的 AWGN 理论 BER。
- `run_lora_css_awgn_reproduction.m`：SF7-SF12 Monte Carlo 和理论曲线。

#### 轨道模型

- `lora_orbit_doppler_config.m`：轨道和射频参数。
- `lora_orbit_doppler_trajectory.m`：距离、径向速度、频移和频移率。
- `lora_visibility_window.m`：单设备可见时间窗。
- `lora_figure17_geometry.m`：两地面设备共享窗口。
- `run_lora_doppler_figure3.m`：Figure 3 风格轨迹图。

#### 动态波形

- `lora_symbol_instantaneous_frequency.m`：包含啁啾回绕的瞬时频率。
- `lora_doppler_piecewise_linear.m`：精确轨迹与符号内线性近似。
- `apply_lora_dynamic_doppler.m`：逐采样 Doppler 相位和 AWGN。
- `lora_css_demodulate_dynamic_channel.m`：不补偿直接检测。

#### BER 入口

- `run_lora_dynamic_doppler_ber_smoke.m`：小规模趋势检查。
- `run_lora_dynamic_doppler_figure17_pilot.m`：可续跑粗网格。
- `run_lora_dynamic_doppler_figure17.m`：正式 Figure 17 BER 扫描。
- `lora_dynamic_doppler_formalize_result.m`：零错误和置信界显示口径。

### 3.3 与主项目的关系

当前 Stage55 采用它验证过的单设备 Figure 3 轨道思想，但已将所需函数复制、整理并
独立测试，因此运行 `Lora(eg)` 时不需要把本目录加入 MATLAB path。

### 3.4 当前建议

这是“物理模型验证项目”，不是当前算法结果目录。用于检查轨道公式或回溯早期 Figure
17 实验时再进入，不要把它的旧 BER 表直接与 Stage55 的 SF11/BW250/FEC 结果合并。

---

## 4. `Lora(theory)` - 理论与历史实验库

### 4.1 根目录

根目录复现标准 LoRa CSS AWGN BER：

- SF7-SF12，BW=125 kHz；
- 单位样本功率、理想同步、复 AWGN；
- 解啁啾加 FFT 最大值检测；
- 自适应 Monte Carlo；
- `run_lora_css_awgn_reproduction.m` 是主入口。

在 BER=10^-4 附近，报告给出的 SF7-SF12 门限约为
`-7.11/-9.95/-12.67/-15.59/-18.37/-21.19 dB`，体现每增加一个 SF 约 3 dB
处理增益。

### 4.2 `work` 子目录

#### `continuous_pass_prec_vs_senlora`

早期 Stage1-54 连续过境项目副本，停留在 2026-08-10 左右。它包含 Stage53 五轨次
和 Stage54 复杂度实验的开发历史，但不是当前规范版本。

#### `senior_doppler_extract`

从师兄工程提取的 Doppler/CFO 相关源码、数据和图。主要用于溯源，不应作为当前
MATLAB path 依赖。

#### `lora_prec`

黄鹏 PREC 适配的早期小副本，已被 `Lora(eg)` 中连续相位、公平译码版本取代。

### 4.3 当前建议

把此目录视为历史实验档案。理论 AWGN 函数可用于核对，但 Stage55 代码和正式结果应
以 `Lora(eg)` 为准。

---

## 5. `Doppler Estimation and Compensation Techniques` - Midamble-Point 独立复现

### 5.1 项目目标

`lunwen` 子目录实现 Farhat 等 2025 年论文中的 Doppler 估计与补偿，重点复现：

- SF7 Figure 10/11 左图；
- SF12 Figure 10/11 右图；
- 由论文公式推导的 SF11、`n_int=12` 实验。

比较三种策略：

1. 无 Doppler 理想/基准；
2. Point estimation；
3. Midamble-Point estimation。

### 5.2 目录结构

- `config/`：SF7、SF11、SF12 冻结配置。
- `src/`：LoRa 波形、轨道、Point/Midamble 估计、Rician、AWGN、Monte Carlo。
- `scripts/`：运行、绘图和审计入口。
- `tests/`：协议、估计器、噪声、结果一致性测试。
- `results/`：CSV、FIG、PNG 和 JSON 审计。
- `docs/`：复现边界、SF7/SF11/SF12 报告。
- `reference/`：从论文图中冻结的验收范围，只用于验收，不参与仿真。
- `tmp/`：论文源文件和临时渲染资源，不是算法输入。

### 5.3 关键源码

- `src/circularOrbitDoppler.m`：论文参考轨道模型。
- `src/integratedDopplerTemplate.m`：积分生成时变 Doppler 相位。
- `src/estimateFromDownchirp.m`：Point 估计。
- `src/updateMidamblePointEstimate.m`：论文式 (17) 残差累积更新。
- `src/buildFrameLayout.m`：Point/Midamble-Point 帧时序。
- `src/simulateSerPoint.m` / `runCaseSweep.m`：一个点和完整 SNR 扫描。
- `src/applyUnitPowerAwgn.m`：显式 0 dBW 功率 AWGN，禁止 `measured`。
- `src/wilsonInterval.m`：SER 置信区间。

### 5.4 入口

```matlab
cd('D:\codex\Doppler Estimation and Compensation Techniques\lunwen')
run(fullfile('scripts','runStage1Validation.m'))
run(fullfile('scripts','runSmokeReproduction.m'))
run(fullfile('scripts','runAllReproduction.m'))
run(fullfile('scripts','runSf7Reproduction.m'))
run(fullfile('scripts','runSf11Reproduction.m'))
run(fullfile('scripts','auditProject.m'))
```

### 5.5 当前状态

代码完整性、静态检查和测试通过，但机器审计为 `needs_paper_match`，不是“完全复现
论文”。主要原因是 SF7/SF12 的绝对 SER 尚未全部进入冻结论文图范围，SF12
Midamble-Point ToA 与论文表格还存在约 10.68 ms 不一致。

因此它适合作为独立的可审计复现实验，不应把“曲线方法排序正确”等同于“论文每个点
完全复现”。

---

## 6. `师兄代码` - 黄鹏论文与相关原始 MATLAB 工程

### 6.1 内容

目录包含：

- 199 个 MATLAB 文件；
- 208 个 FIG 文件；
- 62 个 MAT 数据文件；
- 黄鹏硕士论文 PDF；
- CFO、卫星信道、Rayleigh/Rician、多径、交织、编码等多个实验分支。

它是一个研究过程代码集合，不是模块化软件包。许多脚本依赖当前工作目录、局部 MAT
文件、GUI waitbar 和原始随机状态。

### 6.2 与当前项目最相关的代码

#### `CFO相关/频移算法/PREC.m`

单符号演示：

- 生成 8 个已知前导和 1 个载荷；
- 对前导直接复数平均；
- 在 `eta=0:0.1:0.9` 上进行相位旋转；
- 解啁啾 FFT 搜索最大峰；
- 将整数 CFO 与小数 CFO 合并补偿载荷。

#### `CFO相关/频移算法/MonteCarlo_PREC.m`

固定 CFO Monte Carlo：SF12，SNR -25 到 -19 dB。内部使用逐符号局部相位模型，
并调用 `awgn(...,'measured')`。因此它不能直接代表当前连续跨符号卫星波形下的公平
基线。

#### `.../卫星信道/卫星信道/MonteCarlo_BER_RMSE_PRC_EC_TQ28.m`

使用 `TQ28_CFO.mat` 的天启 28 星频移序列，对 PRC 和 EC 比较 BER/RMSE。帧配置、
带宽、SF、噪声和相位连续性与当前 Stage55 不同。

### 6.3 当前项目如何使用它

`Lora(eg)` 没有直接调用师兄脚本，而是：

1. 保留 `satelliteFig3PaperPrecDecode.m` 复现论文 eta/FFT/CFO 逻辑；
2. 用测试检查关键源码 token 与 0.1-bin 搜索分辨率；
3. 对连续相位信号采用逐前导 FFT 功率合并；
4. 两路统一使用相同 ML-soft Hamming 译码；
5. 共享 payload、noise、SNR、轨道和帧账本。

因此本目录应保持只读，作用是“算法来源证据”，不是正式结果生成目录。

---

## 7. `参考论文` - 理论来源

### 7.1 `2025 SenLoRa Integrated Sensing and Communication with Ambient LoRa.pdf`

提出 SenLoRa 环境 LoRa 通感一体化系统。核心是通过 FFT 概率、Gray-bit LLR、软
Hamming 与似然/置信度识别可靠载荷符号，将它们作为通信与感知的额外信息来源。

代码对应：`Lora(eg)` 根目录置信检测链，以及 Stage55 的 SenLoRa 置信虚拟导频。

### 7.2 `2025 Orthogonality Analysis ... Doppler Effect.pdf`

建立 LoRa 卫星 Doppler 下的连续/离散时域波形、相关性、共享可见窗口和轨道参数分析，
并讨论高频移与高频移率对相关性和 BER 的不同影响。

代码对应：`lora(CFO)` 轨道模型和 `Lora(eg)` Stage55 Figure 3 单设备轨迹。

### 7.3 `移动场景下的可靠LoRa通信方法_黄鹏.pdf`

黄鹏硕士论文包含两部分：CFO/时频双选信道 BER 近似，以及基于相位旋转的 PREC
任意 CFO 估计补偿方法。

代码对应：`师兄代码/CFO相关/频移算法` 和 Stage55 Huang-PREC 基线。

### 7.4 `Doppler Estimation and Compensation Techniques ...pdf`

Farhat 等提出 Point、Linear、Midamble-Point、Midamble-Linear 四类 LoRa DtS
Doppler 估计补偿框架，研究 SF、Doppler 和导频间隔之间的折中。

代码对应：独立 `Doppler Estimation.../lunwen` 项目，以及 Stage55 的
`fuxianduibi`。

### 7.5 `LoRa_DtS_Doppler_CN_Rigorous_Translation 翻译.pdf`

上一论文的中文学习译本，用于公式、术语和实验条件核对。它不是 IEEE 官方译文。

### 7.6 `2025 Effective Chirp Modulation ... LEO Satellite IoT.pdf`

面向高动态 LEO IoT 提出低速率优化 LRO 啁啾、CRC 辅助译码、低复杂度同步和
频率跟踪。它提供另一种系统设计路线，目前未直接进入 Stage55 主接收机。

### 7.7 `2026 Error Performance Characterization ...pdf`

给出 LoRa DtS 在干扰、相对时间偏移和频率偏移下的解析 SER/BER 框架，研究 SF、
带宽和终端位置。它适合作为后续扩展干扰和多用户模型时的理论参考。

---

## 8. `lora（prec）` - 空的旧目录

其中旧代码已经验证、合并到规范 Stage55 并移出 `D:\codex`。当前目录为空，只因某个
MATLAB 会话仍持有目录句柄而暂时存在。关闭该 MATLAB 会话后可以删除，不应再放入
任何新代码。

---

## 9. 根目录零散文件

### `新建 Text Document.md`

虽然名称临时，但内容非常重要：它记录了当前 Stage55 的实施方案，包括论文与模块
分工、单设备 Figure 3 轨道、两个场景、120 符号帧、逐采样完整 RF Doppler、连续
相位、8 槽 rolling 导频、SenLoRa 置信链和分层验收。建议后续重命名为明确的方案文档，
例如 `SENLORA_SATELLITE_IMPLEMENTATION_PLAN_CN.md`。

### `实现方案.txt`

当前为空文件，没有实际内容。可删除，或保留给后续非 Markdown 说明。

---

## 10. 论文到代码的快速映射

| 理论/方法 | 主要论文 | 基础代码 | 当前正式代码 |
|---|---|---|---|
| LoRa CSS/AWGN | CSS BER 文献 | `Lora(theory)`、`lora(CFO)` | Stage55 理论 BER 函数 |
| LEO 轨道与可见窗口 | Orthogonality Analysis | `lora(CFO)` | `satelliteFig3Trajectory/VisibilityWindow` |
| 逐采样动态 Doppler | Orthogonality Analysis | `apply_lora_dynamic_doppler` | `generateContinuousSatelliteFrame` |
| SenLoRa 置信符号 | SenLoRa | `Lora(eg)` 根目录 | `satelliteFig3SenLoRaConfidence` |
| PREC/PRC | 黄鹏论文 | `师兄代码` | `satelliteFig3HuangPrecCpMatchedDecode` |
| Midamble-Point | Farhat 等 | `Doppler Estimation...` | `fuxianduibi` |
| DtS 干扰解析 BER | Error Performance Characterization | 暂无完整实现 | 后续扩展方向 |
| LRO/CRC 跟踪 | Effective Chirp Modulation | 暂无主线实现 | 备选系统设计方向 |

---

## 11. 推荐工作方式

### 继续 Stage55 研究

1. 打开 `Lora(eg)/senlora_orbit_doppler/satellite_fig3_rolling8`。
2. 先读 `CANONICAL_PROJECT.md`、`PROJECT_STATE.md`、`VALIDATION_20260823.md`。
3. 修改前确认结果目录使用新名称，不覆盖冻结结果。
4. 修改后运行 `runStage55ProjectTests`。
5. 最终交付前运行根目录 `runSenLoRaProjectTests`。

### 只重绘当前双方法图

运行：

```matlab
plot_stage55_senlora_prec_ser_ber_trajectory
```

不需要重新运行完整 2592 帧仿真。

### 研究 Midamble-Point

- 若按论文原始 SF7/SF12 条件复现，进入 `Doppler Estimation.../lunwen`。
- 若要和 Stage55 同条件比较，进入 `Lora(eg)/.../fuxianduibi`。

### 回看 Huang-PREC 来源

先阅读黄鹏论文，再查看 `师兄代码/CFO相关/频移算法`；正式比较仍运行 Stage55 适配器，
不要直接把师兄脚本输出混入当前结果表。

---

## 12. 当前结论

`D:\codex` 中真正需要继续维护的主项目只有 `Lora(eg)` 的规范 Stage55。其他目录分别
承担物理模型验证、历史实验、独立论文复现、源码溯源和文献参考的角色。保持这些边界，
能够避免旧版本结果、不同 SF/BW/SNR 口径和不同相位模型被混入同一比较。
