# 连续过境双算法实现与审计日志

最后更新：2026-08-10  
目标项目：`D:\codex\lora（prec）\satellite_fig3_rolling8`  
工作镜像：`D:\codex\Lora(theory)\work\continuous_pass_prec_vs_senlora`

## 上下文恢复入口

任何新会话或上下文压缩后，按以下顺序恢复：

1. 完整读取本文件；
2. 读取 `PROJECT_STATE.md`；
3. 读取 `docs\PAPER_PREC_COMPARISON.md`；
4. 仅从本文件“当前阶段”和“下一步”继续，不复用旧 Stage 45/47 统计；
5. 修改接收机后必须新建结果目录、重新累计并记录随机种子。

## 最终目标

在固定 Sample SNR 下，以相对最近过境点的时间为横轴，对一次完整卫星过境中的两种算法进行配对比较：

- `Huang-PREC-static-CP`：连续相位适配的黄鹏8前导CFO估计，随后固定CFO，不使用载荷反馈和多普勒速率；
- `SenLoRa-VP`：使用完全相同的黄鹏CFO与起始相位，同时按原SenLoRa设计从已知前导相位初始化速率，随后只由通过置信与残差门控的虚拟导频更新CFO和速率。

输出时间窗口 BER、PER、残余 CFO、无错误帧 goodput、复杂度和运行时间。主图只把上述两种方法作为算法曲线；理论AWGN与无补偿仅可作为辅助参考。

## 固定物理与帧条件

- 单一地面设备，Figure-3轨迹；
- `SF=11`，`BW=Fs=250 kHz`，`fc=868 MHz`；
- 轨道高度550 km，倾角15度；
- 8个已知零前导 + 112个载荷符号；
- `Ts=2048/250000=8.192 ms`；
- `Tframe=120*Ts=0.98304 s`；
- 多普勒频率逐采样生成；
- 多普勒相位跨符号、跨帧连续积分，禁止在帧边界归零；
- 两种算法逐帧使用相同数据、噪声、轨迹和初始估计；
- 主实验暂不跨帧继承接收机虚拟导频状态，以隔离帧内更新收益；
- 真值只用于BER、CFO误差和误接纳审计，严禁进入接收机接口。

## 阶段0：现状审计

状态：**已完成（尚待同步到目标目录）**

### 已验证事实

1. Stage 45 的 `Hard-decision rolling-8` 和 SenLoRa 并不是“论文PREC与本文算法”比较。二者都使用：
   - 相同轨道速率先验；
   - rolling-8虚拟导频状态；
   - CFO/速率拟合与残差门控。
   中高SNR下二者自然都接近理论线，因此旧图不能回答导师的论文基线问题。

2. Stage 47 的严格论文PREC执行8前导直接复数平均。在当前跨符号连续相位下发生相消，干净前导幅度只保留约14%/20%。该一帧烟雾图不能作为正式BER，也不能把全部差距解释为虚拟导频收益。

3. `satelliteFig3BootstrapEstimate.m` 已经是连续相位安全的已知前导初始化：
   - 对每个前导独立去啁啾并累加FFT功率，粗捕获不依赖符号间整体相位；
   - 对每个前导独立做相位旋转估计；
   - 使用 `satelliteFig3BootstrapJointPhaseEstimate.m` 对连续前导相位作联合拟合；
   - 接口没有轨道真值或载荷真值。
   因此主比较应复用该初始化，不能再另造一套初始捕获器。

4. 当前正式 SenLoRa 包装器 `satelliteFig3AdaptiveRateReplaySenLoRaDecode.m` 会由粗CFO调用 `satelliteFig3OrbitRatePriorFromCfo.m`，并把轨道速率先验送入跟踪器。这不符合新的“两算法只差虚拟导频更新”主比较定义。

### 根因结论

- 旧两线重合：比较方法共享相同动态跟踪骨架，算法差异过小；
- 严格Paper-PREC近随机：连续相位与论文前导直接复数平均假设不兼容；
- 正式新比较必须共享黄鹏CFO与相位初始化。静态PREC按论文边界忽略速率；SenLoRa只由已知前导相位初始化速率，并在获得可信虚拟导频后释放动态拟合。两者均不得使用轨道速率先验。

### 黄鹏源代码约束

主比较的文献基线与共同CFO估计必须基于以下师兄代码：

- `D:\codex\师兄代码\matlab\CFO相关\频移算法\PREC.m`
  - SHA-256：`3AB8FBC23C595485E0CC9E478223C1A4048BD034A666EE97D7499AF55DF77E98`
- `D:\codex\师兄代码\matlab\CFO相关\频移算法\卫星信道\卫星信道\MonteCarlo_BER_RMSE_PRC_EC_TQ28.m`
  - SHA-256：`85E657783A2A791DE2843526334DE6BBAD816CF2050E8D5A164A5D19A1C1CFD1`

保留步骤：`eta=0:0.1:0.9`、相位旋转、去啁啾FFT、全局峰值、`epsilonHat=integerBin-eta`、固定CFO补偿和硬判决。唯一连续相位适配是把8前导的直接复数平均替换为“逐前导相同eta/FFT后累加功率”，避免不同符号整体相位相消。严格原版仍由 `satelliteFig3PaperPrecDecode.m` 保留。

## 新主比较的接收机边界

### Huang-PREC-static-CP

- 正式新路径改为调用 `satelliteFig3HuangPrecCpBootstrapEstimate`，其CFO严格使用黄鹏eta/FFT定义；
- 初始速率固定为0；
- 载荷期间固定CFO和零速率；
- `AcceptedMask` 的载荷部分恒为false；
- 不调用轨道速率先验；
- 不接受任何载荷真值；
- 输出硬LoRa判决和硬Hamming(7,4)信息bit。

### SenLoRa-VP

- 调用同一个 `satelliteFig3HuangPrecCpBootstrapEstimate`，CFO和起始相位与PREC一致；
- 初始速率仅由8个已知前导的连续相位二次拟合得到，不使用轨道模型；
- 至少两个因果可信虚拟导频被接纳后才释放速率拟合；
- 释放后速率由接纳导频估计，不调用轨道速率先验；
- 软信息只控制导频接纳，最终BER仍使用硬LoRa与硬Hamming结果；
- 不接受任何载荷真值。

### 公平性强制测试

- 两算法逐帧 `bootstrap` 结果必须逐元素一致；
- 两算法第一载荷符号的起始相位必须一致；CFO随时间的首次预测允许因SenLoRa使用接收前导估计速率而分开；
- PREC载荷期间不得接纳虚拟导频，预测CFO必须保持固定；
- 改变载荷样本不得改变PREC的初始化和补偿状态；
- 改变或删除仿真真值不得改变两接收机输出；
- 旧Stage 45、Stage 47结果不得混入新结果目录。

## 可见窗口与连续帧待验收边界

`satelliteFig3VisibilityWindow.m` 定义两个可见波束区间，并在最近过境点附近存在模型定义的盲区：

- 外边界：`±deltaTimeOutSec`；
- 中央盲区：`[-deltaTimeInSec,+deltaTimeInSec]`。

阶段2将从外边界进入到外边界离开持续推进全局时间和相位，并显式标记中央盲区。正式统计将同时保存：

- 整个过境时间跨度的诊断结果；
- 仅模型可见帧的通信指标。

阶段2检查后冻结以下规则：

- 主时间轴覆盖从外边界进入到外边界离开的全部508个完整帧时隙；
- 中央盲区保持灰色标记，信道时间与多普勒相位仍连续推进；
- 正式BER/PER只统计432个“整帧完全可见”的帧；
- 74个完全盲区帧与2个边界过渡帧不进入通信BER/PER，避免把未建模的天线遮挡当成AWGN链路；
- goodput同时给出：按完全可见帧通信时间归一化的 active-link goodput，以及按完整过境墙钟时间归一化的 pass-average delivery rate。

## 统计预注册

- 主横轴：`t-t_cv (s)`；
- 时间窗口：候选10 s，阶段3检查实际每窗帧数后冻结；
- 主SNR不根据两算法差距选择，而由理想补偿理论BER目标预注册；
- 候选扫描：`-23:-19 dB`；
- 主点目标：理想补偿BER约 `1e-3`；补充点目标约 `1e-4`；
- 正式结果采用配对数据/噪声；
- 不拟合、不插值、不对单帧BER平滑；
- 零错误点显示一侧95%上界；
- 时间置信区间以完整过境重复为统计单位。

## 实施阶段

| 阶段 | 内容 | 状态 | 主要产物 |
|---|---|---|---|
| 0 | 审计旧BER、冻结接口和实验边界 | 已完成 | 本MD |
| 1 | 共同黄鹏CFO初始化的静态PREC与无轨道先验SenLoRa | 已完成，待用户验收 | 两接收机、测试、初始化检查图 |
| 2 | 跨帧连续相位过境帧流 | 已完成，待用户验收 | 帧流生成器、边界连续性测试、时间检查图 |
| 3 | 单次过境时间轴烟雾图 | 已完成，待用户验收 | BER/PER/CFO/goodput检查图 |
| 4 | 固定SNR预扫描与冻结 | 已完成，待用户验收 | SNR选择记录 |
| 5 | 正式配对Monte Carlo | 累计器与单过境接线完成；正式重复待运行 | 时间主图、CSV、MAT、种子账本 |
| 6 | 复杂度、耗时和有效速率 | 未开始 | 表格与审计报告 |

## 阶段1验证结果

结果目录：`results\stage48_common_bootstrap_validation`

无噪声机制检查：

| 场景 | Huang-PREC-static-CP CFO RMSE | SenLoRa-VP CFO RMSE | SenLoRa接纳载荷导频 |
|---|---:|---:|---:|
| 高频偏 | 0.0265065 bin | 0.0132545 bin | 34 |
| 高速率 | 0.759277 bin | 0.00684328 bin | 52 |

高速率场景：

- 已知前导相位估计速率：`-1.362880 bin/s`；
- 仿真真值审计：`-1.362927 bin/s`；
- 静态PREC帧尾CFO残差约 `1.285 bin`；
- SenLoRa帧尾CFO残差约 `0.00164 bin`。

该结果只证明物理机制和图形可辨识性，不是正式噪声BER结论。差距来自黄鹏固定CFO与SenLoRa已知前导速率/虚拟导频更新，不来自改变置信门限、随机种子、拟合曲线或使用轨道真值。

回归结果：全部25个 `test_*.m` 测试通过，包含原Stage 1--47测试和新增Stage 48测试。

## 阶段2验证结果

结果目录：`results\stage49_continuous_pass_validation`

- acquisition-to-loss时间跨度可容纳508个完整连续帧；
- 帧时长：`0.98304 s`；
- 末尾不足一帧余量：`0.119754934 s`；
- 完全可见帧：432；
- 完全盲区帧：74；
- 跨越可见边界的过渡帧：2；
- 选取5处轨道时间进行分帧/联合逐采样对照；
- 最大梯形相位桥误差：`7.75e-11 rad`，低于 `1e-10 rad` 门限；
- 分帧/联合相位最大数值差：`6.98e-9 rad`，低于 `1e-8` 数值一致性门限；
- 分帧/联合无噪声波形最大差：`6.98e-9`；
- 26/26项完整回归通过。

该阶段证明连续帧的时间和相位接口正确，但没有运行接收机BER。

## 阶段3验证结果

结果目录：`results\stage50_continuous_pass_smoke`

固定检查条件：

- `Sample SNR=-21 dB`；
- 完整生成508个连续帧时隙，信道时间与相位在中央盲区内继续推进；
- 只对完全可见帧进行通信统计；烟雾检查每4个可见帧解码一次，并强制包含两端及两处高速率邻域；
- 共成对解码110帧、`77,440 bit`；同一帧的两算法共用载荷、噪声、轨迹和黄鹏CFO初始化；
- 10 s窗口原始统计，不拟合、不插值、不平滑；中央盲区中的通信曲线用NaN断开。

全可见区稀疏样本汇总：

| 方法 | BER | PER | CFO RMSE | active-link goodput | 平均接收机耗时/帧 |
|---|---:|---:|---:|---:|---:|
| Huang-PREC-static-CP | 0.0380036 | 0.781818 | 0.321066 bin | 156.25 bit/s | 0.0348 s |
| SenLoRa-VP | 0.0403538 | 0.763636 | 0.294200 bin | 169.27 bit/s | 0.227 s |

为防止全轨道平均值掩盖跟踪差异，使用与算法输出无关的物理分区：若一帧内真实多普勒漂移
`abs(rate)*Tframe >= 0.5 bin`，记为高动态区；否则记为低动态区。该真值只用于结果审计，不进入接收机。

| 区域 | 配对帧数 | Huang BER | SenLoRa BER | Huang PER | SenLoRa PER | Huang/Sen CFO RMSE |
|---|---:|---:|---:|---:|---:|---:|
| 低动态 `<0.5 bin/frame` | 74 | 0.0130528 | 0.0435926 | 0.675676 | 0.810811 | 0.139986 / 0.310813 bin |
| 高动态 `>=0.5 bin/frame` | 36 | 0.0892914 | 0.0336963 | 1.000000 | 0.666667 | 0.524116 / 0.256696 bin |

解释边界：

- Stage 50已经显示算法曲线可辨识；在论文静态CFO结构失配的高动态区，SenLoRa BER约为静态PREC的37.7%，且PER由1降至0.667；
- 低动态区静态PREC更好，说明当前 `-21 dB` 下前导速率估计噪声存在代价；不得隐去这个结果；
- SenLoRa共接纳57个载荷虚拟导频，17/110帧至少接纳1个，真值审计误接纳数为0；
- 此阶段是单次过境稀疏接线检查，不是正式Monte Carlo，不能据此宣称总体统计显著性；
- 没有根据结果调整置信门限、随机种子或接收算法。

连续性根因修复：完整过境将未展开相位累加到约 `2.09e7 rad` 后，大数相减的double ULP为
`3.73e-9 rad`，会使本来严格传递的边界审计出现约半ULP假误差。Stage 50改为在帧间传递物理等价的
`[-pi,pi)` 相位状态，并用模 `2*pi` 残差检查；波形、轨迹和算法不变。全过境最大相位桥及传递误差均为
`1.74e-11 rad`，最大时间网格误差为 `4.03e-14 s`。

完整回归：27/27项 `test_*.m` 通过。

## 阶段4预注册SNR冻结结果

结果目录：`results\stage51_preregistered_snr_freeze`

冻结过程只调用解析 `satelliteFig3TheoreticalHammingBerAwgn`，不生成轨道帧、不运行任一接收机、不读取Stage 50曲线，并验证没有消耗随机数。选择规则为：对每个已登记目标，在严格递增候选网格 `-23:-19 dB` 上选择
`abs(log10(theoretical coded BER)-log10(target BER))` 最小的第一个SNR。

| 角色 | 目标理论BER | 冻结SNR | 对应理论Hamming BER | 对数距离 |
|---|---:|---:|---:|---:|
| 主时间图 | `1e-3` | `-21 dB` | `4.4721e-3` | 0.65051 |
| 补充时间图 | `1e-4` | `-20 dB` | `2.164999e-4` | 0.33546 |

候选理论编码BER依次为：`0.11535, 0.03352, 0.0044721, 0.0002165, 2.9278e-6`。冻结记录同时保存CSV、MAT和JSON；JSON明确标记
`receiverOutputsUsedForSelection=false` 与 `randomNumbersUsedForSelection=false`。因此后续即使某个SNR的算法差异不符合预期，也不得更换主点。

Stage 51独立测试及28/28项完整回归全部通过。

## 阶段5A：Stage 52可续跑累计器与真实单过境接线

代码入口：`run_stage52_continuous_pass_formal.m`

单过境接线目录：`results\stage52_one_pass_wiring`

累计规则已经固化：

- SNR使用Stage 51冻结的 `[-21,-20] dB`；
- 每个SNR至少5次完整过境，且Huang-PREC与SenLoRa各自累计至少300个payload bit error；
- 达不到误差目标则继续完整过境，最多20次；停止判定只发生在完整过境边界；
- 每次过境生成全部508个连续帧，432个完全可见帧进入通信统计，74个盲区帧和2个过渡帧只推进时间/相位；
- checkpoint每10帧原子替换，保存当前SNR、过境编号、下一帧、模相位状态及逐帧统计；
- seed公式为 `base + 10000*passIndex + frameIndex`，同一pass/frame在两个SNR及两种算法间配对；
- SNR、预算、种子、物理配置或关键接收机源码任一变化，旧checkpoint均拒绝恢复；
- 10 s时间窗置信区间以完整过境为重采样单位，使用固定seed的配对bootstrap；只有1次过境时明确标注 `wiring_only`，不得给出95%优势结论。

checkpoint测试：先运行2帧后恢复3帧，与一次运行5帧的误码、CFO、导频、种子、时间/相位及指针状态逐项完全一致；改变noise seed时恢复被拒绝。

真实单过境接线结果（每个SNR `304,128 bit`）：

| SNR | 方法 | BER | PER | CFO RMSE | active-link goodput | 平均耗时/可见帧 |
|---:|---|---:|---:|---:|---:|---:|
| -21 dB | Huang-PREC-static-CP | 0.039865 | 0.77315 | 0.31269 bin | 162.46 bit/s | 0.0312 s |
| -21 dB | SenLoRa-VP | 0.040056 | 0.82407 | 0.29231 bin | 125.99 bit/s | 0.2091 s |
| -20 dB | Huang-PREC-static-CP | 0.017101 | 0.45139 | 0.31300 bin | 392.89 bit/s | 0.0302 s |
| -20 dB | SenLoRa-VP | 0.014076 | 0.44444 | 0.26990 bin | 397.86 bit/s | 0.2226 s |

物理分区进一步显示：

| SNR | 区域 | Huang BER | SenLoRa BER | Huang PER | SenLoRa PER |
|---:|---|---:|---:|---:|---:|
| -21 dB | 低动态 `<0.5 bin/frame` | 0.012828 | 0.037130 | 0.6667 | 0.7925 |
| -21 dB | 高动态 `>=0.5 bin/frame` | 0.097466 | 0.046288 | 1.0000 | 0.8913 |
| -20 dB | 低动态 `<0.5 bin/frame` | 0.002324 | 0.013359 | 0.1939 | 0.4490 |
| -20 dB | 高动态 `>=0.5 bin/frame` | 0.048584 | 0.015604 | 1.0000 | 0.4348 |

上述结果说明曲线已能揭示算法优劣而非都贴近理论线：SenLoRa在高动态区显著降低结构性漂移误差，但低动态区的前导速率估计会带来噪声代价。总体上 `-20 dB` 单过境SenLoRa更好，`-21 dB` 基本相当；由于只有1次过境，均不得写成统计显著结论。

虚拟导频审计：`-21 dB` 接纳163个、误接纳0个；`-20 dB` 接纳381个、误接纳1个。共同Huang CFO与首载荷相位最大差均为0。两次过境最大相位桥/传递误差 `1.74e-11 rad`，最大时间误差 `4.03e-14 s`。

Stage 52新增checkpoint与结果层测试后，30/30项完整回归通过。

## 结果可辨识与导师要求

- 正式主横轴必须为轨道时间，不以SNR为横轴；
- 高速率区真实一帧约产生1.34 bin漂移，作为结构性压力而非人为信道放大；
- 除窗口BER外必须输出PER、帧内位置BER和残余CFO，防止平均BER掩盖跟踪差异；
- 若公平统计后BER仍重合，必须如实报告并用上述机理指标解释，不得调种子、平滑或削弱基线；
- 复杂度和goodput必须同时体现SenLoRa收益与代价。

## 文件变更记录

- 2026-08-10：创建本实时日志；没有修改原Stage 1--47结果。
- 2026-08-10：新增 `satelliteFig3HuangPrecCpBootstrapEstimate.m`，以师兄黄鹏PREC/PRC为基础，只适配连续相位前导合并。
- 2026-08-10：新增 `satelliteFig3HuangPrecStaticCpDecode.m` 和 `satelliteFig3SenLoRaVirtualPilotDecode.m`。
- 2026-08-10：为 `satelliteFig3RollingPilotTracker.m` 与 `satelliteFig3SenLoRaIterativeDecode.m` 增加可选共同bootstrap输入；默认旧路径不变。
- 2026-08-10：新增Stage 48源代码等价性、公平性测试和机制检查图；25/25回归通过。
- 2026-08-10：扩展 `generateContinuousSatelliteFrame.m`，新增可选绝对起始相位和下一帧相位状态；默认旧调用行为不变。
- 2026-08-10：新增 `satelliteFig3ContinuousPassSchedule.m`、Stage 49连续帧测试及时间轴检查图；26/26回归通过。
- 2026-08-10：新增 `run_stage50_continuous_pass_smoke.m` 与接线测试；修复长时间未展开相位造成的浮点审计假失败；27/27回归通过。
- 2026-08-10：新增 `run_stage51_preregistered_snr_freeze.m` 与理论独立性测试；冻结主点 `-21 dB`、补充点 `-20 dB`。
- 2026-08-10：新增 `run_stage52_continuous_pass_formal.m`、`satelliteFig3Stage52WriteArtifacts.m`、checkpoint/结果层测试及双SNR真实单过境检查图；30/30回归通过。

## 当前阶段

阶段5A已完成，等待用户检查Stage 52两张真实单过境时间图。累计器、checkpoint、完整过境bootstrap统计和所有审计表已接线；单过境结果仍明确标为wiring-only。

## 下一步

1. 同步Stage 52代码、测试、单过境图和审计表到目标项目；
2. 新建正式结果目录，从零运行默认预算（至少5次完整过境且两方法各至少300错误，最多20次）；
3. 正式累计期间不得修改接收机、种子、窗口或冻结SNR；若修改，必须新建目录并从零开始；
4. 完成后检查完整过境bootstrap置信区间、paired差值、误接纳、高/低动态区和goodput；
5. 最后进入复杂度/有效通信速率报告，不以单次运行时间替代理论运算量分析。

## 阶段5B：Stage 53正式重复完整过境（已完成）

正式入口：`run_stage53_formal_repeated_passes.m`  
正式结果：`results\stage53_formal_repeated_passes`

冻结条件保持为 `SNR=[-21,-20] dB`、每SNR至少5次完整过境、每算法至少300个payload bit error、最多20次过境。正式seed基数为：

- payload：`2026150800`；
- noise：`2026150900`；
- paired complete-pass bootstrap：`2026151000`。

曾有一次 `-21 dB` 过境误用Stage 52 wiring seed。该结果在发现后立即停止，原样移动至
`results\stage53_abandoned_seed_overlap_with_wiring`，并以 `ABANDONED_REASON.md` 标注；它没有进入任何正式统计。正式Stage 53从独立seed目录的pass 1重新开始。

两个SNR均在5次完整过境后同时达到停止条件。每个方法/SNR均统计 `1,520,640 bit`、2160个完全可见帧；盲区和过渡帧只推进连续时间与相位。

| SNR | 方法 | BER（paired-pass 95% CI） | PER | CFO RMSE | active goodput | pass-average delivery |
|---:|---|---:|---:|---:|---:|---:|
| -21 | Huang-PREC-static-CP | 0.040884 `[0.040434,0.041333]` | 0.77500 | 0.31614 bin | 161.13 bit/s | 136.99 bit/s |
| -21 | SenLoRa-VP | 0.043279 `[0.041644,0.044992]` | 0.81481 | 0.29963 bin | 132.62 bit/s | 112.75 bit/s |
| -20 | Huang-PREC-static-CP | 0.017807 `[0.017318,0.018398]` | 0.44167 | 0.31598 bin | 399.85 bit/s | 339.95 bit/s |
| -20 | SenLoRa-VP | 0.015394 `[0.014452,0.016205]` | 0.49213 | 0.27647 bin | 363.71 bit/s | 309.22 bit/s |

成对完整过境差值定义为 `Huang-Sen`：

- `-21 dB` BER差为 `-0.002395`，95% CI `[-0.004144,-0.000646]`：总体BER上Huang更好；
- `-20 dB` BER差为 `+0.002413`，95% CI `[+0.001367,+0.003404]`：总体BER上SenLoRa更好；
- 两个SNR的PER差均为负，因此当前帧丢弃口径下SenLoRa的全过境packet goodput没有优于Huang。

物理分区没有被总体平均掩盖：

| SNR | 区域 | Huang BER / goodput | SenLoRa BER / goodput |
|---:|---|---:|---:|
| -21 | 低动态 `<0.5 bin/frame` | 0.013808 / 236.77 | 0.043188 / 135.92 |
| -21 | 高动态 `>=0.5 bin/frame` | 0.098567 / 0.00 | 0.043474 / 125.58 |
| -20 | 低动态 `<0.5 bin/frame` | 0.002434 / 585.10 | 0.015513 / 368.30 |
| -20 | 高动态 `>=0.5 bin/frame` | 0.050558 / 5.19 | 0.015141 / 353.92 |

因此正式曲线已经回答导师提出的“不能都贴近理论线”问题：SenLoRa在高动态区明显胜出，静态Huang在低动态区更好；这不是单向全面胜利，而是可解释的适用区间差异。SenLoRa正式接纳/误接纳为 `1073/11`（-21 dB）和 `2151/11`（-20 dB）。共同bootstrap CFO与首载荷相位差均为0；最大相位桥/传递误差 `1.7433e-11 rad`，最大时间误差 `4.0297e-14 s`。

`test_stage53_formal_result_acceptance.m` 自动验证完整过境数、错误预算、seed公式、盲区排除、成对bootstrap、连续相位、公共初始化与高/低动态差异。

## 阶段6：复杂度、耗时与有效通信速率（已完成）

入口：`run_stage54_complexity_goodput_report.m`  
结果：`results\stage54_complexity_goodput`

该阶段只读取冻结的Stage 53产物，不重新运行接收机，不改算法或正式数据。基于实际调用链：

- Huang：每帧精确200个2048点FFT；
- SenLoRa：2--5次迭代，对应552--1248个2048点FFT；另有 `5.05e6--1.26e7` 个LLR log-sum-exp输入、软Hamming评分和最多315个11候选残差投影bank；
- 本机正式平均耗时：SenLoRa约为Huang的 `6.76x`（-21 dB）与 `7.34x`（-20 dB）；
- 两算法所有正式帧均未超过 `0.98304 s` 帧周期，deadline miss rate为0；Huang实时裕量约31帧，SenLoRa约4.3--4.6帧；
- 有效速率主口径为packet goodput，不能用 `(1-BER)` 的correct-bit rate代替；后者只作为不丢弃坏帧的辅助上界。

Huang来源继续由以下SHA-256锚定：

- `PREC.m`：`3AB8FBC23C595485E0CC9E478223C1A4048BD034A666EE97D7499AF55DF77E98`；
- `MonteCarlo_BER_RMSE_PRC_EC_TQ28.m`：`85E657783A2A791DE2843526334DE6BBAD816CF2050E8D5A164A5D19A1C1CFD1`。

阶段6详细定义、表格与论文结论边界见
`results\stage54_complexity_goodput\STAGE54_COMPLEXITY_GOODPUT_REPORT.md`。

## 当前最新阶段

阶段0--6全部完成。最终完整回归按独立 `test_*.m` 函数逐项调用，`33/33` 通过。Stage 53正式时间图、CSV、MAT、seed账本、checkpoint及Stage 54复杂度/有效速率图表均已生成；接下来只需同步到目标项目并做目标端哈希与测试检查。

## 后续修改约束

1. 不得把 `stage53_abandoned_seed_overlap_with_wiring` 合入正式统计；
2. 若修改任一接收机、阈值、SNR、seed、轨迹或帧结构，必须新建结果目录并从零重复正式过境；
3. Stage 53两张时间图是正式统计图，Stage 52单过境图仍仅为wiring；
4. 论文必须同时报告高动态收益、低动态代价、PER/goodput和复杂度，不能只摘取有利BER区域；
5. MATLAB墙钟时间不等价于功耗、芯片面积或嵌入式能耗，硬件无关复杂度引用Stage 54运算量计数。
