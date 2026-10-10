# LoRa SER 项目：结构、算法、实验与结果详细说明

整理日期：2026-10-08，Asia/Shanghai。  
项目根目录：`D:/codex/Lora（SER performance of different estimation strategies）`。

本文在完成只读代码审计后生成。问题、证据、优先级和待授权修复见同目录 [项目代码审计报告](PROJECT_CODE_AUDIT_2026-10-08.md)。本文说明**现在代码实际做什么**，不把历史方案、计划状态或工程命名直接当成性能证明。

## 1. 这个项目研究什么

项目比较不同 Doppler/CFO 估计与补偿方法在 LoRa 数据符号上的错误率。主要研究链条是：

```text
冻结 PHY + payload/noise/channel 包身份
    → 生成具有连续 Doppler 相位的波形
    → 从接收前导估计 CFO/rate
    → 补偿 payload、FFT 判决、CR3/Hamming 处理
    → 接收结束后与真实符号比较
    → 保存逐包错误、失败、VP、gain、残差与源码身份
    → 原始点 SER / 同包差异 / 镜像与相邻统计
```

它是研究用基带、已知帧分段的仿真工程，不是已经实现完整同步获取、LoRaWAN 协议栈、设备时钟/相噪、频率选择性多径和真实链路预算的产品接收机。

## 2. 必须先区分的实验系列

| 系列 | 主要入口/目录 | 帧与方法 | 阶段含义 |
|---|---|---|---|
| 旧 EXP1 | `scripts/`、`src/`、`configs/` | 157T 共同波形；Huang/PREC、Paper V6、Stage55 V16、Ideal | 根 README 的 Pilot/Formal/Ablation 指此系列 |
| 历史 V2/V3 | `senlora_symmetric_v2/`、`senlora_symmetric_v3/` | 分支/候选、rate-bank、LOBO 等历史研究实现 | 不是当前正式 V8；部分仍被 V6 参考调用 |
| V6 | `senlora_symmetric_v6/` | V3 的强动态一致性 Static override | V8 Review 的 V6-native 对照 |
| 正式 V8 | `senlora_symmetric_v8/` | 120T native；连续相位融合 + Joint-block CFO/Hamming | 已冻结并完成 Review；专属 Formal 未启动 |
| PaperPoint 用户 PHY 适配 | `senloraPaperMidamblePointDecode.m` | 234.25T；n_int=1、FFT16、分段固定 CFO | 论文策略的用户 PHY 适配，不等于原论文全部设置逐字复现 |
| PilotTimeAligned 变体 | `senloraPilotTimeAlignedDecode.m` | 同一 234.25T；左右观测导频时间插值 | 明确不是原始 Paper Eq17；最近六图的第四条曲线 |
| AWGN 不确定性图 | `plotSenloraFigure12AwgnUncertainty.m` | 不生成波形；读取完成数据，加 VP 点态区间 | 只修统计呈现，不改均值/理论/接收机 |

**不能互相替换的概念**：EXP1 Formal、V8 Review、五点 1000 包、Case-SNR 1000 包/点、V8 9000 镜像对-包 Formal。

## 3. 目录和依赖关系

```text
项目根目录
├─ configs/                  EXP1 配置、seed 规则、父库冻结清单
├─ src/                      轨道/波形、接收封装、错误计数、统计、持久化
├─ scripts/                  EXP1 阶段运行、聚合与绘图
├─ tests/                    EXP1 回归测试
├─ review_first_v1/          早期 Review 工具和候选
├─ senlora_symmetric_v2/      历史候选；被 V3/V6 依赖
├─ senlora_symmetric_v3/      历史候选及 seed 工具；被 V6/V8 Review 依赖
├─ senlora_symmetric_v6/      V6 与 V6-native 参考
├─ senlora_symmetric_v8/      当前 V8、Paper/变体、Theory、运行器、说明
│  └─ audit/                 before-image 和结果校验工具，不应当作当前入口
├─ results/                  分系列/分阶段的逐包记录、MAT、CSV、PNG
└─ audits/                   审计材料及本次两份文档
```

父库位于：

`D:/codex/Lora(eg)/comparison_experiments/stage55_sf12_sf11_flow_v4_noldro`

`exp1SetupPaths` 加入项目公共层，并把父库放在路径后部。当前程序只读引用父库；父库的 52 项文件由 `configs/parent_source_manifest.json` 锁定。V8 的实际接收源码另外由 `v8_frozen_receiver_manifest.json` 锁定。

不要为了方便对整个工程盲目 `addpath(genpath(projectRoot))`：工程包含同名 before-image。应按目标入口配置路径，并用 `which` 检查实际调用来源；旧副本不是当前官方版本。

## 4. PHY、编码与单位

| 项目 | 当前值/含义 |
|---|---|
| 物理 SF / 有效数据 SF | 12 / 12 |
| BW / Fs | 125000 Hz / 125000 sample/s |
| 每个完整符号样本 | M=4096 |
| 符号周期 T | 4096/125000=0.032768 s |
| FFT bin 宽度 | 125000/4096=30.517578125 Hz |
| 符号字母表 | 4096 个物理 bin，编号 0–4095；不是 1024 |
| LDRO | 关闭，是本研究固定条件，不代表推荐的实际 LoRaWAN 配置 |
| 工程 CR3 | Hamming(7,4)，码率 4/7 |
| 每包 Hamming block | 16 个，每 block 7 个 LoRa 数据符号 |
| 每包数据符号 | 16×7=112 |
| 信息位 | 16×12×4=768 |
| 编码后的数据承载位 | 112×12=1344 |
| native 前导 | 8 个已知 upchirp |

CFO 的内部单位多为 **bin**；转换到 Hz 要乘 30.517578125。rate 为 **bin/s**，转换到 Hz/s 同样乘 bin 宽度。相位模型用 cycles，补偿时乘 `2*pi`。不要把 bin/s、bin/symbol 和 Hz/s 混用。

Gray 映射、对角交织和 Hamming 表由父库提供。`v4SymbolLikelihood` 对完整符号去 chirp 后作单位化 FFT，能量最大 bin 是硬物理符号；软指标由 FFT 能量构造 log probability/bit LLR。

## 5. 三类帧不是同一时间轴

| 帧 | 组成 | 时长 |
|---|---|---:|
| 旧 EXP1 共同时间轴 | 8 前导 + 112 data + 37 midamble | 157T=5.144576 s |
| V8/PREC native | 8 前导 + 112 data；无 midamble、无空导频槽 | 120T=3.932160 s |
| 当前 Paper/Pilot | 8 upchirp + 2 downchirp + 1/4 sync + 112 data + 112 导频 | 234.25T=7.675904 s |

Paper/Pilot 每个 data 后放一个已知 upchirp，包括末尾导频。完整矩阵共有 234 行，quarter-sync 单独保存，并计入真实物理采样时间。

native 第一个/最后一个 data 中心为 8.5T/119.5T；Paper/Pilot 为 10.75T/232.75T。即使 packet seed 和 start time 相同，两类帧的 payload 时间点与 Doppler 也不同。

当前比较固定单位平均功率参考下的采样 SNR，而不是固定整包能量：Paper/Pilot 时长/能量开销约为 native 的 1.952 倍。768 信息位对应的含前导有效速率约为 native 195.31 bit/s、Paper/Pilot 100.05 bit/s。论文/报告中必须说明这个代价。

## 6. 信道、轨道与真值边界

### 6.1 生成器的实际工作

1. 由 payload seed 生成随机信息位、编码、交织和 112 个物理符号。
2. 调制每一行 chirp；Paper 同步行使用 downchirp。
3. 以 `startSec + sampleIndex/Fs` 构造逐样本真实时间，仅用于信道生成。
4. `exp1TrackAOrbit` 得到真实 Doppler 和导数。
5. 以梯形积分形成连续 Doppler 相位，而不是每个符号重置相位。
6. 乘以 AWGN 的单位系数或一个 packet-flat Rician 复系数，再加入噪声。
7. 分离 `observation` 与 `truth`。

当前 Track-A 的实际常数为地球半径 6371 km、轨道高度 550 km、mu=3.986004418e14、光速 299792458 m/s，载频来自配置，默认 868 MHz。距离公式是简化二维共面过顶模型；配置里另列的倾角、地球自转/仰角字段没有进入这个函数。它不是完整三维轨道传播器。

### 6.2 AWGN

单位 chirp 幅度，复噪声方差：

```text
noiseVariance = 10^(-sampleSNRdB/10)
noise = sqrt(noiseVariance/2) * (N_real + j*N_imag)
```

实部/虚部用独立标准正态样本，同一 packet 的重复生成由独立 `RandStream` 和固定 noise seed 控制。

### 6.3 Rician，不是 Rayleigh

当前 K=10 dB，K_linear=10，整个包使用一个系数：

```text
h = sqrt(K/(K+1)) + sqrt(1/(2*(K+1))) * (N_real + j*N_imag)
```

因此 E|h|²=1，但单包 |h|² 会变动。代码没有把每个包重新归一化到单位瞬时功率。噪声方差仍以单位平均信号功率定义，瞬时 SNR 随 |h|² 改变。

这是 packet-flat、小尺度 Rician 模型；没有位置相关路径损耗、阴影、频率选择性多径或散射 Doppler 谱的完整模拟。

### 6.4 observation / truth / Ideal

真实 payload、逐样本相位、真实 CFO/rate 放在 `truth`，只在接收结束后评分或运行 Ideal。实际接收核心读取波形、已知帧布局、同帧前导观测和通用参数，没有发现读取真实符号/真实 Doppler/目标 SER。

`observation` 仍含额外噪声方差等字段；API 也传入大配置 struct，隔离强度主要依靠实现不读取和测试约定，而不是一个完全净化的类型系统。自报 `uses...=false` 只是监测证据的一部分。

所有入口都假设已知完整帧分段。Paper 的 downchirp/quarter-sync 被生成，但本工程不是从任意长接收流中盲搜索帧起点的同步获取器。

## 7. 正式 V8 入口与调用关系

```text
senloraSymmetricV8Decode(observation, common, config, plan)
    └─ senloraSymmetricV8JointBlockDecode(...)
         ├─ v4BCalibrationCandidates → 第 2 组冻结结构参数
         ├─ v4Stage55JointPreambleMlBootstrap → 8 前导 CFO/rate ML
         ├─ senloraSymmetricV8BlendBootstrap → 完整相位轨迹融合
         ├─ v4RollingTrackerPass(mask 全 false) → 第一遍预测/补偿
         ├─ v4DecodePayload → 第一遍硬/软 CR3 与诊断
         ├─ 16 个 block × 21 个残差 CFO 候选
         │    └─ senloraSymmetricV8BlockLikelihood
         └─ v4DecodePayload → 最终硬物理符号、硬/软信息位
```

正式入口版本：`SenLoRa-V8-joint-block-frozen-v1`。旧 `senloraSymmetricV8LegacyDecode` 是被保留的失败基线，不应作为新仿真的正式方法。

### 7.1 前导的两条模型

Static 的 fixed CFO/起点相位来自 common 前导状态，与父库 Static 控制接收机使用的状态构造一致。

Dynamic 在相同 8 前导的连续去 chirp 样本上搜索 CFO/rate。32768 样本 FFT、coarse rate 步长 1 bin/s、fine 步长 0.1 bin/s，再作有界局部数值细化；最大 rate 范围来自冻结参数，当前为 ±20 bin/s。

### 7.2 相位对齐和连续融合

设 x 为相对帧起点的符号时间，模型 cycles 为：

```text
q(x) = a0 + a1*x + 0.5*a2*x^2
rateBinsPerSec = a2/T
```

Static 令 a2=0。Dynamic 的常数相位项先平移，使 x=8 的 payload 起点与 Static 相同，再对**三个系数整体融合**：

```text
drift = abs(rateHat)*120*T
u = clip((drift-0.10)/(0.80-0.10),0,1)
gain = u*u*(3-2*u)
qV8 = qStatic + gain*(qDynamicAligned-qStatic)
```

- gain=0：初始轨迹严格等于 Static。
- gain=1：初始轨迹等于相位对齐后的 Dynamic。
- 中间：相位/CFO/rate 项连续融合，非布尔模式切换。

这是恒定 rate 导致的二次相位，不是新增二阶轨道动力学模型。debug 中 payload CFO 对应首 payload 符号**中心**（8.5T）；相位对齐锚点是起点 8T。

gain 端点性质限定于初始化轨迹。后续 block 估计仍可以修改补偿，不能说 gain=0 时整个解码器永远只是固定 CFO。连续函数也不保证有限包数的 SER 曲线严格平直或单调。

### 7.3 第一遍

`v4RollingTrackerPass` 的 candidate mask 全为 false，使用融合后的 CFO/rate 预测和补偿全部 payload，没有 payload VP 更新。随后 CR3/Hamming 解码。

**关键区别**：当前 Joint-block 中第一遍解码符号主要作为诊断，未固定为第二遍候选标签。当前方法不能描述成旧草稿的“第一遍重编码标签独立约束第二遍 VP”的直接实现。

### 7.4 第二遍当前 block 的联合搜索

每 block 有 7 个 data，16 个 block 顺序处理：

1. 从此前已通过质量门的 block CFO 历史预测当前修正中心和 rate。
2. 遍历冻结的残差网格 `-0.50:0.05:+0.50 bin`，共 21 候选。
3. 用每个候选对当前 block 的 7 个原始接收符号重新补偿。
4. 对 4096-bin log probability 求 Gray bit LLR，去交织后评估每数据行的 16 个合法 Hamming(7,4) 码字。
5. 目标为各行最佳码字分数之和，选一个最大目标候选，其余丢弃。
6. 保存选中的样本、CFO 修正、结束相位和码字置信度。

这是当前 block 内的 CFO 搜索，不是跨 block rate-bank 拼接。V6 参考内部可以使用历史 rate-bank/LOBO；不能把这些参考的实现当成 V8 当前路径。

这个“Joint ML”是离散候选、bit-LLR/Hamming 评分的工程实现，不自动等于完整码字联合符号 likelihood 或连续参数的全局最优解。

### 7.5 质量门和因果历史

当前代码只在以下条件同时满足时向后续历史写一条 block CFO 观测：

- Hamming 硬/软解码信息位一致；
- block 最小 decision peak ratio 过线；
- 最小码字 margin / 平均最佳码字 score 过线；
- CFO 搜索最佳/次佳评分形成的比值过线。

当前候选 2 的主要继承值为 decision peak=1.01、residual peak=1.01、innovation=0.50 bin、soft Hamming margin ratio=0.10。结构参数包括 history decay=0.85、Huber=0.30 bin、最大 rate=20 bin/s、rate deviation=4 bin/s。它们来自已存在的 Stage55 参数结构，不是本次文档生成后新增。

即使质量门未通过，当前 block 的已选定补偿仍被使用；质量门控制未来 CFO/rate 历史的写入。补偿相位积分状态仍按已用轨迹推进，因此不能说所有状态都完全不受拒绝 block 影响；其后续常数相位偏移不改变此处按 FFT 能量作出的硬符号判决。最后 block 没有后续，因此不加入未来历史。

历史最多保留 8 个**block 观测**，不是 8 个独立逐符号 VP。先按已有观测可观测性决定 rate 修正，再作加权一阶拟合与 Huber 重加权，限制 rate 偏移。这里的 history decay 按符号时间间隔计算。

### 7.6 最终输出与 VP 单位

把 16 个选中样本块拼成 112 data，再作最终 payload 解码。主 SER 用 `finalDecoded.hardPhysicalBins`，不是把重编码符号直接替换成“正确答案”。

| 字段 | 解释 |
|---|---|
| `detectedPhysicalBins` | 最终硬物理 bin，SER 的直接依据 |
| `estimatedCfoBins` | 每 data 的补偿中心 CFO，不是已知真实 CFO |
| `firstPassDetectedPhysicalBins` | 第一遍诊断结果 |
| `rateGain` | 本包初始化的连续融合权重 |
| `selectedResidualBins` | 每个 block 选中的残差 CFO 候选 |
| `blockAccepted` | 是否满足向未来写入历史的质量门；最后 block 可以过门但不应用到未来 |
| `acceptedVirtualPilots/virtualPilotAccepted` | 应用到未来的 block 按每 block 7 符号展开的等价计数/掩码 |
| `acceptedBlocks` | 有些输出为所有过门 block 的数量，与已应用数量不完全相同 |
| `monitor.acceptedMeasurement` | 来源数据掩码，不应当成该时刻已经执行控制更新的精确时间戳 |

这些计数不是“105 条独立 CFO 测量”。实际第二遍历史每个接受 block 增加一条观测。`firstPassTracker.usesCrossFrameRate` 的历史命名也不准确：有限 InitialRate 可来自同帧前导，并不表示本方法跨包使用轨道信息。

## 8. PREC、V6-native、Paper 和时间对齐变体

### 8.1 PREC

最近四曲线使用父库已冻结 `v4HuangPrecUnifiedDecodeV9`，与 VP 共用 native 帧。高 rate 下结果恶化是观测到的基线表现，不在本审计中通过换版本或改曲线掩盖。

### 8.2 V6-native

V6 调用 V3，只有强动态候选一致且评分满足要求时覆盖 Static。Review 将其 frameDuration 设为 V8 的 120T，并给同一 native 波形与 common 前导估计，所以名为 V6-native。它主要是 V8 保持低动态性能的参考，不是最近四曲线中的第四条。

### 8.3 PaperPoint

当前用户 PHY 适配采用固定 n_int=1、FFT16：

```text
最后一个完整 downchirp估计初始CFO
    → data按上一已知导频CFO、rate=0补偿
    → 每个midamble测残差并更新CFO
    → 新CFO只作用到后续data
```

末尾导频不再影响已经解调完的最后 data。高 rate 时，即便上一导频 CFO 完全精确，时间滞后仍会留下偏差；不能把这种限制直接断言成代码移植错误。

### 8.4 PilotTimeAligned

采用最后一个 downchirp和每个后置upchirp的观测 CFO，按相对帧中心时间插值到 data 中心：首 data 权重 5/9，其余 1/2。使用模 Fs 的最短频率圆弧，避免 Nyquist wrap 假跳变。

每个 data 仍作常数 CFO、symbol 内 rate=0 补偿；跨 data/pilot 的补偿相位持续积分。它隐式使用频率变化，明确标 `usesDopplerRate=true`、`usesWithinSymbolRate=false`、`usesFuturePilot=true`、`isOriginalPaperThirdMethod=false`。

理论上的最低依赖后瞻是一导频；实际 MATLAB 入口接收整个 frame，先估计全部导频再处理 data。不能把 `bufferedDataSymbols=1` 解读成已经实现了流式单符号内存/低延迟调度。

## 9. Theory 和 Ideal 为什么不同

### 9.1 AWGN 理论

令 gamma=M*10^(sampleSNR/10)。正确 bin 的归一化能量具有非中心复高斯功率分布，其他 M−1 个噪声 bin 为单位均值指数分布，条件错误概率为：

```text
P(error|r) = 1-(1-exp(-r))^(M-1)
```

代码用 `log1p/expm1` 和缩放 `besseli` 稳定积分，不拟合仿真点。

### 9.2 Rician 理论

对 packet-flat Rician 系数边缘化后，正确 bin 的复均值功率为 `gamma*K/(K+1)`、归一化复方差为 `1+gamma/(K+1)`，仍对同一条件错误概率作积分。

这给的是边缘符号 SER；因为同一包的 h 共用，包内错误相关性需要在统计区间中保留，不能把所有符号简单当成独立 Bernoulli 样本。

### 9.3 SNR 锚点不可混用

| 工作点 | AWGN 理论 |
|---|---:|
| 旧 native 五点的采样 SNR=-21 dB | 约 1.000896e-4 |
| Figure12 格式 Es/N0=15 dB，采样 SNR=15−10log10(4096)=-21.12359948 dB | 1.503107436e-4 |

当前 Figure12 的 Rician K10 理论为 0.03096406913。不能为了让黑线更低而把另一个 SNR 的理论值拿来替代。

### 9.4 Ideal 是同包离线参考，不是解析曲线

`exp1IdealDecode` 在真实接收机返回后，用 `frame.truth.phasePhysicalRad` 去除逐样本真实相位，再作相同 payload FFT/解码。native Ideal 与 Paper/Pilot 自有 frame Ideal 是两份不同帧的参考。

Ideal 不把真实 CFO、真实符号或目标错误率送给真实接收机。其有限样本错误率仍会随机波动；它的硬 FFT 参考也不是所有码辅助接收器的普适信息论下界。

## 10. 指标、失败和统计

### 10.1 主指标

```text
rawErrors(packet) = sum(detectedPhysicalBins != truthPayloadBins)
SER(cell) = sum(rawErrors)/(packets*112)
```

1000 包/点的分母是 112000。它是 data-symbol SER，不是 Hamming 后的信息位 BER。硬/软 BER 的分母是每包 768 信息位。旧 EXP1 的 symbol PER 定义为至少一个硬物理符号错误；另存 hard-bit packet error，不等同于真实 CRC 包成功率。

“接收失败=0”只表示未记录解码异常，不表示“符号错误=0”。噪声和方法局限仍会产生错误。

### 10.2 失败处理目前有两种口径

- 旧 EXP1 与四曲线比较：异常包按全部 112 符号错误记入，并标失败。
- V8 的部分 native Case-SNR/五点路径：存 NaN 并按成功包分母计算，保存 valid/failed 数量。

目前最新四曲线无失败，所以没有由这一区别造成的当前偏差；后续出现失败时必须明确分母和成功状态，不能只看 COMPLETE。

### 10.3 配对与 cluster

同一包/镜像对的多个方法共享 seed，比较应在同一个重采样索引上取差值。整个包是 resampling unit，保留包内 112 符号的相关性。

V8 Review 按 900 个镜像对-包形成 1800 帧，每 pair 100 个 packet ID；镜像首样本时刻是 `-negativeStart-frameDuration`，不是简单负号。中央两个起点为 -3.93216 和 0 s。

旧 EXP1 DeltaSER=baseline−Stage55，正值表示 Stage55 更好；V8 的 V8−V6/Ideal 与 AWGN VP−Ideal 则正值表示 V8/VP 更差。报告时必须注明方向。

### 10.4 有限包数、零点与平直性

解析理论是总体期望，不是每个样本点的强制排序。当前 AWGN 每点理论预期 16.8348 错，观测只有 11–25 个，抽样误差相对较大。

真实 raw SER=0 是有限样本估计，不代表总体错误概率为 0。不能加伪错误，不能为了不出现零点重选 seed；应保存原始计数并使用恰当的区间/上界/零点显示。

95% 逐点区间不是全轨同时区间；区间包含 0 不等于方法等效或非劣已证明。需要容差/预注册检验、足够事件数及清晰的多重比较方案。

## 11. 最近结果的定位与解释

| 目录（均在 results/senlora_symmetric_v8 下） | 内容 | 完成含义 |
|---|---|---|
| `joint_block_mechanism` | 9 pair×20 的候选机制材料 | 非 Formal |
| `joint_block_review` | 9 pair×100；20/20/16 错误 | 冻结依据，非 Formal |
| `five_point_1000` | 5 个负轨点各 1000；独立 root1032500000 | 记录过 raw 排序门失败，不等于数据损坏 |
| `case_snr_curve_minus30_to_minus21` | AWGN 两 Case 的 SNR 扫描 | 与最近 Rician 四曲线不是同一信道 |
| `case_snr_rician_k10` | native VP/Ideal 基线 | 原生同包数据来源 |
| `case_snr_rician_k10_prec_comparison` | 加入 native PREC 基线 | 最近 Case 四曲线只读复用的来源 |
| `paper_point_eq17_nint1_case_snr_rician` / `figure12_four_methods_nint1` | 旧驱动器版本完成的即时 Paper n_int1 | 保留，不覆盖 |
| `*_runner_v3` | 新驱动器默认 PaperPoint 的独立命名空间 | 当时用于两包/点回归，不能据目录存在声称该版本已跑满1000 |
| `pilot_time_aligned_case_snr_rician` | 2 Case×10 SNR×1000=20000；三张图 | 最新 Case-SNR 的第四条为时间对齐变体 |
| `figure12_pilot_time_aligned` | 2信道×5位置×1000=10000；三张图 | Es/N0=15，root1033100000 |
| `figure12_awgn_uncertainty` | 原始四曲线 + AWGN VP点态CI，另存配对差值 | 未生成新仿真包 |

最新 Case-SNR root 为 1032900000；两信道轨迹保持同一 payload/noise/channel/extra-pilot seed 身份。native PREC/VP/Ideal 是签名校验后的已完成缓存；新一轮只重算比较方法及其同 frame Ideal。不能把“复用”写成再次全部从头执行。

### 11.1 当前 AWGN 五点数值

SNR=-21.12359948 dB，每点 1000 包。第四列变体不是原论文 Eq17。

| 时刻(s) | PREC错误数 | VP错误数 | 时间对齐变体错误数 | native Ideal错误数 |
|---:|---:|---:|---:|---:|
| -366 | 18 | 16 | 91 | 16 |
| -274.5 | 2192 | 11 | 96 | 13 |
| -183 | 79709 | 14 | 102 | 12 |
| -91.5 | 105110 | 12 | 88 | 12 |
| 0 | 111376 | 25 | 90 | 23 |

VP 合计78错，native Ideal76错；整体没有优于同包 Ideal。五点 VP 的点态95%区间均覆盖理论，配对差值区间均包含0。不是“超过物理极限”的证据，也不是严格达到理论的证明。

时间对齐变体0秒为90/112000=8.035714e-4，旧高率尖峰得到改善，但仍高于1.5031e-4理论。其 Rician 五点约0.0703–0.0864，也仍高于0.030964理论，不能把六图生成成功当成算法最终验收成功。

Case-SNR 四曲线表中的 gain/VP block 遥测当前全为缺失，而 Figure12 表正常。做机制分析时应读取原始 native 基线或先补来源映射，不能将 NaN 当0。

## 12. 随机包身份与重复生成

`v4EventRandomLedger/v4KeyedSeed` 根据 root 和带阶段、事件/点号、SNR、packetId 等字段的 key 产生 payload/noise/channel 等独立 seed。

- 相同 root+key 可重新生成相同包，不依赖全局 RNG 的调用顺序。
- 镜像 pair 两侧共用 payload/noise seed，但真实相位不同。
- 新阶段应使用未见、已登记的 root/key，而不是挑有利 seed。
- bootstrap 的分析 seed 不是新仿真 seed。
- 改进实现后不能一边补不利点一边保持有利旧点；应按预注册范围完整执行或清楚标为机制探索。

当前保存的 Review 使用旧 V8 identity，不是现在的 Frozen identity。本次重算确认：仅按当前 plan+root/pair/packetId 生成的900组seed全部不同；按保存的执行identity生成则全部匹配。重放历史数据应优先用保存的payload/noise seed和`executionSignatureAtRun`，不能忽略命名域差异。

V8 计划根：机制1030000000、smoke1031000000、Review1032000000、Formal1033000000。最近各拓展实验另有独立 root；数字接近不等于同一个 packet 集合，真正身份由完整 root+key 定义。

## 13. 签名、检查点和恢复

### 13.1 三层身份

1. **方法/PHY**：官方入口、版本、d0/d1、native时长、编码/采样条件。
2. **源码/输入**：实际依赖文件SHA、参数JSON、基线数据、论文文件、冻结清单。
3. **运行数据**：完成掩码、错误数组、失败标志、遥测及 stateDigest。

新四曲线实现对整个状态结构去掉自身digest后序列化，再作SHA256。完成 RESULT 与 CHECKPOINT应完全相同；CSV必须能重算同一计数和SER。

旧 EXP1/Review 的数据门弱一些，不能只凭“执行签名相同”就证明所有计数未变。新系列的强门也不能替代方法假设的审查。

当前Review缓存的signature与当前签名构造器不相同（identity和executionSourceSha256不同），所以直接调用现行Review入口会在恢复门处被拒绝。这是尚待闭合的版本兼容性，不是已验证可以透明续跑；详见审计F09。

### 13.2 写入与中断

新四曲线每50个完成job持久化；临时MAT写入后复载验证摘要，再替换检查点。中断后保留已完成ID，未持久化job按原ID/seed重试。不能清空检查点、重选号或只保留成功曲线。

重复使用已完成runner通常还会重新写CSV/PNG，即便不增加包。审计若要求只读，应直接load/readtable，而不执行runner或`audit/validatePilotTimeAlignedResults`。

### 13.3 版本目录与受控迁移

当前默认 PaperPoint 用 `_runner_v3` 独立目录，避免新签名撞上旧Paper检查点。原Paper接收器/已完成结果保留。

过去为加入串行执行选项或修输出命名空间，做过只更新运行器源码hash/状态摘要的受控迁移：有before-image、旧摘要及其他依赖hash检查、所有数组不变证明。本次审计没有再迁移任何状态。

绝对路径、私有MATLAB序列化接口和固定R2022a环境都是复现约束。移动项目、升级MATLAB或改冻结清单不应通过忽略签名错误来解决。

## 14. 入口选择与安全阅读

下面是入口说明，不是本次执行指令。任何运行前先核对实验ID、Mode、数据目录和是否会写文件。

| 目的 | 入口 | 注意 |
|---|---|---|
| 旧 EXP1 单元测试 | `runExp1Tests` | 不是 V8/Paper 全部测试；会执行测试 |
| 旧 EXP1 阶段 | `runExp1Pilot/Formal/Ablation` | 157T旧系列，不是 V8 Formal |
| 当前 V8 机制/Review | `runSenloraSymmetricV8JointBlockValidation/Review` | 固定20/100包每pair；现有Review缓存有F09兼容性限制；可能写文件/开并行池 |
| native AWGN Case-SNR | `runSenloraSymmetricV8CaseSnrCurve` | 固定两Case、-30…-21；写结果 |
| native Rician Case-SNR | `runSenloraSymmetricV8RicianCaseSnrCurve` | packet-flat K10；写结果 |
| 四曲线 | `runSenloraPaperPointFourCurves` | 必须明确Stage和ReceiverMode；默认PaperPoint不是时间对齐变体 |
| AWGN CI图 | `plotSenloraFigure12AwgnUncertainty` | 不加包，但写新的图/统计文件 |
| 全量结果validator | `audit/validatePilotTimeAlignedResults` | 含完成状态续跑和重新导出，不是纯只读检查 |

只读查看某组结果可采用：

```matlab
root = 'D:/codex/Lora（SER performance of different estimation strategies）/results/senlora_symmetric_v8/figure12_pilot_time_aligned';
raw = readtable(fullfile(root,'FOUR_CURVE_RAW_PACKETS.csv'));
summary = readtable(fullfile(root,'FOUR_CURVE_SUMMARY.csv'));
checkpoint = load(fullfile(root,'FOUR_CURVE_CHECKPOINT.mat'));
result = load(fullfile(root,'FOUR_CURVE_RESULT.mat'));
assert(isequaln(checkpoint,result));
```

这个例子不仿真、不续跑、不绘图；它也没有替代完整状态摘要/依赖hash核验。

目前没有一个已发布、满足专属预注册条件的 V8 Formal 入口可直接当作“下一步”执行。计划中的9×1000镜像对-包应是9000个pair-packet、18000帧，而不是用现有五点结果凑数。

## 15. 当前能力与不能承诺的事情

**已经具备**：统一V8入口；同帧Static/Dynamic完整轨迹融合；固定CR3/no-LDRO；逐包复现；原生VP/PREC与自有导频帧比较；真实结果/离线Ideal；源码和参数冻结；部分完整结果的强签名与断点恢复；原始点图和按包统计。

**尚不能承诺**：V8已满足Formal全部验收；SER曲线必然平直/单调；每点VP都高于解析理论或经验Ideal；当前时间对齐变体等于论文原始第三方法；所有方法的包能量/等待时延相同；轨道所有配置字段都已使用；MATLABheap corruption已解决；已实现流式或硬件接收；工程“ML”命名代表全局最优。

## 16. 本次审计与后续工作边界

本次审计新检查：97份MATLAB静态检查0发现；父库52项、V8六源码及三Review证据hash匹配；最新30000行的ID/整数计数/分母/MAT-CSV/摘要/依赖一致；审阅源文件在审计期间没有变化。

确认的问题、优先级和建议见审计报告。下一轮应先决定Formal容差与方法定义，再修统计/失败门、补遥测和行为测试，最后重新冻结。没有用户授权，不因为审计发现问题就改接收算法、选择种子、补跑或重写现有图。

额外只读复核确认新默认Paper V3两个目录仅完成40/20000、20/10000（两包/点烟测），不是新的完整1000包曲线；旧Paper完成结果和最新时间对齐变体结果仍在各自独立目录。

本文和审计报告是仅有的新增文件；所有既有源码、参数、日志、结果与原图保持不变。
