# SenLoRa LoRa 符号检测与多普勒补偿项目审阅和学习说明

这份文档的目标不是写组会讲稿，而是帮你自己把整个复现流程吃透。读的时候建议按顺序看：先理解信号模型，再理解为什么会错符号，然后理解正确符号检测，最后理解为什么正确符号可以反过来帮助多普勒补偿。

## 1. 审阅结论

本项目实现的是一个离散时间 LoRa 基带仿真。每个 LoRa 符号由 `2^SF` 个采样点组成，多个符号按时间顺序连续排列，所以它处理的是“连续符号序列”，但信号本身在 MATLAB 里是离散采样信号。

代码主线是成立的：

1. 生成带多普勒频偏和 AWGN 噪声的 LoRa 符号序列。
2. 对接收符号做多普勒补偿、dechirp 和 FFT。
3. 用 SenLoRa 的软信息流程判断哪些 payload 符号是高置信符号。
4. 把高置信符号当作软导频，用 PREC 相位旋转法估计残差。
5. 用最近若干个已接受符号的残差趋势预测下一个符号的 CFO。
6. 输出 BER/SER 曲线和 `CorrectFlag`、`ErrorFlag`、`ConfidentFlag` 标志。

审阅中发现并修正了一个 MATLAB 静态检查问题：

- `run_senlora_continuous_demo.m` 中 `yticklabels({"Confident", "Error", "Correct"})` 改为字符串数组 `yticklabels(["Confident", "Error", "Correct"])`。

验证结果：

- `checkcode` 检查全部 MATLAB 文件，问题数为 0。
- `testSenLoRaConfidence.m` 的 12 个单元测试全部通过。

需要注意的限制：

- 当前信道是单位增益平坦多普勒相位信道加复高斯白噪声，不包含 Rayleigh/Rician 衰落、多径时延扩展、路径损耗。
- `CorrectFlag` 和 `ErrorFlag` 是仿真评估标志，需要已知发送真值；真实接收机不能直接知道它们。
- 真实接收机可用的是 `ConfidentFlag`，也就是“这个符号看起来足够可靠，可以作为导频”的标志。
- 当前 interleaver 是与本项目合成编码块一致的简化转置模型，不等同于完整商用 LoRa PHY 的所有细节。
- 论文未公开完整 `amendLLR` 和 `channelSense` 闭式实现，本项目保留接口并采用可解释的替代流程。

## 2. 你应该先抓住的整体图

整个项目可以理解成下面这条链：

```text
发送 LoRa bin 序列
    -> LoRa 调制成离散 upchirp 符号
    -> 加入连续累积多普勒相位
    -> 加入复高斯白噪声
    -> 接收端预测并补偿 CFO 与累积相位
    -> dechirp + FFT 得到每个符号的频域峰
    -> 硬判决得到 RxBin
    -> 软信息检测得到 ConfidentFlag
    -> 高置信符号作为软导频
    -> PREC 估计残差
    -> 更新 CFO 轨迹，继续检测后续符号
```

最重要的一句话：

> 这个系统不是只检测单个 LoRa 符号，而是在连续符号序列里，一边检测，一边挑选可靠符号，一边修正随时间累积的多普勒频偏。

## 3. 项目文件怎么对应流程

主实验入口：

- `run_sf11_variable_doppler_ber.m`：最终 SF11、BW250 kHz、多普勒变化率、BER/SER/置信标志实验。
- `run_senlora_continuous_demo.m`：连续 LoRa 符号检测和标志位演示。
- `run_predictive_doppler_ber_demo.m`：较早版本的预测式多普勒 BER 演示。

信号生成：

- `modulateLoRaSymbol.m`：生成单个 LoRa 符号。
- `generateDopplerLoRaSymbols.m`：给符号加连续累积多普勒相位和 AWGN。
- `buildDopplerCfoTrajectory.m`：根据多普勒变化率积分得到每个符号的 CFO。

LoRa 前端解调：

- `hardDemodLoRaWithCfo.m`：补偿 CFO、dechirp、FFT、取最大峰。
- `dechirpLoRaSignalSequence.m`：对连续 IQ 序列做 dechirp 和 FFT。
- `detectLoRaSignalSequence.m`：从 LoRa IQ 到检测结果的封装。

正确符号检测：

- `detectConfidentSymbolsFromFft.m`：核心 SenLoRa 置信符号检测。
- `stepSenLoRaSymbolDetector.m`：流式逐符号检测接口。
- `detectContinuousSymbolSequence.m`：把逐符号事件整理成连续序列标志。
- `selectConfidentSymbols.m`：根据阈值选择高置信符号。

软解码相关：

- `fftToBinLogProb.m`：FFT 能量转 bin 概率。
- `binLogProbToLlr.m`：bin 概率转 Gray bit LLR。
- `softHammingDecodeOne.m`、`softHammingDecodeBlock.m`：软 Hamming 译码。
- `symbolConfidence.m`：计算符号置信度。
- `updateConfidenceThreshold.m`：更新块阈值和全局阈值。

多普勒补偿：

- `predictiveDopplerCompensate.m`：用正确或高置信符号预测并补偿多普勒。
- `estimateResidualByPhaseRotation.m`：PREC 相位旋转法估计残差。
- `makePhaseRotationBank.m`：预生成 0.1 bin 搜索网格的相位旋转矩阵。

测试：

- `testSenLoRaConfidence.m`：覆盖 Gray 映射、软 Hamming、连续标志、LoRa 前端、PREC、多普勒边界、变速多普勒积分等 12 个测试。

## 4. 实验条件

主实验参数在 `run_sf11_variable_doppler_ber.m` 中：

| 参数 | 数值 | 含义 |
|---|---:|---|
| `SF` | 11 | 每个符号携带 11 个 Gray bit |
| `BW` | 250 kHz | LoRa 带宽 |
| `M` | 2048 | 每符号采样点数，也是 FFT 点数 |
| `Ts` | 8.192 ms | 单个 LoRa 符号持续时间 |
| FFT bin spacing | 122.0703125 Hz | 相邻 LoRa FFT bin 的频率间隔 |
| `CR` | 3 | 每个交织块含 `4+CR=7` 个符号 |
| 初始已知导频 | 8 个符号 | 用于启动 CFO 估计 |
| PREC 步长 | 0.1 bin | 局部细搜索步长 |
| 历史长度 | 最多 8 个符号 | 用最近已接受符号拟合 CFO 趋势 |
| 信道 | 平坦多普勒相位 + AWGN | 无多径、无幅度衰落 |

注意横轴 `SampleSNRdB` 是时域单采样 SNR，不是 `Eb/N0`。SF11 的 2048 点 dechirp/FFT 会带来约 `10log10(2048)=33.11 dB` 的符号处理增益，所以负的采样 SNR 下依然可能出现很低 BER。

## 5. 信号模型

第 `m` 个 LoRa 符号的接收模型可以写成：

```text
r_m[n] = x_m[n] * exp(j*(phi_m + 2*pi*epsilon_m*n/M)) + w_m[n]
```

其中：

- `x_m[n]` 是发送的 LoRa 基带符号。
- `M=2^SF` 是每符号采样点数。
- `epsilon_m` 是归一化 CFO，单位是 FFT bin。
- `phi_m` 是第 `m` 个符号起点处的累积相位。
- `w_m[n]` 是复高斯白噪声。

代码里噪声是这样加的：

```matlab
sampleSnr = 10 ^ (sampleSnrDb / 10);
noiseSigma = sqrt(1 / (2 * sampleSnr));
noise = noiseSigma * (randn(size(txSymbols)) + 1i * randn(size(txSymbols)));
rxSymbols = txSymbols + noise;
```

因为 LoRa 符号幅度为 1，所以每个复采样的信号功率约为 1。`noiseSigma` 里的 `2` 是因为复噪声有实部和虚部两个维度。

## 6. 多普勒频偏怎么引入

多普勒不是直接固定一个常数频偏，而是先定义多普勒变化率，再积分得到每个符号时刻的频偏。

符号时间：

```text
Ts = 2^SF / BW = 2048 / 250000 = 0.008192 s
```

FFT bin 间隔：

```text
DeltaF = BW / 2^SF = 250000 / 2048 = 122.0703125 Hz
```

如果多普勒变化率为 `a_D(t)`，则：

```text
f_D(t_m) = f_D(0) + integral a_D(t) dt
epsilon_m = f_D(t_m) / DeltaF
```

在主 BER 实验中，多普勒变化率不是固定 500 Hz/s，而是：

```text
a_D[m] = 500 + 250*sin(2*pi*(m-1)/(30-1)) Hz/s
```

所以它在一帧内约从 250 Hz/s 到 750 Hz/s 变化。接收机不知道这个真实轨迹，只能从已接受的符号中估计。

500 Hz/s 只用于和你给的理论图做边界验证。该条件下：

```text
每符号频率增加量 = 500 * 0.008192 = 4.096 Hz
每符号归一化 CFO 增量 = 4.096 / 122.0703125 = 0.033554432 bin
第 16 个符号 CFO = 15 * 0.033554432 = 0.50331648 bin
```

这解释了为什么原始解调在第 16 个符号附近开始出错：CFO 超过半个 FFT bin 后，最大峰会更容易落到相邻 bin。

## 7. LoRa 解调为什么会被 CFO 搞错

LoRa 解调的核心是：

```text
接收符号 * downchirp -> FFT -> 找最大峰
```

如果没有 CFO，发送 bin `k` 的能量峰应该出现在 FFT bin `k`。

如果有归一化 CFO `epsilon`，频谱峰会从整数 bin 偏移到 `k + epsilon` 附近。硬判决只能选整数 bin，所以：

- `|epsilon| < 0.5` 时，一般还判到原 bin。
- `|epsilon| > 0.5` 时，更容易判到相邻 bin。

这就是“半 bin 边界”的物理含义。

为什么原始 SER 后期接近 1，但 BER 只接近 `1/11=0.0909`？

因为错误主要是相邻 bin 错误，而 LoRa Gray 映射下相邻 bin 平均只差 1 bit。SF11 每符号 11 bit，所以：

```text
BER ≈ 1 / 11 = 0.090909
```

## 8. 正确符号检测到底在检测什么

这里最容易混淆。项目里有三类标志：

| 标志 | 是否真实接收机可用 | 含义 |
|---|---|---|
| `CorrectFlag` | 不可直接用 | 当前硬判决 bin 是否等于发送真值 |
| `ErrorFlag` | 不可直接用 | 当前硬判决 bin 是否不等于发送真值 |
| `ConfidentFlag` | 可用 | 接收机认为该符号置信度足够高，可作为软导频 |

真实系统不知道发送真值，所以不能直接知道 `CorrectFlag` 和 `ErrorFlag`。它只能通过软信息判断 `ConfidentFlag`。

仿真里保留 `CorrectFlag` 和 `ErrorFlag` 是为了评价 `ConfidentFlag` 是否可靠。例如：

- `ConfidentFlag=1` 且 `CorrectFlag=1`：成功找到正确软导频。
- `ConfidentFlag=1` 且 `ErrorFlag=1`：误接收，会污染后续 CFO 更新。
- `ConfidentFlag=0` 并不代表错误，只代表不够可靠，不拿来更新。

## 9. SenLoRa 置信符号检测流程

### 9.1 FFT 能量转概率

对每个 payload 符号，先得到 FFT 频谱 `Z[f]`，再形成 bin 概率：

```text
P(Z[f]) = exp(|Z[f]|^2 - N0) / sum_s exp(|Z[s]|^2 - N0)
```

代码位置：`fftToBinLogProb.m`。

实现时用 log-sum-exp 避免指数溢出。`mode="paper"` 对应论文形式；`mode="noise-scaled"` 是额外保留的实用消融分支。

### 9.2 bin 概率转 Gray bit LLR

每个 LoRa bin 对应一个 SF 位 Gray 码。对第 `k` 个 bit：

```text
LLR_k = log( sum_{bin bit k = 1} P(bin) / sum_{bin bit k = 0} P(bin) )
```

代码位置：`binLogProbToLlr.m`。

直观理解：

- `LLR_k` 很大，说明这个 bit 更像 1。
- `LLR_k` 很小或为负，说明这个 bit 更像 0。
- `|LLR_k|` 越大，越确信。

### 9.3 交织块和 Hamming 软译码

每 `4+CR=7` 个 LoRa 符号形成一个编码块。项目中用简化转置模型：

```text
7 个符号 x SF 个 LLR -> SF 个 Hamming codeword x 7 bit
```

代码位置：

- `deinterleaveBlock.m`
- `softHammingDecodeBlock.m`
- `softHammingDecodeOne.m`

Hamming 软译码不是只看硬 0/1，而是看每个候选码字和 LLR 的匹配程度。匹配得越好，得分越高。

### 9.4 置信度

译码和修正后，每个符号的置信度定义为：

```text
Conf_j = sum_k |LLR'_j,k|^2
```

代码位置：`symbolConfidence.m`。

直观理解：一个符号的 11 个 bit 都很确定，则 `Conf` 很高；如果多个 bit 模糊，则 `Conf` 低。

### 9.5 阈值

块阈值：

```text
tau_b = mean(Conf) + std(Conf)
```

全局阈值：

```text
tau_g = alpha * tau_g_old + (1-alpha) * tau_b
alpha = 0.8
```

代码位置：`updateConfidenceThreshold.m` 和 `selectConfidentSymbols.m`。

项目里故意保留两种用法：

- 置信标志图使用严格的全局阈值 `global`，更贴近论文阈值描述。
- BER 追踪使用局部块阈值 `block`，目的是在多普勒持续变化时保证有足够的新软导频进入补偿闭环。

这不是算法偷偷用了真值，而是阈值策略不同。BER 中真正可实现的曲线仍然只使用 `ConfidentFlag` 作为更新门控。

## 10. PREC 相位旋转残差估计

当一个符号被认为可靠后，就可以把它当作导频。假设当前硬判决为 `k_hat`，重构对应 LoRa 符号 `x_hat[n]`。接收符号和重构符号相乘：

```text
residualTone[n] = r[n] * conj(x_hat[n])
```

如果 `k_hat` 是正确的，那么 LoRa 调制部分被抵消，剩下的主要就是 CFO 引起的复指数旋转。

PREC 做的事情是扫描一组候选残差 `delta`：

```text
J(delta) = | mean( residualTone[n] * exp(-j*2*pi*delta*n/M) ) |
```

哪个 `delta` 让相位旋转抵消得最好，哪个 `J(delta)` 最大，就选哪个作为残差估计。

本项目中：

- 初始导频搜索范围：`-1:0.1:1 bin`
- 后续局部残差搜索范围：`-0.5:0.1:0.5 bin`
- 扫描步长：0.1 bin
- 最大点附近再做三点二次插值，提高估计精度

代码位置：`estimateResidualByPhaseRotation.m`。

## 11. 用正确符号预测下一个符号

你之前举例说“前四个正确符号预测第五个”，项目里把这个推广成可配置的历史窗口。

流程是：

1. 前 `bootstrapPilotCount=8` 个符号已知正确，用它们估计初始 CFO。
2. 后续每出现一个被接受的高置信符号，就估计它的真实残差。
3. 保存最近最多 `historyLength=8` 个已接受符号的位置和 CFO。
4. 对这些点做最小二乘拟合。
5. 用拟合曲线预测下一个符号的 CFO。

线性预测形式可以理解为：

```text
epsilon_i ≈ a*m_i + b
epsilon_next = a*m_next + b
```

代码位置：`predictiveDopplerCompensate.m`。

这个函数还维护一个累积相位 `phaseState`。为什么不只补 CFO，还要补相位？因为多普勒不是每个符号内部才起作用，它在符号与符号之间连续积累。如果只补每个符号内部的频率斜率，不补符号起点相位，连续序列的相位状态会不一致。

## 12. 为什么不能用所有硬判决符号当导频

如果把所有硬判决都当导频，一旦某个符号判错，重构出来的 `x_hat[n]` 就不是原符号。此时 PREC 估计到的残差会混入错误符号造成的相位结构，更新到 CFO 历史后会污染后面的预测。

所以系统要做的是：

```text
少量、可靠、高精度的软导频
```

而不是：

```text
大量、可能错误的硬判决导频
```

这就是 `ConfidentFlag` 的意义。

## 13. BER 图怎么看

结果图：

```text
results/sf11_variable_doppler/sf11_variable_doppler_ber_vs_snr.png
```

五条主要曲线：

| 曲线 | 含义 | 是否真实接收机可实现 |
|---|---|---|
| `No compensation` | 完全不补 CFO | 可实现，但性能差 |
| `Static pilot PREC` | 只用初始导频估计一个固定 CFO | 可实现，但不能跟踪变化 |
| `Detected-symbol pilot` | 用 `ConfidentFlag` 选软导频并迭代补偿 | 可实现，是本项目重点 |
| `Oracle correct-symbol upper bound` | 只允许真实正确符号更新 | 不可实现，只作上界 |
| `Ideal CFO` | 直接使用真实 CFO | 不可实现，只作理想基准 |

关键结果：

| SNR | Detected-symbol pilot BER | 解释 |
|---:|---:|---|
| -23 dB | 0.1676 | 噪声很强，置信符号会有误接收 |
| -20 dB | 0.00696 | 已经明显优于不补偿和静态补偿 |
| -19 dB | 0.00131 | 开始接近 oracle 上界 |
| -18 dB | 0.000585 | 接近 `10^-4` 量级 |
| -16 dB | 3.44e-5 | 低于 `10^-4` |
| -15 dB | 0 observed errors | 145200 bit 中无观测错误 |

`-15 dB` 的 0 错误不能说真实 BER 等于 0。更严谨的说法是：在 145200 bit 仿真中没有观察到错误，单侧 95% 置信上界约为 `2.06e-5`，因此在该实验条件下已验证低于 `10^-4`。

## 14. 500 Hz/s 逐符号图怎么看

结果图：

```text
results/sf11_variable_doppler/sf11_500hz_symbol_ser_ber_validation.png
```

这张图对应你给的理论图条件：`SF=11, BW=250 kHz, 500 Hz/s`。

重点看第 16 个符号：

- 第 15 个符号：`epsilon=0.469762048 bin`，还没超过半 bin。
- 第 16 个符号：`epsilon=0.50331648 bin`，刚超过半 bin。
- 无噪声理论从第 16 个符号开始由正确转为错误。
- 加 AWGN 后，错误率不会垂直跳变，而是在半 bin 附近平滑过渡。

图中 raw SER 后面接近 1，说明原始硬判决几乎每个符号都错。raw BER 后面接近 0.0909，原因是相邻 Gray bin 平均只错 1 bit。

正确符号预测和理想 CFO 曲线基本贴近底部，说明：只要能持续找到可靠符号作为软导频，累积多普勒频偏可以被压住。

## 15. 置信标志图怎么看

结果图：

```text
results/sf11_variable_doppler/sf11_confidence_flag_validation.png
```

上半图：

- 蓝线是每个 payload 符号的置信度 `sum |LLR|^2`。
- 红虚线是全局阈值。
- 绿色点是超过阈值的 `ConfidentFlag`。

下半图：

- `CorrectFlag` 表示仿真真值判断正确。
- `ErrorFlag` 表示仿真真值判断错误。
- `ConfidentFlag` 表示接收机选出来可作为导频。

当前示例中：

- 所有 21 个 payload 符号硬判决都正确。
- 只有 4 个被选为高置信导频。
- `precision=1.000`，说明选出来的都是真正确符号。
- `coverage=0.190`，说明它是保守选择，不会把所有正确符号都拿来更新。

这个图教你的重点是：`ConfidentFlag` 追求的是“选出来的一定要可靠”，而不是“把所有正确符号都选出来”。

## 16. 审阅中确认过的正确点

1. 多普勒频偏是连续相位方式引入，不是每个符号独立随机相位。
2. 500 Hz/s 条件下第 16 个符号跨过半 bin 的计算正确。
3. 变速多普勒通过 `cumtrapz` 积分生成，接收机不读取真实多普勒轨迹。
4. AWGN 是复采样噪声，横轴是 sample SNR。
5. BER 使用 LoRa Gray bit 汉明距离统计，不是简单 SER/SF。
6. `CorrectFlag/ErrorFlag` 与 `ConfidentFlag` 区分清楚。
7. 实际 BER 曲线使用的是检测出的高置信符号，不是 oracle 真值符号。
8. oracle 和 ideal 曲线只用于对照上界，不应称为实际接收机结果。
9. 局部 PREC 搜索步长满足 0.1 bin 要求。
10. MATLAB 静态检查和单元测试均通过。

## 17. 审阅中发现的不妥和处理

### 17.1 MATLAB 路径污染导致测试失败

第一次运行测试时，MATLAB 调到了外部路径：

```text
D:\BELLHOP\atWin10_2020_11_4\tests\runtests.m
```

这个文件遮蔽了 MATLAB 官方的 `runtests`。这不是项目逻辑错误，而是 MATLAB path 污染。复验时我使用：

```matlab
restoredefaultpath
addpath(projectFolder)
suite = matlab.unittest.TestSuite.fromFile('testSenLoRaConfidence.m');
results = run(suite);
```

这样可以绕开外部 `runtests.m`。

### 17.2 MATLAB 偏好目录写入受限

MATLAB 默认想写 AppData 下的 toolbox cache，沙箱环境不允许。复验时将：

```text
MATLAB_PREFDIR = outputs/senlora_matlab/.matlab_batch_prefs
```

这样测试缓存写在项目目录内。

### 17.3 静态检查小问题

`yticklabels` 使用 cell 字符串触发 `checkcode` 建议，已改为字符串数组。修正后 `checkcode` 问题数为 0。

### 17.4 文档解释容易误导的点

原说明容易让人把 `CorrectFlag` 当成真实接收机可用信号。现在需要明确：

```text
仿真评估用：CorrectFlag / ErrorFlag
真实接收机用：ConfidentFlag
```

这点非常重要，因为真实系统没有发送真值。

## 18. 如果你要自己从代码走一遍

建议按这个顺序打开文件：

1. `run_sf11_variable_doppler_ber.m`
2. `buildDopplerCfoTrajectory.m`
3. `generateDopplerLoRaSymbols.m`
4. `hardDemodLoRaWithCfo.m`
5. `detectConfidentSymbolsFromFft.m`
6. `stepSenLoRaSymbolDetector.m`
7. `detectContinuousSymbolSequence.m`
8. `predictiveDopplerCompensate.m`
9. `estimateResidualByPhaseRotation.m`
10. `testSenLoRaConfidence.m`

读代码时抓住三个变量：

- `trueBins`：发送真值，只用于仿真生成和评估。
- `detectedBins`：接收机硬判决结果。
- `confidencePilotMask`：接收机真正拿来更新多普勒的高置信符号掩码。

只要你能解释这三个变量之间的区别，整个项目的核心逻辑就已经抓住一半了。

## 19. 一句话总结

这个项目复现的关键不是“LoRa 能不能解调”，而是：

> 在累积多普勒让 LoRa FFT 峰逐符号漂移的情况下，接收机如何从 payload 中挑出少量可靠符号作为软导频，并用 PREC 残差估计持续修正后续符号的 CFO 和相位，从而把 BER 从多普勒误码地板压到接近理想 CFO 的水平。

