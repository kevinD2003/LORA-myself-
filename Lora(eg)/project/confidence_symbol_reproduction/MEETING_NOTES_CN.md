# SF11 LoRa 正确符号检测与累积多普勒补偿组会讲稿

## 1. 本次复现要解决的问题

本次工作不是只做普通 LoRa 硬判决，而是完成下面的闭环：

```text
连续 LoRa 符号
-> 多普勒连续相位信道和 AWGN
-> 前导符号初始频偏估计
-> 预测下一符号频偏
-> SenLoRa 软解调和置信符号检测
-> 把检测出的高置信正确符号作为新导频
-> PREC 局部相位旋转估计残差
-> 更新频偏趋势和累积相位
-> 输出 CorrectFlag / ErrorFlag / ConfidentFlag 和 BER
```

核心问题是：未知载荷符号不能直接当作导频。只有接收机判定为高置信的符号，才允许参与后续多普勒残差更新。

## 2. 仿真参数与信道模型

主程序是 `run_sf11_variable_doppler_ber.m`，主要参数为：

| 参数 | 数值 | 含义 |
|---|---:|---|
| SF | 11 | 每个 LoRa 符号携带 11 个 Gray bit |
| BW | 250 kHz | LoRa 带宽 |
| M | 2048 | `M=2^SF`，每符号采样点数和 FFT 点数 |
| CR | 3 | 每个交织块包含 `4+CR=7` 个符号 |
| 初始前导数 | 8 | 仅用于启动估计，不是固定为 4 |
| PREC 步长 | 0.1 bin | 用户指定的局部细搜索步长 |
| 预测历史长度 | 8 | 最近最多 8 个已接受正确符号 |
| 置信迭代次数 | 5 | 对应论文 Algorithm 2 的迭代结构 |

当前信道明确写成：

```math
r_m[n]=x_m[n]\exp\left\{j\left(\phi_m+
\frac{2\pi\epsilon_m n}{M}\right)\right\}+w_m[n].
```

其中：

- `x_m[n]` 是第 `m` 个 LoRa 符号；
- `epsilon_m` 是以 FFT bin 为单位的归一化多普勒频偏；
- `phi_m` 是符号起点的累积相位；
- `w_m[n]` 是复高斯白噪声；
- 相位按 `phi_(m+1)=phi_m+2*pi*epsilon_m` 连续累积。

代码中的噪声为：

```matlab
sampleSnr = 10 ^ (sampleSnrDb / 10);
noiseSigma = sqrt(1 / (2 * sampleSnr));
noise = noiseSigma * (randn(...) + 1i * randn(...));
```

因此图中横轴是时域单采样 SNR，不是 `Eb/N0`。当前没有加入 Rayleigh/Rician 幅度衰落、多径时延扩展和路径损耗。这样才能与 AWGN 理论 BER 以及用户给出的半 bin 截图直接比较。

## 3. 多普勒频偏如何引入

符号周期和 FFT bin 间隔分别为：

```math
T_s=\frac{2^{SF}}{BW},\qquad
\Delta f=\frac{BW}{2^{SF}}.
```

对于 `SF=11, BW=250 kHz`：

```math
T_s=8.192\ \mathrm{ms},\qquad
\Delta f=122.0703125\ \mathrm{Hz}.
```

`buildDopplerCfoTrajectory.m` 接受标量或逐符号变化率向量，并先积分得到瞬时多普勒频率：

```math
f_d(t_m)=f_d(0)+\int_0^{t_m}a_D(\tau)d\tau,
\qquad \epsilon_m=\frac{f_d(t_m)}{\Delta f}.
```

主 BER 仿真不是固定变化率，而是：

```math
a_D[m]=500+250\sin\left(\frac{2\pi(m-1)}{29}\right)\ \mathrm{Hz/s},
```

即一帧内约在 `250...750 Hz/s` 之间变化。接收机并不知道这个轨迹，它只能从已接受符号的残差进行预测。

`500 Hz/s` 只用于与给定截图做理论边界校核。该条件下每符号频率增加：

```math
\Delta f_D=500T_s=4.096\ \mathrm{Hz},
```

归一化增量为：

```math
\Delta\epsilon=\frac{4.096}{122.0703125}=0.033554432\ \mathrm{bin/symbol}.
```

第 `m` 个符号起点为：

```math
\epsilon_m=(m-1)\times0.033554432.
```

因此第 16 个符号：

```math
\epsilon_{16}=15\times0.033554432=0.50331648>0.5.
```

这就是截图中原始解调从第 16 个符号开始发生确定性错误的原因。频偏超过半个 FFT bin 后，相邻 bin 的幅度超过原 bin，最大峰硬判决转移到相邻符号。

## 4. LoRa 符号解调和 Gray BER

发送符号可写成：

```math
x_m[n]=c[n]\exp\left(j\frac{2\pi k_m n}{M}\right),
```

其中 `c[n]` 是基础 upchirp，`k_m` 是符号 bin。接收端先乘 downchirp，再做 `M` 点 FFT：

```math
Z_m[q]=\operatorname{FFT}\{r_m[n]c^*[n]\}.
```

普通硬判决为：

```math
\hat{k}_m=\arg\max_q|Z_m[q]|.
```

BER 不是简单的符号错误数除以符号数。代码先把发送 bin 和检测 bin 映射为 LoRa Gray bit，再统计 Hamming 距离：

```math
BER=\frac{\sum_m d_H\left(g(k_m),g(\hat{k}_m)\right)}{N_{sym}\times SF}.
```

当归一化频偏使判决稳定偏移一个相邻 bin 时，循环 Gray 映射平均只错 1 bit，所以：

```math
BER\rightarrow\frac{1}{SF}=\frac{1}{11}=0.090909.
```

这解释了逐符号 BER 图中原始曲线最后稳定在约 `0.091`，而 SER 稳定在 1。

## 5. SenLoRa 正确符号和置信符号检测

### 5.1 FFT bin 概率

对每个 payload FFT 频谱，先根据论文公式形成 bin 概率：

```math
P(Z[f])=\frac{\exp(|Z[f]|^2-N_0)}
{\sum_s\exp(|Z[s]|^2-N_0)}.
```

`N0` 由前导 FFT 的非零 bin 能量估计。代码使用 log-sum-exp，避免 softmax 数值溢出。

### 5.2 Gray bit LLR

第 `k` 个 Gray bit 的 LLR 为：

```math
LLR_k=\log\frac{\sum_{s:b_k(s)=1}P(Z[s])}
{\sum_{s:b_k(s)=0}P(Z[s])}.
```

一个 LoRa 符号得到 `SF=11` 个 LLR。7 个符号组成一个 `CR=3` 交织块。

### 5.3 Hamming 软译码

反交织后得到 `SF x (4+CR)` 的 LLR 矩阵。每个 Hamming codeword 在 16 个候选码字中评分：

```math
Score(c)=\sum_{i:\operatorname{sign}(LLR_i)=c_i}|LLR_i|^2
-\sum_{i:\operatorname{sign}(LLR_i)\ne c_i}|LLR_i|^2.
```

选择得分最大的候选码字。当前 `amendLLR` 默认使用 identity 模式，因为论文没有公开其完整闭式公式。

### 5.4 符号置信度和阈值

每个符号的置信度为：

```math
Conf_j=\sum_{k=1}^{SF}|LLR'_{j,k}|^2.
```

论文的块阈值和全局阈值为：

```math
\tau_b=\mu_{Conf}+\sigma_{Conf},
```

```math
\tau_g(t)=0.8\tau_g(t-1)+0.2\tau_b(t).
```

代码保留两条用途不同的分支：

- 论文置信标志图使用严格全局阈值 `Conf_j >= tau_g`；
- 多普勒跟踪 BER 使用局部块阈值 `Conf_j >= tau_b`，并最多迭代 5 次，以保证变化率转折后仍有新导频到达。

必须区分三类标志：

- `CorrectFlag`：硬判决是否等于仿真真值，只能在有标签的仿真中计算；
- `ErrorFlag`：硬判决是否不等于仿真真值；
- `ConfidentFlag`：接收机依据 LLR 和阈值认为该符号足够可靠，不需要知道真值。

实际在线接收机使用的是 `ConfidentFlag`，不能直接使用 `CorrectFlag`。

## 6. PREC 残差估计和下一符号预测

### 6.1 初始前导估计

前 8 个符号是已知前导。数量由 `cfg.bootstrapPilotCount` 配置，并没有在算法中固定为 4。

对于一个已知符号波形 `x_hat[n]`，相位旋转候选值为 `delta`，评价函数为：

```math
J(\delta)=\left|\frac{1}{M}\sum_{n=0}^{M-1}
r[n]\hat{x}^*[n]\exp\left(-j\frac{2\pi\delta n}{M}\right)\right|.
```

估计结果为：

```math
\hat{\delta}=\arg\max_\delta J(\delta).
```

初始搜索范围为 `-1:0.1:1 bin`，后续局部残差范围为 `-0.5:0.1:0.5 bin`。最大点附近再做三点二次插值，所以输出估计可以细于 0.1 bin，但实际扫描网格仍严格是用户要求的 0.1。

### 6.2 用历史正确符号预测下一符号

保存最近最多 8 个被接受的导频位置 `m_i` 和 CFO 测量 `epsilon_i`，做最小二乘拟合：

```math
(\hat{a},\hat{b})=\arg\min_{a,b}
\sum_i\left[\epsilon_i-(am_i+b)\right]^2.
```

下一符号预测为：

```math
\hat{\epsilon}_{m+1}=\hat{a}(m+1)+\hat{b}.
```

这正对应“前面若干正确符号预测下一个符号”，历史长度可配置，不是固定四个符号。

### 6.3 预测补偿和残差更新

先用预测 CFO 和累积相位补偿：

```math
\tilde{r}_m[n]=r_m[n]\exp\left[-j\left(
\hat{\phi}_m+\frac{2\pi\hat{\epsilon}_m n}{M}\right)\right].
```

再硬判决得到 `k_hat_m`。只有置信掩码允许更新时，才把判决符号重构为软导频，并用 PREC 求真实残差：

```math
\hat{e}_m=\hat{\epsilon}_{m,res},
\qquad
\hat{\epsilon}^{meas}_m=\hat{\epsilon}_m+\hat{e}_m.
```

累积相位更新为：

```math
\hat{\phi}_{m+1}=\hat{\phi}_m+hat{\phi}_{err,m}
+2\pi\hat{\epsilon}^{meas}_m.
```

如果当前符号不可信，则不更新导频历史，只按预测 CFO 推进相位。这可以防止错误符号污染后续所有预测。

## 7. Algorithm-2 风格迭代闭环

主 BER 曲线中的接收机流程是：

1. 第一次只允许 8 个前导更新，得到 pilot-only 补偿结果；
2. 对补偿后的编码 payload 做 SenLoRa 置信符号检测；
3. 把新 `ConfidentFlag` 合并到导频掩码；
4. 使用新的掩码重新做整帧预测和残差补偿；
5. 最多迭代 5 次，或者置信集合不再变化时提前停止；
6. 最后输出检测符号、正确/错误标志和 BER。

这条曲线不读取真实 Doppler 轨迹。仿真真值只用于事后计算 BER、精度和上界曲线。

## 8. BER 图中的五条曲线

1. `No compensation`：完全不做 CFO 补偿；
2. `Static pilot PREC`：只用前导得到一个固定 CFO，之后不再跟踪；
3. `Detected-symbol pilot (local threshold)`：实际接收机方案，用检测出的置信符号迭代更新；
4. `Oracle correct-symbol upper bound`：仿真真值门控，只允许真正正确的符号更新，用于表示可达到的上界；
5. `Ideal CFO`：直接使用真实 CFO 补偿，仅作为理想基准；
6. 黑色虚线 `AWGN theory, ideal CFO`：非相干正交 MFSK 的理论 BER。

实际可实现方法是第 3 条。第 4、5 条不能当作在线接收机结果，只用于解释性能损失来自置信检测、频偏估计还是 AWGN。

## 9. BER-SNR 结果分析

### 9.1 低 SNR 区域

在 `-23 dB`：

- AWGN 理论 BER：`0.13955`；
- 理想 CFO 仿真：`0.13953`，与理论高度一致；
- 真值上界：`0.15275`；
- 检测符号导频：`0.16760`；
- 置信精度：`0.9059`，有 54 个误接收导频。

这说明在很低 SNR 下，主要误差来自噪声，同时错误置信符号会污染频偏估计，所以实际曲线高于上界和理想曲线。

### 9.2 瀑布下降区

从 `-21 dB` 到 `-19 dB`，检测导频 BER 从 `2.927e-2` 降到 `1.309e-3`。同时置信精度提高到约 `0.994`，说明随着 SNR 增加，正确符号检测开始可靠，动态导频能够稳定修正累积多普勒。

理想 AWGN 理论线在：

```math
SNR=-18.374446976\ \mathrm{dB}
```

时恰好达到 `BER=10^-4`。这比 `-15 dB` 更早，原因是 SF11 具有：

```math
10\log_{10}(2^{11})=33.1133\ \mathrm{dB}
```

的符号能量处理增益。因此这里的负单采样 SNR 不能按未扩频 BPSK 的直觉解释。

### 9.3 高 SNR 区域

在 `-16 dB`，检测符号导频 BER 为：

```math
BER=\frac{1}{29040}=3.4435\times10^{-5}<10^{-4}.
```

在 `-15 dB`，专门增加到 600 帧，共 `145200 bit`：

- 检测符号导频错误数：0；
- 置信精度：1.000；
- 置信覆盖率：0.2107；
- 误接收导频数：0；
- 理论 BER：`4.3887e-12`。

零误码不能解释成真实 BER 严格等于 0。单侧 95% 零误码上限为：

```math
BER_{95\%,upper}=1-0.05^{1/145200}=2.0632\times10^{-5}.
```

所以可以严谨地说：在本仿真信道和参数下，`-15 dB` 的检测导频 BER 已验证低于 `10^-4`，而不是说 BER 等于 0。

`-17 dB` 为零误码、`-16 dB` 出现 1 bit、`-15 dB` 又为零，是有限蒙特卡洛样本造成的轻微非单调，不代表物理性能反向变化。

### 9.4 多普勒误码地板

在 `-15 dB`：

- 未补偿 BER：`0.07643`；
- 静态前导 PREC BER：`0.06092`；
- 检测符号导频 BER：0 个观测错误。

未补偿和静态补偿即使提高 SNR 仍存在误码地板，因为问题来自随时间变化的频偏，不是噪声。静态 CFO 只能延后错误，不能跟踪后续变化。

## 10. 与用户截图的逐符号结果对比

截图条件为 `SF11, BW=250 kHz, 500 Hz/s`，虚线前导/载荷边界约在 8.5，原始 SER 在第 16 个符号开始突变。

本次复现得到：

- 第 15 符号：`epsilon=0.469762048 bin`，加噪原始 SER 约 `0.287`；
- 第 16 符号：`epsilon=0.50331648 bin`，加噪原始 SER 约 `0.497`；
- 第 22 符号以后：原始 SER 接近 1；
- 原始 BER 最终稳定在 `1/11=0.090909`；
- 正确符号上界补偿在 600 次试验中无观测错误。

截图的无噪理论红线在第 16 个符号从 0 直接跳到 1。本代码加入 AWGN 后，红线在半 bin 附近平滑过渡，这是合理现象：接近 0.5 bin 时两个相邻 FFT 峰幅度接近，噪声决定某次试验落在哪个峰。

截图标题包含 `No Payload Tracking`，其蓝线后期仍缓慢上升。本实现按用户要求加入了 payload 正确符号跟踪，所以蓝色上界保持在零计数显示下限，优于截图中的无载荷跟踪方法。组会中应表述为“理论错误边界成功对应，并在此基础上实现了进一步的载荷正确符号跟踪”，不要说两条蓝线数值完全相同。

## 11. 正确/错误/置信标志图分析

示例包含 21 个完整编码 payload 符号：

- 所有硬判决均正确，因此 `CorrectFlag=1`、`ErrorFlag=0`；
- 严格全局阈值选出 4 个 `ConfidentFlag`；
- 置信精度为 1.000；
- 覆盖率为 `4/21=0.1905`；
- false accept 为 0。

覆盖率低于 1 是算法有意的保守行为。`ConfidentFlag=0` 不表示该符号错误，只表示它没有达到作为软导频的可靠度要求。

主 BER 跟踪使用局部块阈值，`-15 dB` 平均覆盖率约为 0.2107。也就是说每个 7 符号块通常只选少量最可靠符号，避免把全部硬判决都用于更新。

## 12. 可以在组会上给出的结论

可以明确陈述：

1. 成功复现 SF11、250 kHz、500 Hz/s 条件下第 16 符号跨越半 bin 的理论错误边界；
2. 成功实现连续 LoRa 序列的 `CorrectFlag`、`ErrorFlag` 和接收机侧 `ConfidentFlag`；
3. 成功把检测出的置信符号作为软导频，用 0.1 bin PREC 残差更新下一符号 CFO 和累积相位；
4. 在变化率 `250...750 Hz/s`、平坦多普勒 + AWGN 信道下，`-15 dB` 的 145200 bit 仿真验证 BER 低于 `10^-4`；
5. 动态置信导频明显消除了未补偿和静态补偿的多普勒误码地板。

不应过度陈述：

1. 当前没有复现 Rayleigh/Rician、多径或真实 UAV 信道；
2. 论文未公开 `amendLLR` 和 `channelSense` 的完整公式，本实现保留接口并采用可解释的 identity/迭代替代；
3. `CorrectFlag` 是仿真评价标签，真实接收机只能使用 `ConfidentFlag`；
4. 零观测错误不等于真实 BER 为零，应报告统计上限；
5. 本次成功复现的是正确符号检测和多普勒补偿功能及理论边界，不是论文全部硬件实验的逐点数值复刻。

## 13. 建议的组会汇报顺序

### 第 1 页：问题和目标

一句话：累积多普勒使 LoRa FFT 峰逐符号漂移，静态前导估计失效，因此要从 payload 中持续寻找高置信正确符号作为软导频。

### 第 2 页：信号和信道模型

展示 `r_m[n]` 公式，强调连续相位、多普勒变化率向量和复 AWGN。说明当前是单位增益平坦信道。

### 第 3 页：为什么第 16 个符号出错

现场计算 `Ts=8.192 ms`、`Deltaf=122.07 Hz`、每符号 `0.0335544 bin`，最后得到第 16 个符号 `0.50331648 bin`。

### 第 4 页：正确符号检测

展示 FFT 概率、Gray LLR、Hamming 软译码、`Conf=sum|LLR|^2` 和两级阈值。强调 `ConfidentFlag` 不依赖真值。

### 第 5 页：预测补偿闭环

用流程图讲：8 个前导初始化 -> 最小二乘预测 -> 相位/CFO 补偿 -> 置信符号检测 -> PREC 残差 -> 更新下一符号。

### 第 6 页：BER-SNR 图

先看理想线与理论线重合，证明 LoRa AWGN 仿真正确；再比较未补偿、静态、检测导频和真值上界；最后给出 `-15 dB, 145200 bit, 0 errors, 95% upper=2.06e-5`。

### 第 7 页：逐符号图与截图对比

指出第 16 个符号理论边界完全一致；解释 AWGN 使阶跃变为平滑过渡；解释本实现有 payload tracking，所以补偿曲线优于截图的 no payload tracking。

### 第 8 页：结论和下一步

结论是正确符号检测驱动的动态补偿有效。下一步应加入 Rician/多径信道、真实 LoRa 对角交织、论文未公开的 `amendLLR/channelSense` 细节以及 SDR 数据验证。

## 14. 现场可能被问到的问题

### 为什么 `-15 dB` 还能做到很低 BER？

因为横轴是时域单采样 SNR，SF11 的 2048 点解扩/FFT 带来约 33.11 dB 符号能量增益。它不是未扩频系统的 `Eb/N0=-15 dB`。

### 为什么原始 BER 最后只有约 0.091，而 SER 是 1？

频偏主要把符号推到相邻 FFT bin。相邻 LoRa Gray 码通常只差 1 bit，所以每个错误符号平均错 1/11 的 bit。

### 算法是否知道真实多普勒变化率？

不知道。变化率只用于生成信道。接收机只看到 IQ 样本，并从前导和置信 payload 的 PREC 残差估计下一符号。

### 为什么不用所有判决符号更新？

错误符号一旦作为导频，会把错误 CFO 和相位写入历史并造成连续发散。置信阈值用覆盖率换取高精度。

### 为什么同时画实际曲线和 oracle 曲线？

实际曲线反映完整接收机性能；oracle 曲线隔离了置信检测错误，用来判断性能差距究竟来自错误导频还是频偏估计器本身。

### 当前信道是否完整？

当前包含连续相位多普勒和复 AWGN，但不包含幅度衰落与多径。它适合验证理论边界和算法闭环，不等同于完整外场信道。
