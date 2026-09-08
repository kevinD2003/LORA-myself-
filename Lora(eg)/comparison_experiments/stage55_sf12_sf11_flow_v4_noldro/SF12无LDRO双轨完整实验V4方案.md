# SF12 无 LDRO 双轨完整实验 V4 方案（R4：阶段 3R 机制重构）

修订日期：2026-09-07

修订方案标识：`V4-noLDRO-plan-R4-track-a-stage3r`。基线为外部 `../SF12无LDRO双轨完整实验V4方案_审计修订版.md`（R3）与已签名实施证据；本版明确修订的 Track A 重构、预算和实施阶段门优先，其余规范继续继承 R3。本文件是后续 R4 实施的方案入口，不能把旧 R3 manifest 或审计自动视为 R4 已冻结、已通过。

修订依据：`V4_STAGE3_BLOCKER_REVISION_REQUEST.md`，SHA-256 为 `f3a68ebaeed2a47f50eca88af2d0504da51277551ff43102d4f462c6c5ae2290`，与用户提供值一致。用户已选择“重构 Track A Stage55，保持原质量门”。本次授权范围为修改方案，不包含启动代码修改或新的 calibration、validation、smoke、formal。

当前实际状态仍为 `STAGE_03 = FAIL / DO_NOT_ADMIT_STAGE_4`；阶段 3R 为 `NOT_STARTED`。实验 B 仍要求实验 A PASS。修订方案不改变既有失败事实，也不产生任何新实验通过证据。

## 1. 研究目标与结论边界

V4 有两个相互独立但共享 no-LDRO PHY 定义的实验轨道：

1. Track A：尽量接近 Farhat et al. 论文条件，检查 Paper Midamble-Point 的 SER 和 Doppler tracking 趋势；
2. Track B：把 Paper Midamble-Point 移植到完整 SF12 no-LDRO、CR3、768-bit、112-data-symbol 项目中，与 Stage55-VP 和 Huang-PREC/static-CP 公平比较。

必须长期保持以下身份区分：

- Track A 是 `Paper-condition SF12 no-LDRO anchor`；
- Track A 的论文接收机是 `Paper-native`；
- Track B 的论文接收机是 `Paper-adapted`；
- Track B 的 Stage55 是 SF11 完整流程的 SF12 no-LDRO 移植；
- Paper-adapted 不是论文 Fig.10/Fig.11 的精确复现；
- 性能排序只能来自冻结参数后的 formal blind results；
- 不设置“Stage55 必须优于 Paper”的测试或停止条件。

## 2. 版本和只读边界

V4 工程位于：

```text
D:\codex\Lora(eg)\comparison_experiments\stage55_sf12_sf11_flow_v4_noldro
```

以下工程保持历史冻结：

- V2：SF12 paper-condition LDRO 历史实验；
- V3：SF12 完整流程 LDRO 历史实验；
- SF11：规范主项目及其结果。

V4 不得读取或续跑 V2/V3 checkpoint，不得用其正式曲线选择参数，不得覆盖其源码、manifest 或结果。V4 的代码、配置、参数、种子、checkpoint、报告和算法签名全部独立。

## 3. 公共 SF12 no-LDRO PHY

Track A 和 Track B 共同固定：

```text
physicalSf = 12
effectiveDataSf = 12
ldro = false
bandwidthHz = 125000
sampleRateHz = 125000
samplesPerSymbol = 4096
symbolDurationSec = 0.032768
fftBinSpacingHz = 30.517578125
dataAlphabetSize = 4096
dataBinSpacing = 1
physicalBin = logicalBin
```

V4 中禁止残留有效的：

```text
effectiveDataSf = 10
dataAlphabetSize = 1024
dataBinSpacing = 4
physicalBin = 4 * logicalBin
logicalBin = physicalBin / 4
physicalBin % 4 == 0
```

4096 点 FFT 的每个 bin 都是合法数据标签。硬判决直接取 FFT 最大能量 bin；软概率直接在 4096 个 bin 上归一化，不再做 spacing-4 区域聚合。Gray LLR 必须计算 12 个 bit。

## 4. Track A：Paper-condition no-LDRO anchor

### 4.1 固定条件

- SF=12、BW=125 kHz、Fs=125 kHz、FC=868 MHz；
- LDRO=false，4096 个直接物理标签；
- L=120 bit 仅作为论文场景元数据；
- CR=1 场景身份；
- 23 个 payload 数据符号；
- Paper Case1/Case2 固定位置；
- `n_int=3`；
- packet-flat Rician K=10 dB；
- 最后一个完整同步 downchirp 用作 Point 初始 CFO；
- 主性能指标为 SER。

Track A 仍是 symbol-level paper adapter。除非另行实现并独立验证完整标准 LoRa CR1、交织、填充、包头和白化，否则：

- 不能声称 120 bit 严格编码生成了 23 个符号；
- 不能报告 CR1 BER、CR1 PER 或伪信息位 goodput；
- 只报告 SER、CFO RMSE、Midamble/VP 接纳、误接纳、开销、运行时间和 deadline。

### 4.2 Paper-native

方法名固定为：

```text
Paper-Midamble-Point-native-SF12-noLDRO
```

要求：

- 初始 Point CFO 使用论文式 dechirp 后 FFT-bin peak estimator；
- Midamble residual CFO 同样使用 FFT-bin peak estimator；
- 估计分辨率为整数物理 FFT bin；
- 不调用 Stage55 的 sub-bin refined CFO search；
- 不使用轨道真值、Payload 判决或未来样本；
- Midamble 之间使用论文定义的分段常数补偿。

### 4.3 Track A Stage55 与诊断基线

Track A 的对比方法：

```text
Stage55-VP-quality-SER-SF12-noLDRO
```

必须增加两个诊断基线：

1. `No-Doppler-Rician-AWGN-SF12-noLDRO`：检查 PHY、SNR 和信道定义；
2. `Paper-Point-native-SF12-noLDRO`：只使用最后一个 downchirp 的 Point CFO，全 payload 固定补偿，不做 Midamble 更新。

诊断顺序：No-Doppler 失败先查 PHY/SNR；Point 失败查 bootstrap/CFO estimator；Point 正常而 Midamble-Point 失败查 Midamble 更新和时间轴。

### 4.4 阶段 3 的失败事实与重构边界

阶段 1 来源/接口冻结、阶段 2 公共 PHY 和阶段 3 确定性机制测试已有 PASS 证据；原 Track A Stage55 在三轮参数预算内未通过独立 validation。每个 Case 在 -21 dB 使用 2000 个独立 packet、46000 个可产生 VP 的数据符号，真实结果如下：

| 参数版本 | Calibration | Case | 实际接纳 | 误接纳 | false-acceptance | coverage | Validation |
|---|---|---|---:|---:|---:|---:|---|
| A-param-v01 | PASS | -366 s | 43375 | 2610 | 6.0173% | 94.2935% | FAIL |
| A-param-v01 | PASS | 0 s | 42159 | 6213 | 14.7371% | 91.6500% | FAIL |
| A-param-v02 | FAIL | 两个 Case | — | — | — | — | NOT_APPLICABLE |
| A-param-v03 | PASS | -366 s | 3820 | 175 | 4.5812% | 8.3043% | FAIL |
| A-param-v03 | PASS | 0 s | 2098 | 1965 | 93.6606% | 4.5609% | FAIL |

v02 没有候选同时满足质量门，未进入 validation。其失败产物保存逻辑修复后的同候选、同确定性种子复跑仅补齐失败证据，不算新一轮。v03 的低 SNR 数值安全不能抵消 -21 dB 失败。

原始证据保留在 `results/calibration/track_a/A-param-v02/track_a_calibration.json`、`results/validation/track_a/A-param-v01/track_a_validation.json`、`results/validation/track_a/A-param-v03/track_a_validation.json` 及 `results/audits/STAGE_03_EXPERIMENT_A_SMOKE_AUDIT.md`。最后一个文件虽含 SMOKE 名称，实际审计明确 smoke 未运行；不得因此把 validation 改称 smoke。

Case 0 无噪声诊断显示，第一个数据符号中心真实 CFO 约 -3.2214 bin，而初始 Point 为 -3 bin。严格单符号门可能漏掉第二个早期正确 VP，使 rate 保持 0；随后 CFO 误差越过半 bin，错误硬标签仍可能呈现高峰、低熵、小局部 residual，并形成错误整数分支的自洽跟踪。这些真值只用于离线解释，禁止作为重构接收机的输入。

结论限定为“当前已实现机制在原候选预算和固定 validation 门下未准入”，不能推断所有无编码机制都不可行，不能据 validation 宣称 Stage55/Paper 正式优劣。重构是新机制版本，不是给旧机制追加第四轮阈值搜索。

重构继续固定以下条件：

- Track A 独立圆轨道及 Case 前导起点 -366 s、0 s；不替换为 Track B 轨道，也不向接收机提供轨道先验；
- `8U + 2 down + 0.25 down + (DDD M)×7 + DD + terminal M`，23 D、8 M、总长 `41.25T = 1.351680 s`；
- Paper-native 初始 Point/Midamble 均为有符号整数 FFT-bin 估计，residual CFO 累加且只影响后续时隙；
- Stage55 不读取 M，不调用 Hamming、块软置信或相位对 CFO；仍为无编码符号级适配器；
- terminal M 不改变过去判决，也不向下一独立 packet 传状态；Stage55 的 pending/history/失锁状态同样逐包重置。

### 4.5 Track A Stage55 新机制：因果双测量启动与失锁保护

采用 `B4_COMBINATION = B1_CAUSAL_TWO_MEASUREMENT_BOOTSTRAP + B3_FAIL_CLOSED_BRANCH_LOCK`，新算法版本为 `Stage55-A-causal-pending-lock-v1`。方法族名称仍为第 4.3 节名称，但图例、目录、manifest 必须附算法版本，不能与旧机制混同。此组合是本修订稿的实施设计，不是已经验证有效的结论；若无编码随机标签的分支歧义仍不能解决，允许并必须如实失败。

**可见输入与候选。** 只允许本包已到达的初始 Point 观测、当前及过去 D 的 IQ/FFT、接收机产生的硬标签、单符号 residual/质量量、符号中心与完成时间以及自身历史预测。候选 i 冻结为 `(hardLabel_i, t_i, availableAt_i, cfoCandidate_i, quality_i)`；硬标签取该符号当时补偿后的判决。CFO 候选为当时补偿量加单符号 residual，必须保留补偿参考、符号方向及 bin 单位，不得用后来的重判决替换。禁止 payload truth、true CFO/rate、orbit truth、true channel coefficient、future samples，也禁止将 Midamble 或编码冗余作为 Stage55 新观测。

**状态。** 使用 `PENDING_BOOTSTRAP → LOCKED → LOST`。初始状态沿用本包 Point 的 CFO 和零 rate；候选在 pending 中不算接纳、不更新 tracker、不影响当前或过去符号。启动窗口固定为最近 3 个已完成 D，过期候选丢弃；每个 D 仅生成一个不可变候选，不搜索替代 payload 标签。

**双测量发布。** 只使用窗口内两个不同中心时刻、均通过单符号门的候选。对 `t_j > t_i` 定义：

```text
rate_ij = (cfoCandidate_j - cfoCandidate_i) / (t_j - t_i)
fit_ij(t) = cfoCandidate_j + rate_ij * (t - t_j)
```

二者必须分别满足相对于当时 Point/预测的预冻结 innovation 门，`abs(rate_ij)` 必须满足全 Case 共用的冻结速率上界；窗口内已有合格候选对 `fit_ij` 的残差须满足冻结一致性门。只有两个点时拟合残差天然为零，不能把它当成额外的分支正确性证据。不得借用真实 Doppler rate 设定 Case 专属上界；不得靠添加整数偏移重新挑选硬标签使候选通过。若多个合格候选对指向不一致整数分支，则继续 pending；没有唯一一致分支就不发布。多个一致候选对按最早第二测量时间、再最早第一测量时间确定，不能按真值或 SER 选择。

确认时将选中的两个原始候选以同一事务提交 tracker，仅按各自实际测量时间参与 CFO/rate 拟合，进入 `LOCKED`；它们的发布时间都是确认所需最后一个样本到达之后。剩余 pending 清空。阈值只可在第 12 节限定的 calibration 候选中选择，第一次运行前冻结候选表及确切整数分支一致性判据，不能根据 validation 再补解释。

**锁定与失锁。** `LOCKED` 中后续 VP 仍须通过单符号门、预测 innovation 门和历史斜率/残差一致性门；tracker 的已提交 history 最多保留 8 项，测量时间严格递增，权重/衰减/Huber 参数随候选版本冻结。发生可见的整数分支冲突，或连续 3 个 D 没有可接纳更新，即转入 `LOST`，拒绝触发失锁的候选并清空 pending；本包不再尝试重捕获或接纳 VP。失锁后保持最后可信 CFO/rate 的既定预测规则至包末并继续输出数据判决，报告失锁时间与持续时长，不删除这些 packet 或降低统计分母。无接纳或低覆盖仍须承担原质量门失败。局部一致性不能保证识别所有错误分支；能否满足 2% 门只能由全新独立 validation 判断。

**发布时间与首次生效。** 每条候选记录 `measurementTimeSec`、`decisionAtSec`、`availableAtSec`、`releaseAtSec`、`firstEffectiveTimeSec`。若确认依赖符号 j，则 `releaseAtSec >= availableAt_j`；首次生效只能是发布完成后首个尚未开始处理的物理时隙。不得回写 i、j 或已经完成的时隙，不能把 pending 的测量时间当作接纳时间。实际处理延迟越过边界时继续顺延，不能靠回填时间戳掩盖延迟。最后一个 D 后的发布不能改善本包已结束的 payload，也不能传入下一包。

**接纳计数。** 接纳事件只在候选实际提交 tracker 时发生，每个原始 D 最多计一次；双测量提交计两个 VP，重复拟合不重复计数。pending、过期、拒绝、失锁后候选均不算接纳，但对应 D 仍属于可产生 VP 的分母。离线评分用提交时冻结的硬标签与 payload truth 比较，真值评分器必须位于接收机调用链之外。

## 5. Track B：完整 SF11 流程的 SF12 no-LDRO 移植

### 5.1 编码身份

Track B 固定为：

```text
16 blocks × 12 rows × 4 information bits = 768 information bits
16 blocks × 7 coded symbols = 112 payload data symbols
```

单块链路：

```text
12×4 information bits
→ 12×7 Hamming(7,4)
→ 12-row diagonal interleaving
→ 7 个 12-bit Gray labels
→ Gray decode
→ 0–4095 physical FFT bins
```

接收链：

```text
4096 FFT-bin probabilities
→ 12 Gray-bit LLRs
→ 12-row soft deinterleaving
→ 12 个 ML Hamming(7,4)
→ 12×4 information bits per block
```

第 11、12 bit 必须真实参与 Hamming、交织、LLR、硬译码和 ML 软译码。

### 5.2 三个主方法

```text
Huang-PREC-static-CP-SF12-noLDRO
Stage55-VP-quality-CR3-SF12-noLDRO
Paper-Midamble-Point-SF12-CR3-noLDRO-adapted
```

Paper-adapted 可以复用项目统一的 bootstrap、时间轴和经 V4 标定的基础 CFO 设施，但名称、manifest 和报告必须标注 `adapted`，不能作为 Paper-native 或论文原图数值复现。

### 5.3 Stage55 因果机制

- 最多 5 次软置信迭代；
- 软信息只决定 VP 接纳；
- VP 标签始终来自补偿后的硬 LoRa 判决；
- 当前 7-symbol Hamming 块完整到达后，软结果才能影响后续物理符号；
- rolling history 最多 8 项；
- 使用历史衰减、peak 权重和 Huber 拟合；
- 使用单符号 CFO 融合、双门保护的相位对 CFO 和 VP 速率可观测性门；
- 禁止 Payload/轨道/信道真值和任何未来信息进入接收机。

## 6. Paper-native 与 Paper-adapted 的强制隔离

| 项目 | Paper-native（Track A） | Paper-adapted（Track B） |
|---|---|---|
| 目标 | 论文趋势锚定 | 项目条件下公平比较 |
| Payload | 23 symbol-level labels | 112 个 CR3 数据符号 |
| 初始 CFO | 最后 downchirp FFT-bin Point | 共同 8-upchirp bootstrap |
| residual CFO | 原生 FFT-bin peak | 可用 V4 统一精细估计器 |
| sub-bin search | 禁止 | 允许，但须标注 adapted |
| 编码指标 | 不报告伪 BER/PER | 768-bit 硬/软 BER、PER |
| 统计单位 | paired packet | complete satellite pass |

代码、配置、测试和结果目录必须分别命名，禁止通过一个布尔开关让两种 Paper 身份共享同一未审计实现。

## 7. Track B 的两种公平比较口径

### 7.1 Controlled-time algorithm comparison

目的：比较相同 Doppler 时间位置下的算法跟踪能力。

Paper 时间轴：

```text
D D D M D D D M ...
```

其中 D 是 payload，M 是已知纯 upchirp Midamble。

Stage55/Huang：

- 不读取、不解调、不接纳 M；
- 在 M 时隙保持接收机算法无观测更新；
- 物理时钟、Doppler oscillator、Doppler phase 和信道状态继续推进；
- payload D 与 Paper 出现在相同绝对物理时刻。

共享的是 Payload bits/labels、轨道、随机账本、初始条件和 payload 时刻。不得声明三方法整帧 raw complex array 逐样本相同；它们的帧内容和数组长度/占位定义不同。受控比较只要求公共 D 时刻的底层随机实现按账本对应。

### 7.2 Native-overhead system comparison

目的：比较发送同一 768-bit Payload 的真实系统代价。

- Paper：112 D + 37 M，157 个物理符号；
- Stage55/Huang：112 D，不发送 M；加上共同前导后采用各自自然帧长度；
- 各方法使用自己的自然 `frameStartTimes`，不强行对齐 payload 绝对时刻；
- 共享同一轨道模型和预注册随机账本映射，但不宣称 raw samples 配对相同。

单独报告 SER、硬 BER、ML BER、PER、goodput、ToA、Midamble overhead、runtime、deadline 和 energy proxy。energy proxy 在没有射频功率模型时只定义为“单位发射功率 × 发射 airtime”，不得称为实测焦耳能耗。

Controlled-time 与 native-overhead 必须使用不同结果目录和图例，不能合并为一条曲线。

## 8. 明确帧时间模型

所有运行配置和 manifest 必须显式包含：

```text
timelineMode
scheduleType
frameStartTimesSec
interFrameGapSec
frameDurationSec
payloadStartTimesSec
payloadSymbolTimesSec
midambleTimesSec
```

允许的 `scheduleType`：

- `back_to_back`
- `fixed_interval`
- `custom_pass`

V4 Track B 的主研究身份固定为连续 burst / continuous-pass，不推广到长间隔 LoRaWAN 稀疏上报：

- controlled-time：`scheduleType=custom_pass`，以 157-symbol 公共受控时钟生成显式 `frameStartTimesSec`，`interFrameGapSec=0`；
- native-overhead：每种方法 `scheduleType=back_to_back`，按各自自然帧时长生成独立 `frameStartTimesSec`，`interFrameGapSec=0`；
- 自定义间隔实验只能作为新扩展，不能混入主结果。

跨帧 rolling-8 的测量时间必须来自 manifest 中的实际前导中心时刻，禁止用帧序号代替物理时间。

## 9. 轨道、信道和相位状态

### 9.1 轨道

Track B 保持 SF11 的圆轨道几何：地球半径 6371 km、高度 550 km、倾角 15°、FC 868 MHz、理论最大仰角 56°、通信仰角 10°、中央盲区边界 50°、中央时刻 0 s。Doppler 逐采样计算并积分相位。

### 9.2 信道

Track A 使用 Rician 主信道；Track B 以 AWGN 为主，Rician 作为独立补充：

```text
r(t) = h_k * x(t) * exp(j*phi_Doppler(t)) + n(t)
```

- `phi_Doppler(t)` 在数据、Midamble、空置时隙和包边界连续；
- `h_k` 是每包重新采样的 packet-flat Rician K=10 dB 复系数；
- `angle(h_k)` 可以在包边界跳变；
- AWGN 以单位平均发射功率和 125 kHz 带宽定义；
- AWGN-only 是机制基线，不是第四主方法。

跨帧允许延续：Doppler oscillator state、模型 Doppler phase state、接收机可见 CFO/rate history。禁止直接把上一包接收信号的绝对复相位作为下一包接收机相位，因为它包含 `angle(h_k)`。每帧接收机相位必须由本帧公共前导重新观测；跨帧状态不得含 channel phase。

## 10. 公平性账本

Track B 三方法必须共享：

- 相同 768-bit Payload；
- 相同 112 个数据 labels；
- 相同轨道和 Doppler realization 定义；
- 相同 Rician/AWGN 随机账本；
- 相同 bootstrap 输入定义；
- 相同硬/软译码口径；
- 相同统计单位。

在 controlled-time 中，公共数据时刻的 Rician/AWGN realization 必须通过显式索引映射对应。在 native-overhead 中，方法时间轴不同，只共享种子域和生成规则，不声称样本逐点相同。

接收机接口禁止：Payload truth、Doppler truth、true CFO、true Doppler rate、true channel coefficient、future symbol、future Hamming block、future frame。

## 11. 独立 PHY golden vectors

TX→RX 4096/4096 自洽测试不足以证明方向正确，必须新增不调用完整 V4 TX 映射链生成期望值的 golden-vector 测试。

固定物理符号：

```text
0, 1, 2, 3, 1023, 1024, 2047, 4094, 4095
```

测试独立使用数学公式：

```text
x_s[n] = exp(j*2*pi*(n^2/(2M)-n/2+s*n/M)), M=4096
```

经独立 downchirp 和 4096 FFT 后必须落在 s。还必须固定人工 12-bit Gray/coded-bit 矩阵，独立验证 Gray encode/decode、bit ordering、12-row interleaver/deinterleaver 方向和 FFT bin 正负方向。

强制证明：`physicalBin==logicalBin`，无 ×4/÷4/%4 限制，第 11、12 bit 会改变物理标签并能从 LLR/译码恢复。

## 12. 参数标定与版本隔离

V2/V3 参数不得直接用于 V4。Track A Paper-native 的整数 bin estimator 不接受 Stage55 sub-bin 参数；Track A Stage55 和 Track B 接收机分别标定并分别冻结 manifest。

必须分离 calibration、validation 和 formal 种子域。正式前冻结：

- code hash
- source manifest
- receiver parameter manifest
- algorithm signature
- random seed ledger
- PHY configuration
- frame timing configuration
- comparison mode

标定只使用 CFO error、置信覆盖、误接纳、rate observability、half-bin exceedance 和信道单位功率。half-bin exceedance 指数据中心预测 CFO 误差绝对值至少 0.5 bin，不等同于持续整数分支锁错或真实相位 cycle slip。禁止读取 formal 曲线或论文图 marker 反向调参。真值只供隔离的离线评分器计算机制指标，不得进入接收机。

### 12.1 阶段 3R 的有限预算

```text
NEW_ALGORITHM_VERSION = Stage55-A-causal-pending-lock-v1
NEW_PARAMETER_VERSIONS = A-3R-param-v01; A-3R-param-v02
MAX_NEW_PARAMETER_ROUNDS = 2
MAX_CANDIDATES_PER_ROUND = 32
NEW_MECHANISM_DOMAIN = a_3r_mechanism_v1
NEW_CALIBRATION_DOMAIN_NAMES = a_3r_calibration_v1; a_3r_calibration_v2
NEW_VALIDATION_DOMAIN_NAMES = a_3r_validation_v1; a_3r_validation_v2
NEW_LOW_SNR_SAFETY_DOMAIN_NAMES = a_3r_safety_v1; a_3r_safety_v2
NEW_SMOKE_DOMAIN = a_3r_smoke_v1
NEW_FORMAL_DOMAIN = a_3r_formal_v1
NEW_BOOTSTRAP_DOMAIN = a_3r_bootstrap_v1
PACKETS_PER_CASE_AT_MINUS21_DB = 2000
LOW_SNR_SAFETY_PACKET_COUNTS = 500 per Case at each of -30 dB and -25 dB
KEEP_FALSE_ACCEPTANCE_MAXIMUM_2_PERCENT = YES
KEEP_COVERAGE_MINIMUM_1_PERCENT = YES
KEEP_ACCEPTED_MINIMUM_200 = YES
```

每轮运行前冻结不超过 32 组候选、calibration 样本数、根种子/substream 映射和算法签名；禁止边看当轮结果边扩展候选表。calibration 样本量是准入冻结字段，不得留空启动。新域必须与原 v1/v2/v3、Track B、smoke/formal 和各自评分 bootstrap 域核对无交集，不能只改目录名而复用旧随机样本。

每轮每个候选在每个 Case 固定使用 500 个 calibration packet；32 个候选即每轮最多 32000 packet，两轮最多 64000 packet。候选间共享相同 Case/packet 的 payload、Rician 和 noise 键以降低候选比较方差，但 candidateId 不进入这些物理随机键；所有候选接收机状态仍独立。

第一轮 `A-3R-param-v01` 为五个二值轴的 32 组全因子：`decisionPeakRatioThreshold=[1.5,3.0]`、`maximumNormalizedEntropy=[0.50,0.80]`、`innovationLimitBins=[0.20,0.35]`、`maximumRateBinsPerSec=[12,16]`、`branchResidualLimitBins=[0.15,0.30]`。第二轮 `A-3R-param-v02` 预注册为：`decisionPeakRatioThreshold=[2.5,4.0]`、`maximumNormalizedEntropy=[0.35,0.65]`、`innovationLimitBins=[0.15,0.25]`、`maximumRateBinsPerSec=[10,18]`、`branchResidualLimitBins=[0.10,0.20]`。两轮共同固定 `residualPeakRatioThreshold=1.01`、`residualStepBins=0.05`、`historyDecay=0.85`、`huberThresholdBins=0.15`、`branchRateAgreementLimitBinsPerSec=2`、pending窗口3、连续拒绝3、history长度8。

calibration中每个候选须在两个 Case 分别满足 `falseAcceptance<=2%`、`coverage>=1%`；500×23的分母使coverage门对应每Case至少115次提交。合格候选先最大化两个Case中较低的coverage，再最小化两个Case等权CFO RMSE，最后取候选编号最小者。不得跨Case池化质量门。

候选排序继承 R3：先满足质量门，再最大 coverage、最小 CFO RMSE、最低候选编号；不得用 SER、BER、论文 marker 或 Stage55-Paper 排序。calibration 不通过也消耗一轮，不进入该轮 validation；通过后冻结唯一候选，以同一候选对两个 Case 分别运行全新 validation。两个 Case 必须同时通过，不跨 Case 池化、不按 Case 挑不同阈值。

第一轮 validation 失败后完整保留所有原始产物，后续门禁决策仅引用失败审计和汇总门指标；第二轮使用新参数版本及全新种子域。不得将旧 validation packet、候选级结果或失败样本回灌 calibration，也不得在同一 validation 集上试多个参数。原 `a_validation_v1/v2/v3` 永久退出调参用途。两轮用尽仍失败则停止于阶段 3R，保留 FAIL，禁止自动追加第三轮、改算法名重置预算或给旧机制追加第四轮。机制结构超出第 4.5 节范围时须另行修订方案，不能当参数变更绕过预算。

### 12.2 固定 validation 门和低 SNR 安全

每个 Case 在 -21 dB 独立计算：

```text
falseAcceptance = falseAcceptedVp / actualCommittedVp <= 0.02
coverage = actualCommittedVp / (2000 * 23) >= 0.01
actualCommittedVp >= 200
```

分母 `actualCommittedVp=0` 时 false-acceptance 为 undefined，直接判门失败，不能填 0。三个条件同时检查；coverage 门按全部 46000 个 D 计算，pending、丢弃和失锁不能减少分母。1% coverage 在该固定样本量下实际要求至少 460 次接纳，仍显式保留 200 次接纳门，不以其替换 coverage 门。

2% 是观察比例的工程门，同时报告 packet 聚类不确定性；不声称真实误接纳率已被 95% 证明低于 2%。另在 -30、-25 dB 各 Case 各 500 个新 packet 上检查 NaN/Inf、因果性、状态有界及失锁行为，低 SNR 允许低覆盖，但不得因此放宽 -21 dB 主门。安全检查失败同样不得准入。

validation 和安全检查通过后，使用新 smoke 域对两个 Case 各 16 个 packet 检查 wiring、随机配对、因果发布、checkpoint 恢复及完整产物；smoke 不作性能排序或再次调参。阶段 3R 审计 PASS 后方可进入实验 A formal。

### 12.3 版本和失败证据保留

```text
DECISION_D = KEEP_ALL_AS_SUPERSEDED_FAILURE_EVIDENCE
ALLOW_OVERWRITE_V1_V2_V3 = NO
ALLOW_MERGE_WITH_NEW_RESULTS = NO
```

原 R3 的源码/配置签名、参数、种子账本、calibration/validation JSON 和阶段 3 FAIL 审计全部保留。`superseded` 仅表示后续采用新机制，不撤销失败结论。R4 产物使用包含 `stage3r/Stage55-A-causal-pending-lock-v1/A-3R-param-vNN` 的独立版本目录；新方案、代码、参数、种子、结果和审计共同签名，不得覆盖旧文件或跨签名拼接。修改公共代码时，R3 快照及失败证据的可解释性必须保留。

后续获准实施时，先创建新的版本化 `plan_manifest`，记录本 R4 方案与修订单各自 SHA-256、父 R3 方案哈希、用户路线选择、算法版本、预算、实验 B 准入规则及源文件摘要；旧 `config/plan_manifest.json` 仍是 R3 历史证据，不能覆写以冒充原结果来自 R4。本方案自身 SHA-256 由外部 manifest 保存，不把自引用哈希写回正文。

## 13. 统计协议

第 13 节沿用外部规范 R3 及现有 `plan_manifest.json` 已冻结的固定样本量，删除实施副本残留的 precision stopping 规则；这不是为解决阶段 3 失败而改变统计预算。阶段 3R 仅重构机制与开发预算，不缩减 formal。

### 13.1 Track A

- 统计单位：paired packet；
- SNR：`-30:-21 dB`；
- Case1/Case2 分开；
- 每个 Case/SNR 固定 20000 paired packets；
- 每 250 packets 原子 checkpoint；
- 完成固定预算后计算主要 ΔSER 的 paired packet bootstrap CI；
- CI half-width >0.01 时标记 `precision-inconclusive`，不得为达标追加样本。

### 13.2 Track B

- 统计单位：完整 satellite pass，禁止把同一过境中的帧当独立样本；
- SNR：`-30:-21 dB`；
- controlled-time 和 native-overhead 分开运行；
- AWGN 主结果、Rician 独立补充均为每个 mode×SNR 固定 50 paired complete passes；
- 每个完整 pass 原子 checkpoint，完成固定预算后计算 CI；
- 主要比较：Stage55 minus Paper-adapted；Huang 作为控制同时报告；
- 主要差值：ΔSER、Δhard-BER、ΔML-BER、ΔPER、Δgoodput；
- 以完整过境做 paired cluster bootstrap，10000 次联合重采样；
- 最终精度标签：ΔSER half-width≤0.02、Δhard-BER≤0.01、ΔML-BER≤0.01、ΔPER-ML≤0.05、native Δgoodput≤10 bit/s；
- 未满足的指标标记 `precision-inconclusive`，保留所有数值，不追加样本。

两轨均禁止根据 CI、错误数、误接纳或方法排序提前停止或补跑至显著。资源中断只允许同签名恢复到固定预算；主动缩减为 `incomplete`。点态近似 95% percentile CI、零错误独立单位上界、`degenerate-bootstrap` 的 Hoeffding 保护和 B 逐 pass 等权估计严格继承外部 R3 第 11.3 节，不把零宽 bootstrap 区间视为精度已达标。

## 14. 新 config / manifest 字段

公共 PHY：

```text
physicalSf, effectiveDataSf, ldro, dataAlphabetSize, dataBinSpacing
bandwidthHz, sampleRateHz, samplesPerSymbol, symbolDurationSec, fftBinSpacingHz
grayBitOrder, fftBinDirection, interleaverDirection
```

实验身份：

```text
trackId, paperIdentity, comparisonMode, estimatorResolution
reportsBitMetrics, isExactPaperFigureReplication
```

时间模型：

```text
timelineMode, scheduleType, frameStartTimesSec, interFrameGapSec
frameDurationSec, payloadStartTimesSec, payloadSymbolTimesSec, midambleTimesSec
```

信道和相位：

```text
channelModel, ricianKDb, ricianResampleUnit
dopplerPhaseContinuous, channelPhaseContinuousAcrossPackets
receiverPhaseResetSource, crossFrameStateFields
```

统计和恢复：

```text
clusterUnit, fixedClusters, checkpointInterval
bootstrapDraws, ciHalfWidthTargets, errorBudgets
seedDomain, seedLedgerHash, codeHash, sourceManifestHash
parameterManifestHash, frameTimingHash, algorithmSignature
```

阶段 3R 另增：

```text
parentPlanVersion, parentPlanSha256, revisionRequestSha256, approvalScope
algorithmVersion, parameterRound, maximumRounds, maximumCandidatesPerRound
candidateTableHash, calibrationSampleCounts, validationGate, lowSnrSafety
pendingWindowDataSymbols, branchConsistencyRule, branchConsistencyThresholds
lockState, consecutiveRejectedDataSymbols, lossReason, lossTimeSec
measurementTimeSec, decisionAtSec, availableAtSec, releaseAtSec, firstEffectiveTimeSec
candidateId, committedHardLabel, committedVpCount, expiredVpCount
experimentBEntryRule, supersededFailureEvidencePaths
```

## 15. 实施阶段和门禁

本节按修订单的实际执行顺序统一阶段编号，替换旧实施副本将 Track B 穿插在实验 A 结束前的阶段表。历史 R3 文件仍保留原名和原签名，不能按新表重命名后伪造通过。

| 阶段 | 工作与准入要求 | 当前状态/证据 |
|---|---|---|
| 0 | 原始来源、论文身份、方案与只读边界冻结 | 历史记录保留；R4 实施前另冻结新 manifest |
| 1 | 来源、接口和版本冻结；34 个 upstream_sf11 文件与规范 project 同名源码哈希一致 | 历史 PASS：`results/audits/STAGE_01_SOURCE_AND_INTERFACE_AUDIT.md` |
| 2 | 公共 SF12 no-LDRO PHY、4096 全标签、独立 chirp/Gray/交织和信道功率机制测试 | 历史 PASS：`results/audits/STAGE_02_COMMON_PHY_AUDIT.md` |
| 3 | 原实验 A 机制、三轮 calibration/validation，质量门后才能 smoke | FAIL：`results/audits/STAGE_03_EXPERIMENT_A_SMOKE_AUDIT.md`；smoke BLOCKED |
| 3R | 新机制冻结、实现与因果测试、有限 calibration/validation、安全检查、新 smoke、独立审计 | NOT_STARTED；不继承阶段 3 的机制 PASS 作为重构验收 |
| 4 | 实验 A 固定预算 formal 与报告；只接纳阶段 3R 当前签名 PASS | BLOCKED，原 formal 未启动 |
| 5 | 实验 A 结束审计 `EXPERIMENT_A_FINAL_AUDIT.md` | NOT_APPLICABLE；必须真实完成 A 的阶段链才能给 PASS |
| 6 | 实验 B 完整实现、机制测试、独立 calibration/validation 与 smoke | BLOCKED；要求阶段 5 审计 PASS |
| 7 | 实验 B 两种时间口径的固定预算 formal 与审计 | NOT_STARTED；要求阶段 6 PASS |
| 8 | V4 总报告和最终审计 | BLOCKED；不得把两轨部分完成称为 V4 完成 |

### 15.1 阶段 3R 必须逐项完成

1. 在获准实施后，冻结 R4 方案哈希、来源差异、新算法可见输入、pending 状态、阈值候选定义和发布/生效规则；复核 SF11/V2/V3 与 R3 失败证据未变。
2. 实现第 4.5 节机制，通过第 16 节新增的前缀因果、延迟发布、错误分支与失锁测试；Paper-native 整数估计与无 Hamming 身份回归必须通过。
3. 冻结该轮候选表、样本预算和独立 seed ledger，仅以机制指标 calibration；每轮完整保存通过和失败产物。
4. 通过 calibration 后，以唯一冻结候选运行新 validation；两个 Case 均通过 2%/1%/200 门，并通过独立低 SNR 安全检查。
5. 运行新 smoke，通过调用链、配对、恢复、产物和因果验收。
6. 生成独立版本目录中的 `STAGE_03R_EXPERIMENT_A_REDESIGN_AUDIT.md`，绑定同一套代码、参数、种子及方案签名，全部满足才写 PASS 并准入阶段 4。

任一子门失败均不得跳到后续步骤；最多两轮耗尽后审计 FAIL，仍为 `DO_NOT_ADMIT_STAGE_4`。不运行 A smoke/formal，不生成声称 A 完成的结束审计，不进入 B。旧阶段 3 永远保留 FAIL；新阶段 3R 的 PASS 只说明新机制已准入。

### 15.2 实验 B 的依赖与自身验收

```text
EXPERIMENT_B_ENTRY_RULE = REQUIRE_A_PASS
ALLOW_AFTER_A_FAILED_CLOSEOUT = NO
```

不采用 A3 解耦路线。实验 A 的失败报告不能替代阶段 5 PASS；将来如需解除依赖，须另有用户明确选择和方案修订，本版不预授权。

阶段 6 仍须完成 Track B 的 12×4×16 信息矩阵、12×7×16 编码矩阵、768 bit/112 symbols、硬/ML 无噪声零错误，Huang/Stage55/Paper-adapted 三接收机，Hamming 块后生效、rolling-8、无真值接口，以及 controlled-time/native-overhead 独立调度、信道/相位和完整 pass 配对测试。既有 B 源文件存在不等于 B 已获准推进。

B 的 calibration/validation 继续继承 R3 独立预算（最多 3 轮，每轮最多 32 候选），不得占用或混用 A 的 3R 新预算。-21 dB validation 每个 mode 固定 20 个独立完整 AWGN pass，两个 mode×两个仰角区分别达到原 2%/1%/200 门；低 SNR 安全为 -30、-25 dB 每 mode 各 2 pass。通过后每个 mode×channel 使用新种子各 1 个完整 pass 做 smoke，再独立审计准入 B formal。

## 16. 测试门

1. 4096/4096 no-LDRO 标签往返零错误；
2. 9 个独立 chirp golden vectors 命中预期 FFT bin；
3. 独立 12-bit Gray/bit-order/interleaver golden vectors；
4. 非 4 倍数标签 1、2、3、1023、4095 正确；
5. 第 11、12 bit 参与标签、LLR 和译码；
6. 16 个 Hamming 码字逐项验证；
7. `12×4×16`、`12×7×16`、768 bit、112 symbols；
8. no-noise/no-Doppler 下 A 的 SER 为 0；B 的 SER/hard BER/ML BER/PER 全 0；A 不生成伪 bit 指标；
9. Paper-native 不调用 sub-bin estimator；
10. No-Doppler、Paper-Point、Midamble-Point 诊断链逐层通过；
11. controlled-time 只对齐公共 D 时刻，不断言整帧 raw array 相同；
12. native-overhead 的 ToA/goodput/energy proxy 使用自然帧时长；
13. Stage55/Huang Midamble 接纳为 0，Paper VP 接纳为 0；
14. 完整 Hamming 块前无因果回写；
15. rolling history≤8，时间严格递增；
16. 包间 `angle(h_k)` 跳变不进入跨帧 Doppler phase state；
17. checkpoint 恢复与连续运行逐项一致；
18. 种子域全枚举无交集；
19. cluster bootstrap 只按 packet/pass 重采样；
20. MATLAB Code Analyzer 为 0；
21. V2/V3/SF11 未被修改；
22. `auditV4` 全部通过。

阶段 3R 新增强制测试，不能用旧确定性机制 PASS 替代：

23. 相同接收样本前缀、不同未来 D/噪声：截至前缀时刻的硬判决、pending、接纳事件、状态及 CFO/rate 输出完全一致；
24. 单个候选不更新 tracker；两个不同时刻候选只有确认完成后才能同时提交，历史 D 判决不变；
25. 人为增加发布处理延迟时首次生效时隙同步后移；不能按测量中心时间回填更新；
26. 高峰/低熵但与可见分支约束冲突的错误标签被拒绝；出现歧义不强选分支，失锁后本包零新增 VP；
27. 窗口过期、连续 3 个 D 无接纳、pending 清空、history 有界以及包间重置均符合定义；
28. 双测量提交计两个唯一 VP；重复拟合不重计，评分使用提交时标签，分母包含 pending/丢弃/失锁 D；零接纳必须 FAIL；
29. 对接收机不可区分但实际标签错误的自洽分支构造反例，离线评分必须计为误接纳，不声称质量特征能保证正确；
30. Stage55 不访问 Hamming、块置信、相位对 CFO、M、真值、未来输入；Paper-native 的整数 estimator 与 terminal M 隔离不受重构影响；
31. 原三轮失败产物哈希未变，新旧域无交集；两轮/32 候选预算在启动与恢复入口均强制检查；
32. 断点恢复重现 pending/LOCKED/LOST、接纳账本及发布时间；不同算法/参数/种子/方案签名的 checkpoint 必须拒绝混用。

这些是后续实施的验收要求，本次文档修订未运行它们。新机制审计的 PASS 不能预先写入旧 `auditV4` 结果。

## 17. 正式报告措辞

Track A：

> 在 SF12、125 kHz、120-bit 元数据、Case1/Case2、no-LDRO 的论文条件适配环境中，实现 Farhat et al. Paper-native Midamble-Point，并检查 SER 和 Doppler tracking 趋势。由于论文未公开全部底层 PHY/编码细节，本轨道只作为 paper-condition anchor，不声称逐点复现 Fig.10/Fig.11。

Track B：

> 将 Paper Midamble-Point 适配到与 Stage55 相同的 SF12 no-LDRO、CR3、768-bit、112-data-symbol PHY，在相同 Payload、预注册随机信道/噪声/Doppler 生成规则下进行配对比较，并分别报告 controlled-time 算法能力和 native-overhead 系统代价。

## 18. 实现准入结论

当前已有来源/接口冻结、公共 no-LDRO PHY 和 Track A 确定性机制 PASS 证据，不能继续描述为“仅有 V3 LDRO 骨架”。但原 Stage55 符号质量机制已在三轮预算内失败，阻塞仍然存在，不能宣称 BLOCKER 清零。

本版选择以阶段 3R 重构 Track A，固定物理条件、Paper-native 身份及 2%/1%/200 门；原失败证据完整保留。两轮新预算不是已经执行的实验，pending/分支保护也不是已证明能达标的方法。实验 A smoke/formal 和实验 B 当前均未获准启动。

报告必须同时写出：原阶段 3 FAIL、阶段 3R 的实际状态、A formal 是否完成、A 结束审计状态以及 B 是否准入。只有对应新签名证据通过才能推进，不能把文档修改等同于运行验收。

## 19. 修订决策与授权记录

```text
REVISED_PLAN_ID = V4-noLDRO-plan-R4-track-a-stage3r
REVISION_DATE = 2026-09-07
DECISION_A = A2_REDESIGN_TRACK_A_STAGE55
RATIONALE_A = 保留原质量门，以新的因果启动和失锁保护机制检验当前结构性问题；不追加旧机制第四轮调参。
DECISION_B = B4_COMBINATION(B1_CAUSAL_TWO_MEASUREMENT_BOOTSTRAP, B3_FAIL_CLOSED_BRANCH_LOCK)
ALLOWED_OBSERVATIONS = 本包已到达Point观测；当前及过去D的IQ/FFT、硬标签、单符号质量、时间戳及自身预测
FORBIDDEN_OBSERVATIONS = payload truth; true CFO/rate; orbit truth; true channel coefficient; future samples; Hamming; Midamble observations for Stage55
PENDING_RELEASE_RULE = 第4.5节双测量通过唯一一致分支检查后，以同一事务提交原始候选
FIRST_EFFECTIVE_TIME_RULE = 发布完成后首个尚未开始处理的物理时隙；不回写、不跨包
DECISION_C = 最多2轮，每轮最多32组；每Case在-21dB使用2000个全新packet，-30/-25dB各500个安全packet
DECISION_D = KEEP_ALL_AS_SUPERSEDED_FAILURE_EVIDENCE
EXPERIMENT_B_ENTRY_RULE = REQUIRE_A_PASS
APPROVED_BY = 用户（本会话先选择A2并保持原质量门，随后明确要求“修改计划并执行”）
APPROVAL_SCOPE = R4_STAGE3R_PLAN_FINALIZATION_AND_IMPLEMENTATION
IMPLEMENTATION_AUTHORIZATION = GRANTED_BY_USER_2026-09-07
ADDITIONAL_CONSTRAINTS = 不覆盖或拼接旧结果；不放宽门；不追加预算；不使用真值或未来信息；不提前进入B
```

B 的具体组合、C 的默认有限预算及 E 的继续依赖在本方案中明确列为修订设计，没有把用户未逐项表态的内容伪写成独立人工批准。后续若用户要求按本方案实施，应先冻结本方案和修订单各自 SHA-256 到新的版本化 manifest，再执行代码或实验变更，并严格通过阶段 3R；本次不修改旧 manifest、审计或修订单中的历史批准栏。
