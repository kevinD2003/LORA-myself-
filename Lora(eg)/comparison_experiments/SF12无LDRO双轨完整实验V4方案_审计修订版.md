# SF12 无 LDRO 双轨完整实验 V4 方案（审计修订版 R3：按指定 SF11 project 对齐）

修订日期：2026-09-07；方案标识：`V4-noLDRO-plan-R3-project-aligned`。

本版以用户指定的 `D:\codex\Lora(eg)\project` 为标准。源码证据、SHA-256 与逐项对应关系见同目录 `V4_SF11_PROJECT_ALIGNMENT.md`。本文件原位修订，不另存旧方案副本。

本文件是对用户提供的 V4 方案的完整修订稿，供后续分阶段实现使用。本次不生成初稿归档。当前只完成文档修订，未修改算法、未运行标定或仿真；不能据此宣称代码测试通过或已有 formal 准入资格。

## 1. 研究目标与边界

保留两个独立轨道，共用 SF12 no-LDRO 数据符号定义，但不要求轨道几何、信道和编码链完全相同。

| 项目 | Track A | Track B |
|---|---|---|
| 研究目标 | 论文条件下的 Point / Midamble-Point 趋势锚定 | SF11 主项目流程的 SF12 no-LDRO 移植及公平比较 |
| 主要信道 | packet-flat Rician K=10 dB＋AWGN＋Doppler | AWGN＋连续 Doppler |
| 补充信道 | 无 Doppler 的同信道诊断 | packet-flat Rician K=10 dB＋AWGN＋连续 Doppler |
| 数据链 | 23 个独立均匀标签，无完整 CR1 编码 | 16 块、12 行 Hamming(7,4)、768 信息 bit、112 数据符号 |
| 初始估计 | 最后一个完整同步 downchirp 的整数 FFT-bin Point | 共同 8-upchirp bootstrap |
| Paper 身份 | Paper-native estimator，paper-condition adapter | Paper-adapted |
| Stage55 身份 | 符号质量门适配，不使用 Hamming 软迭代 | 完整 CR3 块置信与因果 VP 跟踪移植 |
| 跨包状态 | 每个 packet 重置 | 仅可见、因果的接收机估计 history |
| 独立统计单位 | paired packet | paired complete pass |
| 主要结论 | SER 与跟踪趋势 | 编码错误率及系统有效吞吐 |

Track B 将 AWGN＋连续 Doppler 恢复为主信道，落实可见对话中的 SF11 主信道对齐方向。Rician 是独立补充，必须单独标注、单独统计，不汇入 AWGN 主曲线。

本研究仍不是“只改变 SF”的单变量实验：BW/Fs 从 250 kHz 改为 125 kHz，信息量从 704 bit 改为 768 bit，符号时间从 8.192 ms 改为 32.768 ms，Paper 导频密度也变化。不得把所有性能变化归因于 SF。

不声称 Track A 逐点复现论文 Fig.10/Fig.11；不设置“Stage55 必须优于 Paper”的校准、停止或验收条件。

## 2. 版本、来源和实施范围

计划工程目录：

```text
D:\codex\Lora(eg)\comparison_experiments\stage55_sf12_sf11_flow_v4_noldro
```

V2、V3 和 SF11 历史工程及结果保持只读。V4 不加载其 checkpoint 或用其正式曲线选参数。代码、参数、种子、checkpoint、结果目录与签名独立。

用户指定的标准根目录为 `D:\codex\Lora(eg)\project`。本次读取 project/confidence_symbol_reproduction/README.md 和规范目录 CANONICAL_PROJECT.md，确认 Stage55 算法标准为：

```text
D:\codex\Lora(eg)\project\orbit_doppler\satellite_fig3_rolling8
```

采用 satelliteFig3SenLoRaVirtualPilotDecode 默认 UseQualityAwareVirtualPilots=true 的路径，Huang 采用 satelliteFig3HuangPrecCpMatchedDecode。project 下早期四前导 demo、简化交织 demo，以及显式关闭质量模式的 legacy 运行脚本，不作为 V4 主接收机标准。

原 R2 的 senlora_orbit_doppler 路径本次检查不存在，撤销其标准来源身份；V3 和 V4 中 upstream_sf11 文件只作快照，不能代替指定 project 当前文件。实测源码哈希见对应文档，实施前重新核对。

本次为静态源码核对，未执行 SF11 测试，不宣称新一次回归已通过。阶段 0 仍须补齐实际移植依赖闭包、论文 PDF 哈希/页码与 V4 source_manifest；不得引用旧正式曲线作为测试门。

论文身份冻结为 Farhat et al.，DOI `10.1109/OJCOMS.2025.3598602` 的录用/发表版本；记录本地 PDF 哈希与对应页码。其 Table 2 的 SF12 Midamble-Point 间隔为 3，仿真含 Rician K=10 dB，Fig.8 使用纯 upchirp Midamble。早期 arXiv v1 的参数不同，不得混用。[作者录用稿](https://www.researchgate.net/publication/394476640_Doppler_Estimation_and_Compensation_Techniques_in_LoRa_Direct-to-Satellite_Communications)

Track A 的 23 标签、packet-flat 重采样、Fs=B 和末尾导频属于本适配器的明确实现选择；120 bit 与 CR1 仅为场景元数据。不从这些元数据推导未实现的 CRC、包头、白化或信息位 goodput。

## 3. 公共 SF12 no-LDRO PHY 与编码方向

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
grayBitOrder = LSB-first
fftBinDirection = positive-tone-to-positive-bin
```

数据标签为整数 0–4095。MATLAB 数组位置为标签＋1。硬判决取最大 FFT 能量；并列最大时取最小标签。所有 4096 个 bin 都参与软度量，不做 spacing-4 聚合。

设物理标签 s，Gray 标签为 `g=s XOR floor(s/2)`。编码交织得到的是 g，再 Gray decode 得到 s；接收时由每个候选 s 的 g 构造 12 位 bit 表，不能直接对 s 的二进制位求 Gray LLR。

Track B 每块信息矩阵为 12×4，每行信息位记为 d1,d2,d3,d4，码字固定为：

```text
[d1 d2 d3 d4 p1 p2 p3]
p1 = d1 XOR d2 XOR d4
p2 = d1 XOR d3 XOR d4
p3 = d2 XOR d3 XOR d4
```

在单块中，列 c=1,…,7，Gray 位 b=1,…,12（b=1 是 LSB）：

```text
row = mod(b+c-2,12)+1
grayBit(b,c) = codedBit(row,c)
grayLabel(c) = sum_b grayBit(b,c)*2^(b-1)
```

解交织使用同一 row 映射的逆赋值。信息序列按指定源的 MATLAB `dataBits(:)` 顺序展平：12 行 row 最快，接着 d1…d4，最后 block。显式外部序列格式如需不同，必须通过固定置换转换并由人工向量验证；编码与 BER 两侧使用同一冻结顺序。

维度固定：16×12×4=768 信息 bit，16×12×7=1344 编码 bit，16×7=112 数据符号。每数据符号是 12 位编码标签，平均 768/112≈6.857 信息 bit，不是 12 个独立信息 bit。

冻结源码可保留历史 LDRO 内容以供只读追溯；活动调用链不得存在有效的 10-bit/1024/spacing-4 映射。源码扫描须区分历史快照、测试反例和实际调用代码。

## 4. 软概率、LLR 和最终译码（对齐 project）

Track B 的数学基准为 satelliteFig3SenLoRaConfidence。撤销 R2 默认引入的最大峰±2 bin 排除噪声估计和 LLR [-50,50] 截断；它们不是指定 SF11 源默认规则。数值修复必须先有独立失败证据，再登记新算法版本。

令 Z=FFT(dechirped)/sqrt(M)，本帧已补偿 8 个前导的频域能量排除物理 bin 0 后求均值：
```text
Nhat = max(mean(abs(Zpreamble(:,2:end)).^2,'all'), eps)
logit(s) = abs(Z(s))^2/Nhat
logP = logit−logsumexp(logit)
LLR(b) = logsumexp(logP: GrayBit(s,b)=1)
       −logsumexp(logP: GrayBit(s,b)=0)
```
数组位置 1 对应 bin 0，噪声估计和信号必须使用相同 FFT 归一化。softMetric 标注 fft-energy-exponential-surrogate，不称为精确信道后验；非有限值失败并禁止 VP 更新，不读取 truth 修补。Track A 无 Hamming 链，不使用本节块软译码。

硬 Hamming 取最小 Hamming 距离。最终 ML-bit-metric 最大化 sum((2*c−1).*LLR)，使用当前补偿后未做置信修正的 raw bit LLR。用于置信的候选码字另最大化 sum((2*c−1).*sign(LLR).*abs(LLR).^2)，记录最优/次优 margin。按 0–15 信息值枚举，平分时取最小值。

保留源置信修正：
```text
reliability = sqrt(max(margin,0)/7)
target = (2*confidenceCodeword−1).*max(abs(rawCodeLLR),reliability)
amended = (1−mix)*rawCodeLLR + mix*target
symbolConfidence = sum(abs(interleave(amended)).^2)
tauBlock = mean(symbolConfidence)+std(symbolConfidence,0)
tauGlobal = alpha*tauPrevious+(1−alpha)*tauBlock
```
首块 tauGlobal=tauBlock；每符号 margin 取参与该符号的行中最小值，以 tauGlobal 归一化。soft-hard agreement 比较平方置信评分重编码符号与当前 tracker 硬判决，不能改成最终 ML 信息位重编码。

alpha=0.8、mix=0.5、confidenceThresholdScale=1.0 作为源结构基准登记；改变需明确算法差异，不能混入纯维度适配。CFO 门和 margin ratio 等按 V4 独立标定。入口 UseEstimatedSnrGate=false，源配置中遗留的 -16 dB promotion 门与旧低 SNR 窗口不得误启用。

每轮从原始 IQ 重新补偿并形成 raw LLR，不把上轮 posterior 当独立信息累加。因果模式每轮 PreviousTauGlobal=NaN，避免上轮末块 EMA 回流首块；两轮稳定确认与全帧退出的风险见第 6.4 节。

## 5. Track A：23 标签论文条件锚点

### 5.1 轨道与帧起点

使用独立的圆轨道天顶过境模型：Re=6371e3 m，h=550e3 m，mu=3.986004418e14 m³/s²，c=299792458 m/s，fc=868e6 Hz，a=Re+h，omega=sqrt(mu/a³)。

```text
R(t) = sqrt(a^2+Re^2-2*a*Re*cos(omega*t))
fD(t) = -fc*a*Re*omega*sin(omega*t)/(c*R(t))
```

时间 0 对应天顶最近点。Case1 与 Case2 的**前导起点**分别固定为 -366 s、0 s；不能在不同方法间改用 payload 起点作为 Case 时间。此模型不加入 Track B 的 15°倾角与地球自转修正。

每个 packet 重新生成 23 个独立均匀物理标签 s∈{0,…,4095}、一个独立 Rician 系数和独立噪声。方法间使用相同 packetId 的标签和公共时刻样本。不同 packet 无接收机状态继承。

### 5.2 Paper-native

方法：`Paper-Midamble-Point-native-SF12-noLDRO`。

初始估计来自最后一个完整同步 downchirp，乘对应 upchirp 后取整数 FFT-bin peak。Midamble 使用纯 upchirp s=0，先施加当前补偿，再乘 downchirp，取残余整数 FFT-bin peak。

FFT 索引 q 的有符号频率为 q*Fs/M（q<M/2），否则为 (q-M)*Fs/M。残余估计累加到当前 CFO，而不是覆盖为 total CFO。初始及每次更新都使用已完整到达的训练 chirp；新 CFO 从该 chirp 结束后的样本开始生效。补偿 NCO 相位在更新处连续，更新改变后续相位斜率，不回写已判决数据。

不插值、不 zero-padding、不调用 Stage55 sub-bin search；不使用 payload 判决、轨道真值或未来数据。native 指该估计器机制，整个 packet adapter 仍不声称精确标准包或原图数值复现。

### 5.3 Track A 的 Stage55 适配

方法改为：`Stage55-VP-symbol-quality-SER-SF12-noLDRO-adapted`。

使用与 Paper-native 相同的 Point 初始化；初始 rate=0。保留因果硬标签 VP、最多 8 个已接纳测量的 history、历史衰减、peak 权重、Huber 拟合及单符号残余 CFO 融合。

本轨道没有 Hamming 码约束：禁止调用 7-symbol Hamming 软迭代、block margin 或 decoded-codeword confidence。每个完整数据符号独立产生 peak ratio、归一化谱熵、单符号残余拟合误差与预测 innovation。接纳条件是上述质量门全部满足，候选标签始终为补偿后的硬标签；阈值按第 12 节独立标定。

被接纳符号的 CFO 测量记录在该符号中心时刻，最早影响下一个物理时隙；若下一个时隙是 M 空槽，则只作时间预测，到下一个 D 才解调。至少两个不同时间的已接纳测量且 rate 可观测性门通过，才启用 rate；否则保持已得 CFO、rate=0。Track A 不使用相位对 CFO 分支，以免把未经独立定义的跨符号相位模型带入论文锚点。

23 个标签全部逐符号处理，因此不存在尾部不足 7 个的 Hamming 块，不添加填充、不偷偷编码。这是 Stage55 的符号级机制适配，不是 Track B 完整接收机；两轨 Stage55 结果不可互相替代。

### 5.4 诊断与指标

诊断方法为 `No-Doppler-Rician-AWGN-SF12-noLDRO` 和 `Paper-Point-native-SF12-noLDRO`。前者关闭 Doppler；后者仅用初始 Point 并全 payload 固定 CFO。

指标：SER、数据符号中心处补偿 CFO RMSE（Hz/bin）、VP 接纳率与误接纳率、Midamble 数、时长、runtime、deadline。禁止 CR1 BER/PER 和伪信息位 goodput。No-Doppler 不参与“同一 Doppler 实现”的断言。

Point 在高动态下的高 SER 是允许的性能结果。诊断通过依据是第 14 节的确定性机制测试，而非强制贴合论文 marker。

## 6. Track B：完整 CR3 接收机

三个主方法：

```text
Huang-PREC-static-CP-SF12-noLDRO
Stage55-VP-quality-CR3-SF12-noLDRO
Paper-Midamble-Point-SF12-CR3-noLDRO-adapted
```

三个方法接收同一定义的 8-upchirp 前导；controlled-time 中前导输入数组也必须逐样本相同。共享 bootstrap 数学设施和冻结参数，分支各自后续状态不共享。native-overhead 下相同设施应用于各方法自然时刻的前导，不声称输入数组相同。

Huang 保持选定 SF11 源版本的 static-CP 机制，不使用 M 或 VP。Paper-adapted 使用共同 bootstrap 初始 CFO，在 M 处用统一精细 residual estimator 作分段常数更新，不用 payload 判决或 VP；不新增 Stage55 的 payload-driven rate tracking。

Stage55 固定：最多 5 次块置信迭代；硬 LoRa 判决作为 VP 标签；完整 7 个**数据符号**到达后才允许软结果影响后续物理符号；M 不算作 Hamming 块中的数据符号。最终 ML 位译码不反向修改历史硬 SER 或 VP 标签。

保留默认 VP-quality 路径的历史衰减、peak/Huber 权重、CFO 融合、相位对双门与 rate 可观测性，按以下状态契约移植。

### 6.1 公共 bootstrap 与时间契约

satelliteFig3HuangPrecCpBootstrapEstimate 对每个 eta 候选分别旋转 8 个 upchirp，累加各 chirp FFT 功率后搜索全局峰，epsilonHatBins=signedIntegerBin−etaHat。禁止用 V3 逐前导局部 CFO 鲁棒斜率静默替换。源默认 eta 步长 0.1 bin 只作来源记录，V4 步长独立标定。

bootstrap.cfoBins 为 8 个相同 epsilonHatBins；phaseRad(k) 为第 k 个前导去除此 CFO 后的相干均值相位，作为源模型下该前导起点的接收机相位估计，不宣称是真实瞬时相位。另由卫星源 joint phase 函数返回 jointRateBinsPerSec，不覆盖共同 CFO。

跨帧聚合 CFO 观测值 epsilonHatBins 的时间标注为 frameStart+4T，不冒称真值瞬时 CFO。整个 8 前导到达后才能使用；首个数据符号相位桥接采用 phaseRad(8)+2*pi*epsilonHatBins，后续按物理时隙推进。

Huang 载荷 CFO 固定、rate=0；Paper-adapted 同 CFO/相位起点且 rate=0，仅 M 更新 CFO；Stage55 使用下节的可见 rate。共享 bootstrap 不是要求三种方法载荷期 rate 策略相同。

### 6.2 帧内与跨帧 history

撤销 R2 将本帧缓冲区定义为仅含 VP、空状态启动的规则：
- rollingPilotHistory：每次帧内 replay 由当前 8 个前导初始化 8 槽；VP 替换最旧槽；总长度≤8，包含未被替换的前导。
- preambleHistory：跨帧≤8 个完整前导的聚合 CFO/中心时间，不含 Payload 或 channel phase。
- vpRateEvidence：本帧所有已接纳 VP 的 raw single CFO/实际时间，用于斜率可观测性；容量≤112。它不是固定 8 槽 history，不能错误截成 8 项。

每帧重建 rollingPilotHistory 和相位对状态，只有 preambleHistory 跨帧传递；这些是三个职责不同的对象。

### 6.3 初始 rate 和质量模式

按 satelliteFig3CrossFrameRateUpdate：
- 孤立帧或首个可用帧：使用当前前导 jointRateBinsPerSec，经最大速率保护；撤销无条件 rate=0。
- 2 帧：按实际时间做线性 CFO 斜率；
- 3–8 帧：当前时间为中心的二次 CFO 拟合，历史衰减加两轮 Huber，取当前斜率；
- 超过 8 帧丢最早测量；不必等满 8 帧才拟合；
- 数值秩失败/非有限估计须报失败并拒绝更新，不用 truth 或未注册回退掩盖。
默认质量模式仅在 preambleHistory<8 且启用 VP rate update 时，允许可观测 VP 斜率在限制范围内替换先验；满 8 帧后保留跨帧先验，VP 继续更新 CFO 中心。不能按“2 VP 已接纳”直接释放 rate，也不增加 V3 的“至少两帧才能晋升 VP”门。

SF11 的 maxRateBinsPerSec=2、创新门等数值不能原样冻结到 SF12。先按 Hz、Hz/s、bin、bin/s 量纲建立候选，再独立标定；bootstrap 失败不得靠静默更换算法解决。

### 6.4 迭代与前缀因果性

第一轮只产生候选；后续 stable=当前 proposed AND 上轮 proposed AND 两轮置信重编码符号一致。候选集合 OR 保留，真正接纳仍经过 tracker 质量门。最终采用最后一次已执行 tracker，不能对最后新提议 mask 再额外重放。

源收敛退出条件为 iteration>=2 且 nextMask==mask，最多5轮；这个全帧退出本身需通过前缀因果测试。若未来数据改变退出轮数并影响过去状态，须作为显式因果修正处理：先展示反例，再采用固定轮数或前缀状态冻结并登记差异，不能删除失败测试或谎称源严格因果。

7个D完整后，其置信最早影响块后第一个物理时隙；M不计入块长也不提供Stage55观测。存储硬VP标签、判决时刻、可用时刻、应用时刻。误接纳必须按实际入 tracker 的标签计数，不用最后一轮重解码标签替换。

以相同前缀、任意不同未来D/块/帧测试：截止时刻的已发布判决、接纳、EMA、CFO/rate/history必须逐项相同。pending块结果和整包最终软译码的发布时间分别标注，不把包尾可见结果冒充早期输出。

### 6.5 相位对 CFO

源 tracker 以帧内连续 NCO 预测相位加 residual.phaseRad 构成测量相位；两端相位差除以2*pi*gap形成平均CFO，再用预测rate换算到终点，分别检查与预测相位平均值、raw single CFO的一致性。单符号和相位对按各自融合增益更新；不得分别对端点NCO取模后直接相减。

gap必须为实际物理间隔/T，包含M空槽，不能以D序号差替代。保留帧内连续相位或cycle counter；跨包清空相位对状态。对±pi跨界、大CFO、长gap和假相位对做独立测试。若需新增残差解缠算法，记录显式变更并重新验证，不预称与源等价。

### 6.6 Paper-adapted 残余估计

已知M采用 satelliteFig3PhaseRotationEstimate 的整数FFT峰获取加局部细化：对当前补偿后s=0的M先找有符号整数峰q，再搜索q±1 bin的细网格并用源三点功率插值。StepBins独立标定，B各模式/信道共享。禁止把VP的小残余窗口直接限制已知M的再获取。

局部峰在端点或估计非有限时记录failure、保持原CFO，不无限扩窗；此边界策略明确属于V4 adapted定义。只在M结束后累加残余更新相位斜率。A的Paper-native仍只做整数FFT-bin估计。

## 7. 完整帧调度与 Midamble 数量

所有时间区间采用左闭右开。完整符号中心为起点＋T/2，最后采样点为终点−1/Fs。所有调度先生成 sample-index event list，再计算物理时间，避免浮点累加错位。

### 7.1 Track A 调度

前导为 8 U＋2 个完整 downchirp＋0.25 downchirp，共 10.25T；最后一个完整 downchirp 是 Point 观测，0.25 部分计时但不作为估计器输入。省略同步字及真实 header/CRC，记录为简化 packet adapter。

保留本地论文适配器的末尾导频选择：在 D3、D6、D9、D12、D15、D18、D21 之后各插 M，并在 D23 后插一个 terminal M。共 8 M：

```text
8U + 2down + 0.25down + (DDD M)×7 + DD M_terminal
```

第 j 个 D（j=1,…,23）的起始偏移为 `[10.25+(j-1)+floor((j-1)/3)]*T`。前 7 个 M 的起始偏移为 `(10.25+4k-1)*T`，k=1,…,7；末尾 M 为 40.25T。总长 41.25T=1.351680 s。

terminal M 不得影响本包任何数据判决，也不得传给下一个独立 packet；仅保留已定义的发送开销与末尾估计诊断。它不计入数据 CFO RMSE。

Track A 的 Stage55 与 Point-only 在全部 M 时隙无观测，保持相同 D 时刻。其比较时长也为 41.25T；如另报 Point 原生帧 ToA，则为 33.25T=1.089536 s，必须标注仅为原生开销描述，不能把不同时间轴性能混作同一实验。No-Doppler 诊断使用公共 D 时刻。

### 7.2 Track B 调度

前导仅含共同 8 U，共 8T；这是项目简化帧定义。

Paper-adapted 在每满 3 个 D 后且仍有后续数据时插 M：

```text
8U + (DDD M)×37 + D
```

共 112 D、37 M、157 个完整物理符号，ToA=5.144576 s。没有头部 M，没有末尾 M。此规则为 R2 的 adapted 调度选择，与 Track A 保留 terminal M 的口径显式区分。

第 j 个 D 的起始偏移为 `[8+(j-1)+floor((j-1)/3)]*T`；第 k 个 M 为 `(8+4k-1)*T，k=1,…,37`。数据 D112 位于索引 156（从 0 开始）的时隙。

Stage55/Huang 原生帧为 8 U＋112 D=120T=3.932160 s。Paper 的 Midamble airtime 为 37T=1.212416 s；相对 120T 原生帧的新增时长为 37/120≈30.833%，M 占 Paper 全帧比例为 37/157≈23.567%。两个百分比均保留名称，不互相替换。

### 7.3 两种比较模式

controlled-time：所有方法使用 157T 公共帧时钟；Stage55/Huang 在 37 个 M 槽不发数据、不读样本、不更新测量，但物理时间、信道及预测相位推进。公共前导和 D 时刻的底层随机样本一一对应。禁止要求整帧 raw array 一样。

native-overhead：Paper 按 157T、Stage55/Huang 按 120T 连续发送，各自独立自然起点序列。此模式才用于主要系统 goodput、ToA 和发送能耗比较。采用共同源包序列和 passId，不要求相同包在相同绝对时间发送。

两模式分别保存参数身份、调度、结果与图例。37 M/157T 替换旧版 38 M/158T；不得加载旧调度的 checkpoint。

## 8. Track B 轨道、盲区、区域和跨帧状态

### 8.1 SF11 轨道公式

采用用户指定 project 中 satelliteFig3Trajectory 的轨道公式，参数为 Re=6371e3 m，h=550e3 m，g=9.8 m/s²，omegaE=7.292e-5 rad/s，inclination=15°，fc=868e6 Hz，c=3e8 m/s，最大仰角 thetaC=56°，中央时间 0 s。

```text
rs = Re+h
omegaS = sqrt(g*Re^2/rs^3)
omegaF = omegaS-omegaE*cos(inclination)
gammaC = acos((Re/rs)*cos(thetaC))-thetaC
cosGamma(t) = cos(gammaC)*cos(omegaF*t)
R(t) = sqrt(rs^2+Re^2-2*Re*rs*cosGamma(t))
vRad(t) = Re*rs*cos(gammaC)*omegaF*sin(omegaF*t)/R(t)
fCarrierD(t) = -fc*vRad(t)/c
elevation(t) = atan2(rs*cosGamma(t)-Re, rs*sqrt(1-cosGamma(t)^2))
```

反三角输入在数值误差范围内夹到 [-1,1]。g、c 的近似值保持该源版本定义，不默默替换为 Track A 的 mu、c。

完整 pass 为仰角从进入 10°到离开 10°，外边界±tOut；中央遮蔽为仰角>50°，内边界±tIn。边界用上述模型求根或其解析逆式，不能沿用 SF11 的帧序号。

按以上常数独立算术核对：tOut≈249.752037 s，tIn≈37.082433 s；30°分区的绝对时间约为110.157580 s。完整pass约499.504075 s。这些数值是公式核对值，调度仍从公式与采样索引计算，不用四舍五入后的秒数生成采样点。

### 8.2 连续发送与观测权限

每个方法从 -tOut 开始按本模式帧长 back-to-back 发送；`interFrameGapSec=0`。包含穿越盲区的发送时隙，这是 continuous-pass 饱和流量实验，不是 LoRaWAN 稀疏上报。pass 末尾放不下一个完整帧时不再发帧，剩余时间计入 pass 时间分母。

冻结三种 mask：

1. `physicalVisible(t)`：10°≤elevation(t)≤50°；
2. `receiverFrameAvailable`：整帧区间完全位于某一个可见时间瓣内；
3. `linkMetricEligible`：与 receiverFrameAvailable 相同。

完全在盲区、跨入/跨出盲区、跨外边界的帧均不给接收机任何前导或 payload 样本，不更新 bootstrap、VP 或 preambleHistory；记录 geometry erasure。选择整帧可见才接收，是本版明确的保守包接入规则，不宣称模拟了部分包抢救能力。

遇到任何不可用帧即清空 rollingPilotHistory、preambleHistory、vpRateEvidence、相位对历史、置信 EMA 和接收机 rate 状态；下一可用帧重新 bootstrap；Stage55 rate 回退到当前八前导相位拟合（第 6.3 节），Huang/Paper rate=0。生成器的 Doppler 相位仍按物理时间连续。不得以“只不计分”为由读取盲区前导，亦不得把生成器模型状态传给 receiver。

### 8.3 计分区域

全部可用帧构成 visible-all 主链路区域。补充分区按帧中心仰角：low-elevation 为 [10°,30°)，high-elevation 为 [30°,50°]。这是 R2 的预注册分区，不冒称旧工程已有相同高/低动态阈值。使用命名 low/high-elevation，随表同时报告实际 Doppler rate 范围。

不为分区边界重新移动帧；一个可用完整帧只归入一个区域，整包 bits/symbols 都计入该区域。区域分配由外层统计器完成，不送给接收机用于选择参数。正负时间瓣另加标签用于诊断，重采样仍按完整 pass。

## 9. 信道、噪声和相位

```text
r(t) = h_k*x(t)*exp(j*phiD(t)) + n(t)
```

Track B 主实验 h_k=1；Track A 及 Track B 补充实验使用独立每包 packet-flat Rician。Klinear=10，令 u,v 为独立标准正态：

```text
h_k = sqrt(Klinear/(Klinear+1))
    + sqrt(1/(2*(Klinear+1)))*(u+j*v)
```

因此 E|h|²=1。包间相位允许跳变，本版不模拟散射径时变 Doppler；共同 phiD 作用于该 flat channel，是建模范围，不代表完整卫星多径信道。

SNR 横轴固定为单位平均、衰落前信号功率与 125 kHz 带内复 AWGN 功率之比。所有发送 chirp 单位平均功率；不按每包衰落后的实测功率归一化噪声。MATLAB 加噪显式给 0 dBW 功率，禁止 `awgn(...,'measured')`。为公共随机数配对，生成一次可按事件索引访问的复噪声库；验证实际复噪声总方差及 I/Q 各一半。

本计划直接扫描 SNR，不需要 Eb/No 或 Es/No 转换。未来若增加转换，先核对 R2022a 支持的函数与适用口径，不直接套用后续 MATLAB 版本 API。

仿真器保存 noise variance 真值用于外层核验；主接收机使用第 4 节的前导噪声估计，不读取 true h、true CFO、true rate 或噪声样本 realization。公共协议参数与训练符号可见，轨道时间函数不可见；receiver 时间使用当前 pass 的经过时间，绝对轨道 epoch 留在外层。

Track A 保留第5节载波Doppler。Track B 对齐 project/orbit_doppler/satellite_fig3_rolling8/generateContinuousSatelliteFrame.m 的 full-RF 近似：
```text
fBB[n] = B*(mod(n+s,M)/M−0.5)
fD[n] = −(fc+fBB[n])*vRad(t[n])/c
phiD[n+1] = phiD[n]+pi/Fs*(fD[n]+fD[n+1])
```
这是源频率积分模型，不是包含传播延迟/重采样的完整宽带信道。外层CFO误差对齐数据中心采样的full-RF频率；区域/轨道rate诊断使用载波量，字段分别命名，不能混用truth。

controlled-time使用Paper的U/D/M公共参考事件序列生成共享full-RF phase；Stage55/Huang的M空槽不发射、无观测，但推进同一参考phase，以保留后续公共U/D样本相同。空槽reference fBB是受控实验配对约定，不算实际发射能耗。native-overhead按每种方法实际chirp序列独立积分，不声称不同时间轴的phase逐样本一致。无发送间隔仅推进载波相位，重新发射按边界采样规则桥接。

phiD跨数据、M、空槽、包和盲区按这些规则连续，不能以fD(t)*t代替积分。生成器 state 与 receiver NCO state 必须分类型保存。每帧 receiver 用本帧前导重新建立相位参考；跨帧只继承允许的 CFO/rate history，禁止继承含 angle(h_k) 的原始复相位。

## 10. 随机账本和配对

种子域为 `mechanism / calibration / validation_vN / smoke / formal / bootstrap`，另有 `track / channel / comparisonMode / SNR / replicateId`。每域采用不同 root seed 与独立 substream；账本记录生成器、精度、版本和完整键，不仅存一个整数种子。

Track A 的 replicateId 是 packetId。Track B 是 passId；pass 之间独立生成 payload 与噪声/Rician，所有接收机状态在 pass 开始重置。几何为固定模型，统计推断只针对这个几何下的随机重复过境，不推广到任意卫星轨道总体。

Track B 源数据为可延长的独立均匀 768-bit 包序列 `payload(passId, packetId)`。同一包索引三方法取相同比特；较短方法多发送的包自然取后续索引，没有重发、无 ACK，不重复同一比特包模拟“更多送达”。

controlled-time 公共 U/D 的 AWGN 键为 `(passId, packetId, eventType, dataOrPreambleIndex, sampleIndex)`，不含 methodId；M 使用独立 component，不能因为多生成 M 消耗随机流而错移后续 D 噪声。Rician 按 packetId 共享。

native-overhead 使用相同 packetId/component 的公共随机数耦合，但其绝对发送时刻不同；Paper 的 M 噪声独立。每包 h 按 packetId 共享为统计耦合，并非一条真实连续 fading path。额外包继续取后续键，不能把它们丢掉以凑等包数。

三个方法的每个 pass 记录必须一起重采样，禁止各自独立抽 pass 破坏配对。AWGN 和 Rician、controlled/native 之间不合并统计；比较模式和信道采用独立种子域。源数据、noise、h、bootstrap 重采样流彼此独立。

checkpoint 保存完整 pass 统计和状态时点、seed ledger、事件游标与所有哈希。允许内部帧级恢复文件，但正式计数只接受完整 pass；恢复必须拒绝版本/参数/调度不匹配，已完成 pass 不能重复累计。

## 11. 指标、分母和统计方案

### 11.1 可比较的估计量

Track A：每包 SER=错误 D 数/23；主要配对差为 Stage55-symbol-quality minus Paper-native。Point 及 No-Doppler 是诊断，不根据它们的排序修改方案。

Track B：每个方法、每个 pass、每个 visible 区域，分别计算 SER=错误数据符号/数据符号总数，hard BER 与 ML BER=对应信息位错误/768×可用包数，PER-hard 与 PER-ML=至少一个对应信息位错误的包/可用包数。主要 PER 指 PER-ML；两者都报告。truth 只存在于外层计分器，接收机不能读取它来估计成功。

主要系统 goodput（仅 native-overhead）：

```text
goodput(pass,method) = 768*完全正确ML信息包数 / (2*tOut)
```

分母为完整 pass 时间，包含盲区和末尾不足帧的剩余时间；geometry erasure 的包交付为 0。另报全发送包 PER-system（geometry erasure 视为失败）、geometry erasure 比例、发送包数和可用包数。这些不混入 visible 链路 BER 分母。

controlled-time 的 goodput 如保留，只能标为 controlled-slot goodput，使用公共 pass 时间，不解释为原生系统效率。

跨 pass 的主要点估计为逐 pass 指标的等权平均；差值先在同一 pass 内求，再平均。总体错误数/总样本数可作次要汇总，但不替换主要估计量。分区没有可用帧时视为调度规格失败，formal 前即必须发现，不能到统计时随意丢 pass。

energy proxy=`unitTxPower*实际发送chirp airtime`。controlled 模式的空槽不算发射 airtime，但算经过时间；native 所有实际发射帧（含 geometry erasure）都算 airtime。未建射频功率、接收耗电模型前，不称为实测焦耳或电池寿命。

### 11.2 固定样本量，取消 precision stopping

本版选择固定预算，取代原方案的最小/最大样本间反复检查 CI：

| 轨道与结果组 | formal 样本量 | checkpoint |
|---|---:|---|
| A 每个 Case×SNR | 固定 20000 paired packets | 每 250 packets |
| B AWGN 每个 mode×SNR | 固定 50 paired complete passes | 每个完整 pass |
| B Rician 补充每个 mode×SNR | 固定 50 paired complete passes | 每个完整 pass |

SNR 均为 -30:1:-21 dB。上述预算是预注册的成本/精度折中，不承诺必然达到全部精度目标。formal 中不因 CI 宽度、错误数、误接纳率或方法排序提前结束，也不在看完结果后补跑到显著。资源中断可从同一配置恢复至固定预算；主动缩减只能标为 incomplete，不能伪装为预注册 formal 完成。

### 11.3 CI、退化样本与结论强度

完成固定样本量后，按 paired packet（A）或 paired pass（B）做 10000 次联合非参数 bootstrap，取差值分布的 2.5%/97.5% 分位数，报告**点态、近似 95% percentile CI**。冻结分位数插值算法及 bootstrap seed。B 不能把帧/符号/bit 当独立样本重采样。

CI 不作“整个 SNR 曲线及所有指标同时覆盖95%”解释；不预注册全局显著性检验，不根据单个偶然显著点宣称普遍胜出。固定预算消除了本方案原有的可选停止环节，但普通 bootstrap 的有限样本近似误差仍须如实标注。[时间一致推断的背景](https://arxiv.org/abs/1810.08240)

零错误不再是提前停止出口。若某方法某区域全部 N 个独立 pass 都零错，报告 observed=0、原始分母和“发生任意该类错误的 pass 概率”的单侧95%上界：

```text
qUpper = 1 - 0.05^(1/N)
```

该式针对 N 个独立 pass 的零事件，不针对 pass 内数百万个 bit。因为 pass 错误率∈[0,1]且不超过其错误事件指示量，qUpper 也是平均 pass 错误率的保守单侧上界。N=50 时约为5.82%，不得据 observed=0 宣称真实 BER=0。

若配对差的所有独立单位值相同，bootstrap 的零宽区间不得用于“精度达标”或确定性相等结论。报告 `degenerate-bootstrap`，并对独立、有界差值 d∈[a,b] 使用保守 Hoeffding 区间作为精度判断：

```text
mean(d) ± (b-a)*sqrt(log(2/0.05)/(2*N))
```

区间裁剪到 [a,b]；SER/BER/PER 差值使用 [-1,1]。goodput 差值支持界限由确定性调度的各方法最多可交付包数除以同一个 pass 时间推导，不能用观测最小/最大值缩窄支持区间。此退化保护适用于 A 的 paired packet 和 B 的 paired pass。

最终精度标签：A ΔSER half-width≤0.01；B ΔSER≤0.02、Δhard-BER≤0.01、ΔML-BER≤0.01、ΔPER-ML≤0.05；native Δgoodput≤10 bit/s。未满足的指标标 `precision-inconclusive`，保留数值和区间，不追加样本。CI 跨零与精度不足是不同标签，不应混为“实验失败”。

## 12. 标定、独立验证和 smoke

### 12.1 标定前冻结

正式实现前列出 receiver 参数名、单位、所属机制、候选范围、候选顺序、默认禁用回退与来源，存入 `calibration_protocol.json`。候选范围只根据公开物理范围及独立机制测量确定，禁止从 V2/V3 formal 曲线、V4 formal 或论文 marker 倒推。

Track A symbol-quality、Track B 完整 Stage55、B 公共精细 CFO 参数分别冻结。B 在 AWGN 上标定并冻结后，Rician 补充实验直接使用相同接收机参数，不为补充结果另行调参。controlled/native 的 receiver 参数相同，唯一差别是实际调度与由此产生的状态观测；各自统计单位仍独立。

结构参数如 history 长度8、最大迭代5、标签来源和因果生效时刻不作为调参开关。score、noise estimator、FFT 归一化与 llrClip（本版 none）均属于代码签名的一部分。

### 12.2 有限标定预算与准则

每轮最多32个预声明候选参数组，最多3轮。初轮使用小规模机制样本验证输入和时间轴后，才运行连续短窗口；B 窗口每段至少16个连续可用帧、覆盖两个可见瓣及高/低仰角，不能将有跨帧 history 的参数仅在孤立 packet 上标定。

候选只按 CFO RMSE、VP false-accept、接纳覆盖、rate 可观测性与 half-bin exceedance 排序。对每个候选按顺序：先满足质量门，再最大化覆盖率，最后最小化 CFO RMSE；仍并列时按预先记录的候选序号选最小者。禁止以 SER/BER 或 Stage55−Paper 排序选参数。

质量定义：false-accept=已接纳且硬标签错误的 VP 数/全部已接纳 VP；coverage=接纳 VP 数/全部可产生 VP 的可用 D 数。没有接纳时 false-accept 为 undefined，不能作为0通过。half-bin exceedance 指数据符号中心预测 CFO 误差绝对值≥0.5 bin；它不等价于持续整数分支锁错或真实相位 cycle slip。若需后者，另冻结持续时间和整数分支判据；本版仅使用该超界事件，不按正负选参数。误接纳以实际用于 tracker 更新的硬标签为准，不以最终一轮标签替代。

工程可用门（不是统计最优保证）：独立 validation 在 -21 dB 的 A 两个 Case、B 两个 mode×两个仰角区分别达到 false-accept≤2%、coverage≥1%、接纳总数≥200。B validation 为每 mode 固定20个独立完整 AWGN pass；A 每 Case 固定2000个独立 packet。冻结后另在 -30、-25 dB 各运行 A 每Case500 packet、B 每mode2 pass，只检查数值/因果安全并报告性能；低 SNR 可自然低覆盖，不能因追求1%而放松门。

这些阈值是 R2 预注册工程门，2%以观察比例计算，同时提供 packet/pass 聚类不确定性；不表述为“真实误接纳率已被95%证明低于2%”。若门失败，记录失败候选，下一轮建立新参数版本及全新 validation 域；达到3轮仍失败，停止在机制开发阶段并报告不可行，不自动放宽门或把零VP降级结果冒充完整 Stage55。

Paper-native 不调 sub-bin 参数，不适用 VP 覆盖门；只通过确定性 CFO/因果机制门。Huang 与 Paper-adapted 同样不能因为相对性能差而改算法。

### 12.3 smoke 与冻结变化

validation 通过后，smoke 使用新种子：A 两个Case各16 packet，B 每个 mode×channel 各1个完整 pass。smoke 检查调用链、配对、维度、状态、checkpoint 与产物，记录误接纳等诊断但不据方法排序调参。

NaN、truth leakage、时间错位、重复计数等确定性缺陷必须修复；修复接收机或指标算法即生成新 codeHash，并重新做受影响验证。smoke 中随机质量波动不能临时改变已冻结的 calibration 门。进入 formal 后如发现核心缺陷，作废受影响结果并注册新版本，禁止修代码后把不同签名结果拼接。

## 13. Runtime 与 deadline

runtime 只计接收机：bootstrap、CFO/NCO 更新、FFT、置信迭代、最终译码及 history 管理；不含信道生成、truth 计分、画图和磁盘 I/O。分别报告模块耗时、总耗时、均值、p95、最大值，并固定 MATLAB版本、CPU、线程/worker数、是否预热。

逻辑因果性按事件时间验证，不以桌面计时替代。A 的单符号更新、Paper 的 M 更新、B 的块置信更新，实时诊断预算统一为从所需最后一个样本到达起至下一个物理符号结束的 T=32.768 ms（允许缓冲下一符号）；8U bootstrap 使用相同下一符号预算。最终译码另外报告相对 frame end 的完成延迟。

离线 formal 使用逻辑及时的因果状态，runtime 不改变噪声/调度；若实测更新超过预算，则标明 realtime-deadline-not-met，不宣称已经实现实时系统。若未来模拟实际计算延迟导致的丢更新，必须另立实验版本，不能与本版曲线混合。

## 14. 独立验证与准入门

### 14.1 PHY 与编码

1. 4096个标签全枚举无噪声往返正确；标签1、2、3、1023、4095不受除4/倍4限制。
2. 独立数学向量 s={0,1,2,3,1023,1024,2047,4094,4095}，n=0,…,M−1：`x_s[n]=exp(j*2*pi*(n²/(2M)-n/2+s*n/M))`。用独立 conj(x0) dechirp 后最大 FFT 索引应为 s。
3. 独立手工 Gray/bit-order/交织矩阵；第11、12位变化必须改变预期物理标签并由LLR恢复。期望值不得调用 V4 TX 生成。
4. 16个Hamming码字、12×4×16信息量、12×7×16编码量、112符号验证；无噪声hard/ML信息错误为0。
5. 软度量需验证 LLR 符号、logsumexp数值、并列规则与16码字枚举最优性；不得只以硬判决往返作为软译码正确性证明。

### 14.2 CFO、因果和盲区

6. 无噪声常数 CFO：正/负整数 bin、±0.25 bin、±10kHz；Point 误差在非半bin并列时≤0.5 bin＋数值容差；检查频率符号方向与 residual 累加。
7. 用已知阶梯 CFO 的完整 M 事件验证补偿只从训练事件结束后生效，Point-only 全payload固定；terminal M 不改变之前数据。
8. B 7个D块前不生效，M不计入块长度；A没有Hamming调用。改变任何未来数据、未来块或未来帧，过去输出和状态逐项不变。
9. rollingPilotHistory 与 preambleHistory 分别≤8；帧内前者初始化为8前导，vpRateEvidence为本帧全部已接纳VP且≤112；物理测量时间递增。跨帧只有前导CFO history，相位对不跨Rician包。增加1/2/3/8/9帧的rate来源测试及第8帧停止VP覆盖rate的测试。
10. 给盲区/跨界帧替换任意样本或真值，receiver输出和下一可用帧初始状态不变；丢观测后的重置明确可测试。

### 14.3 随机、统计和工程

11. A完整调度41.25T/8M，B controlled157T/37M，B native120T与157T；校验所有D/M时刻及无重叠、无非法头/尾M。
12. controlled公共U/D样本哈希一致；M不推动后续公共noise键。native保持同源包序列、自然时刻和额外包，不断言raw一致。
13. 独立大样本信道单位功率、复AWGN方差/IQ对称核验：固定100000个独立样本，样本均值/方差相对目标偏差≤2%；样本独立性按生成器键另查。禁用衰落后measured加噪。
14. paired bootstrap联合抽相同replicateId；固定样本数不被CI/错误数改变；全零/全相同差值触发退化保护，不产生“零误差已证明”的错误结论。
15. goodput、PER-system、visible BER的不同分母独立算例核对，盲区geometry erasure不消失；分区无重复计数。
16. checkpoint中断恢复与连续运行逐项一致、签名不匹配拒绝、完成replicate不重复。并行度不得改变随机账本。
17. MATLAB R2022a Code Analyzer检查活动V4文件；历史快照不为消除警告而改写。未解决的活动代码告警需逐项说明并判定，不能通过删除核心检查使audit转绿。
18. 正式前运行统一`auditV4`，核对所有测试证据与参数/代码/调度/统计哈希；复验历史源文件未变。

## 15. 实施阶段与 manifest

| 阶段 | 工作 | 完成证据 |
|---|---|---|
| 0 | 核对源版本与论文、隔离V4、清除活动V3结果依赖 | source manifest、差异记录、调用清单 |
| 1 | no-LDRO chirp/Gray/交织/LLR | 独立向量与全标签测试 |
| 2 | Track B 768-bit CR3链 | hard/ML无噪声及位度量测试 |
| 3 | Track A独立接收机与完整调度 | Point/Midamble/符号质量门及无Hamming证据 |
| 4 | Track B三个分支与因果状态 | 块后生效、双history、无真值接口 |
| 5 | 双模式、轨道、信道、盲区与统计 | 时间账本、mask、配对及退化统计算例 |
| 6 | 有限候选calibration与独立validation | 新参数版本、门指标、失败记录 |
| 7 | 小规模完整链smoke | wiring与恢复证据，不形成显著性结论 |
| 8 | 固定预算formal及报告 | 完整独立样本、所有结果与精度标签 |

阶段0–5允许为实现验证所需的确定性测试和小型机制检查，不运行formal；每阶段完成后先做对应自审，再进入下一阶段。任何长时运行先验证小规模调用链。

manifest 至少包含：

```text
planVersion, trackId, methodId, paperIdentity, paperVersionHash
channelRole, channelModel, comparisonMode, sourceManifestHash, codeHash
physicalSf, effectiveDataSf, ldro, dataAlphabetSize, dataBinSpacing
bandwidthHz, sampleRateHz, samplesPerSymbol, symbolDurationSec
grayBitOrder, fftBinDirection, interleaverDirection, hammingTableHash
softMetric, noiseEstimator, llrSign, llrClip, calibrationProtocolHash
preambleDefinition, terminalMidamble, midambleAfterDataIndices
frameStartTimesSec, frameDurationSec, payloadSymbolTimesSec, midambleTimesSec
scheduleType, interFrameGapSec, frameTimingHash, orbitModelHash
observationMaskHash, scoringMaskHash, regionDefinition, receiverResetPolicy
channelPhaseContinuousAcrossPackets, receiverPhaseResetSource
rollingPilotHistoryDefinition, preambleHistoryDefinition, vpRateEvidenceDefinition
bootstrapEstimator, bootstrapCfoTimeReference, bootstrapPhaseTimeReference
initialRateFallback, vpRateOverridePolicy, phasePairPhaseRepresentation
fullRfDoppler, controlledReferencePhasePolicy, allowedCrossFrameStateFields
clusterUnit, fixedReplicateCount, bootstrapDraws, bootstrapSeed, ciMethod
estimandDefinitions, ciHalfWidthTargets, degenerateCiPolicy, zeroEventBound
seedDomain, seedLedgerHash, parameterManifestHash, algorithmSignature
matlabRelease, runtimeMeasurementScope, deadlineDefinition, hardwareProfile
```

结果路径按 `results/{phase}/{track}/{channel}/{mode}/{parameterVersion}/...` 分开；Track A mode标记`paper-controlled`。图标题和报告页必须显示 no-LDRO、信道、mode、payload身份与fixed N，不能仅显示“SF12”。

## 16. 修订记录与准入结论

| 审计项 | 本版处理 |
|---|---|
| F01 主信道 | B主AWGN、Rician独立补充；明确非纯SF单变量 |
| F02 A的Stage55未定义 | 定义独立符号质量门、无Hamming、逐符号因果与每包重置 |
| F03 M数量/帧长 | A明确8M含terminal；B选择37M、157T，无terminal |
| F04 可选停止 | A固定20000packet、B固定50pass，CI只在结束计算 |
| F05 零错上界 | 删除零错提前停止，采用独立packet/pass事件上界及退化CI保护 |
| F06 盲区与区域 | 整帧可见才接收，盲区/跨界不更新，断观测重置，分区显式定义 |
| F07 软概率 | 对齐project的unitary FFT、排除bin0的噪声估计、无默认LLR截断；平方置信与ML位评分分开 |
| F08 配对与goodput | 源包序列、事件键、完整pass配对、visible与system分母分开 |
| F09 calibration/deadline | 候选预算/工程门/validation/smoke职责明确，deadline为实测诊断 |

本次已确定标准project目录、默认VP-quality入口、关键算法对应关系及关键源码实测哈希。阶段0仍需补全移植依赖闭包、论文PDF哈希、V4独立source_manifest，并复验来源未变。对project代码已知规则的静态核对不能代替运行测试；特别是全帧迭代退出的前缀因果性仍是实际准入门。

R3 按用户指定project修正了算法对应关系，但没有完成代码验收、校准或formal。后续只有在相应阶段证据通过后才能推进，不预先宣称“所有BLOCKER为0”。

报告措辞：Track A 是no-LDRO论文条件适配锚点与符号级Stage55机制对照；Track B 是AWGN主信道下的SF11流程SF12移植，另有Rician鲁棒性结果，分别报告controlled算法跟踪和native系统代价。保留所有不利结果、精度不足和实时期限未达标结论。



## 17. R3 项目对齐补充门与交付契约

### 17.1 数值量纲

SF11的bin宽为250000/2048=122.0703125 Hz，V4为125000/4096=30.517578125 Hz。对相同物理Hz/s速率：
- V4的bin/s为SF11的4倍；
- 单符号Hz漂移因T增加而为4倍；
- 单符号漂移的bin数为16倍。
不能把“4倍”同时套给所有门限，也不能用8 bin/s替代重新验证。本版保留源方法结构，SF12保护范围和残余估计不确定度独立标定。

### 17.2 移植一致性与新增规则

阶段1–4先以相同SF11配置和合成输入，比对指定project源及V4兼容测试入口的bootstrap、LLR、平方margin、逐轮mask、8槽history、CFO/rate与最终bit输出。这个兼容入口只用于实现验证，正式V4仍固定SF12；不修改源project或读取正式性能门。

必须保留R2新增实验身份：A整数Paper-native、B 37M/157T、双时间轴、B AWGN主/Rician补充、完整pass固定样本统计与新仰角分区。源脚本按每个可见段重置生成相位而R3生成器跨盲区连续，这是显式物理调度差异，不宣称所有状态和源完全一致。接收机跨断观测重置与源可见段重启方向一致，具体事件mask仍由R3定义。

某些旧源码注释提到轨道prior、旧SNR门或强制性能排序；使用实际默认函数参数和可执行分支判断，不复制不生效注释为方案规则。所有源与方案差异分成维度适配、V4实验设计、独立证明的缺陷修正三类登记。

### 17.3 先冻结结果结构再运行formal

smoke必须完整经过正式记录、保存、恢复、统计、bootstrap和报告生成链。固定记录至少包含：
- plan/source/code/parameter/timing/statistics/seed哈希；
- 每帧方法、mode/channel/passId/packetId、可见/计分mask和所有计数分母；
- 逐D预测CFO、对齐的中心时间、full-RF CFO平方误差、当时的硬标签；
- VP候选/实际接纳/实际使用标签、产生/可用/应用时刻、首生效位置；
- 帧内rolling前导/VP来源、cross-frame history count、rate来源与可观测性；
- Paper M估计和生效事件、失败标志、FFT和细搜索运算量；
- native发射包数、geometry erasure、实际airtime、完整pass时间及各模块runtime。
对可见帧CFO保存逐符号计数/平方误差，不能只保存总RMSE。原始误接纳标签不可被最终译码覆写。

formal前由smoke实测每包/每pass耗时与内存，估算A 400000 paired packets、B 2000 paired complete passes的总成本与存储。固定预算和统计规则不因估算不方便而静默缩减。计算开销估算、代码测试、校准与formal完成状态分别报告。
