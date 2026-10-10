# Rician K=10 dB：Paper 第三种策略与冻结 V8 的比较

状态：**完整 20,000 个 Paper 帧已完成，20 个 Case×SNR 单元各 1000 包；
接收失败 0，禁用输入使用计数 0。冻结 V8 未改变，全轨 Formal 未启动。**

完整输出的最终只读审计：**PASS，无待处理发现**。审计独立复核了逐包/
逐点 CSV、计数归一化、失败与禁用标志、MAT/检查点一致性、三张图和
非 Ideal 接收机的 truth 隔离；没有重新运行仿真。

## 复用对象与边界

论文 Section VI-C.1、式 (17)/(18) 对应 Midamble-Point。此次按用户要求，
原样复用现有 AWGN 实验的 `v4PaperMidamblePointUnifiedV6`，并非重新选择或
调优算法。它是 **SF12/CR3/no-LDRO 适配版 V6**：静态分支调用整数 FFT、
分段固定 CFO 的 V4；动态分支调用已有局部细化、趋势预测、8 点历史和延迟
更新的 V3 文件（该文件输出算法标签为 local-trend-v5）。分支仅由前导观测
决定。趋势预测不是论文原始 Midamble-Point 的组成部分，因此图例明确标注
adapted V6，不能将其称为论文原版逐式复现。

未修改这三个接收机文件，也未修改冻结 V8 接收机、d0=0.10、d1=0.80。
没有使用 tuned/calibrated Paper 配置，没有重新选择 seed 或调 K 因子。

## 实验条件和配对

- Case1：t0=-366 s；Case2：t0=0 s。
- SNR：-30:1:-21 dB；固定每个 Case×SNR 1000 包，共 20,000 个 Paper 帧。
- SF12、BW/Fs=125 kHz、no-LDRO、CR3/Hamming(7,4)、16 block、112 数据符号。
- Rician（莱斯）K=10 dB；每包一个单位平均功率复系数，整包内保持不变。
- AWGN 在衰落后加入，固定噪声方差 10^(-SNR/10)，不按每包功率重归一化。
- 轨道与样本级相位积分使用上一轮的 `exp1TrackAOrbit`；不调用另一个
  轨道模型的旧 frame generator，以免偷偷改变信道定义。
- V8 保持 8 前导+112 数据的原生帧：120 符号，3.93216 s，无空导频槽。
- Paper 沿用 AWGN 适配帧：8 前导+112 数据+37 个显式 midamble；每 3 个
  数据符号插入符号 0，最后一个在数据 111 后；157 符号，5.144576 s。
  该适配帧没有论文原帧的同步 downchirps，不能声称原版空口格式完全一致。
- V8/Ideal 的既有 20,000 帧结果只读复用。种子根 1032900000 不变，
  payload seed、channel seed、native noise seed 逐包按原 ledger 重算校验。
- Paper 前导/数据的噪声按 **逻辑符号编号** 从原生 120×4096 噪声矩阵映射，
  不是用相同种子直接生成 157×4096 矩阵。新增导频使用独立的 SHA-256
  keyed noise seed；不会改变已配对的数据噪声。
- 因为插入导频会延长帧，后续数据的真实 Doppler 时刻不同。这里是
  同 payload/衰落/逻辑数据噪声的原生开销对比，不是同物理时间轴对比。
  图中额外保留 Paper 自己帧上的 Ideal，确保有真正同帧的参考。

论文没有给出完整衰落时间相关模型。packet-flat 是沿用前一轮的显式假设，
不是对未公开模型的猜测性宣称。论文条件中的 LDRO、CR1、120 bit payload
也不替换用户当前条件。理论线沿用独立无 Doppler Rician 积分，没有拟合。

## 接收流程

1. 按既有种子生成 112 个 CR3 payload 符号与一个 Rician 系数。
2. 只为 Paper 插入 37 个已知纯 upchirp；生成实际更长帧的 Doppler 相位。
3. 映射配对前导/数据 AWGN，再加入独立导频 AWGN。
4. 8 前导运行既有 `v4CommonBootstrap`，调用唯一 Paper V6 入口。
5. V6 用前导观测选择原有静态/趋势分支，因果更新 midamble，补偿 payload，
   `v4DecodePayload` 完成硬符号与 Hamming 解码。不传 orbit/Case/SNR/真实符号。
6. 接收机返回后才用 truth 统计 112 个原始符号错误和 CFO RMSE。
7. 最后运行 `exp1IdealDecode` 对 Paper 同帧作离线理想相位补偿参考。

## 完成证据

初次接入验证：三个新增 .m 文件的 MATLAB checkcode 均为 0 findings；两个
自动测试通过，覆盖噪声/衰落/payload 配对、导频位置与独立噪声、两个 Case
同一入口和同帧 Ideal 的无噪声解码。初次只读审计发现：基线汇总校验需要
显式拒绝 NaN，并按独立理论积分核对理论值。当前真实基线不存在这些异常。
已补充 `senloraSymmetricV8ValidateRicianReferenceSummary` 及对应回归测试。
该修补只改变输入校验，不修改任何接收或信道算法。

修补前的部分检查点保留在目录
`case_snr_rician_k10_paper_comparison_pre_audit_validation_fix_20261002/`。
最终运行从修补后的独立检查点重跑，不混合不同源码签名。

修补后四个 .m 文件 checkcode 均无 findings，三个自动测试通过。40 帧烟测
Paper/同帧 Ideal 错误数为 2812/1746，失败与禁用输入标志为 0；第二次调用
成功读取同一检查点，未新增包。针对实际修补 diff 的只读复审 **PASS**，
无待处理发现。代码审计 PASS 不替代 1000 包/点的结果验收；下述完整仿真
输出的独立核对现已完成。

完整批处理以 exit 0 结束，Paper/同帧 Ideal 原始符号错误总数为
**1,399,040 / 872,704**；按 Case 分别为 **636,122 / 433,830** 和
**762,918 / 438,874**。只读复用的 V8/原生帧 Ideal 为 **962,462 / 872,393**。
每个方法各评估 2,240,000 个 payload 符号。

独立 MATLAB 验证通过：

- 结果 MAT 与最终检查点所有字段完全一致；
- 源码闭包与输入基线的全部 SHA-256 均与当前文件一致；
- 原始 CSV 恰好 20,000 行，汇总 20 行，每个单元恰好 1000 包；
- CSV/MAT 错误计数一致，每个 SER 都是原始错误数除以 112,000；
- 每包 37 个显式导频，全部 CFO RMSE 有限，失败与禁用输入标志为 0；
- 理论参考全部有限且与冻结 Rician 积分一致；
- 归档的修补前 4540 帧与新运行对应帧的错误数、CFO RMSE、模式、导频数
  和导频噪声种子逐项完全一致，确认修补仅影响校验；
- 三张图已视觉检查，轴、图例和标签完整，无拟合、平滑或强制排序。

## 每点原始错误数与 SER

每行的 Case1 和 Case2 各为 1000 包，分母均为 112,000 个数据符号。
“Ideal”在本表专指 **Paper 自己帧上的 Ideal**；V8 与原生帧 Ideal 的全部
计数保留在合并 CSV 中，不用这张表混淆不同帧长的同帧关系。

| SNR dB | Case1 Paper 错误 | Case1 Ideal 错误 | Case1 Paper SER | Case2 Paper 错误 | Case2 Ideal 错误 | Case2 Paper SER |
|---:|---:|---:|---:|---:|---:|---:|
| -30 | 109893 | 95959 | 0.981188 | 111846 | 95996 | 0.998625 |
| -29 | 106624 | 85748 | 0.952000 | 111137 | 87565 | 0.992295 |
| -28 | 100707 | 74084 | 0.899170 | 109514 | 76245 | 0.977804 |
| -27 | 92343 | 61576 | 0.824491 | 104922 | 61531 | 0.936804 |
| -26 | 75339 | 44436 | 0.672670 | 95448 | 45039 | 0.852214 |
| -25 | 59724 | 31555 | 0.533250 | 80499 | 31354 | 0.718741 |
| -24 | 42240 | 20476 | 0.377143 | 60746 | 19302 | 0.542375 |
| -23 | 25383 | 10730 | 0.226634 | 42738 | 11608 | 0.381589 |
| -22 | 15269 | 5977 | 0.136330 | 29038 | 7211 | 0.259268 |
| -21 | 8600 | 3289 | 0.076786 | 17030 | 3023 | 0.152054 |

在 -21 dB：

| Case | V8 错误 / SER | 原生帧 Ideal 错误 / SER | Paper 错误 / SER | Paper 同帧 Ideal 错误 / SER |
|---:|---:|---:|---:|---:|
| 1 | 3512 / 0.031357 | 3268 / 0.029179 | 8600 / 0.076786 | 3289 / 0.029366 |
| 2 | 3233 / 0.028866 | 3027 / 0.027027 | 17030 / 0.152054 | 3023 / 0.026991 |

独立无 Doppler 理论在该 SNR 为 0.0284643。Paper−自身 Ideal 的配对 SER
差异及 95% packet bootstrap 区间为：Case1 0.0474196
[0.0415938, 0.0534152]；Case2 0.1250625 [0.1134107, 0.1375089]。
这些结果只描述用户条件下既有 **适配 V6**，不冒充论文 LDRO/CR1 原版结果。
所有 20 个点的 V8、Paper 和各自 Ideal 均非零；没有为确保非零追加抽样。

本轮没有调优 Paper 的趋势门限、更新延迟或 interval，也没有改变 V8。低 SNR
下 Paper 的高 SER 是实际误符号计数，不是异常接收时填充的错误数；异常
计数为 0。不能将这组曲线外推为论文原版策略在其原始 PHY 下的性能。

## 输出与复现

新结果目录为 `results/senlora_symmetric_v8/case_snr_rician_k10_paper_comparison/`，
不覆盖旧 Rician 图或数据：

- `RICIAN_PAPER_RAW_PACKETS.csv`：既有 V8/Ideal 和新增 Paper/同帧 Ideal
  逐包原始错误、种子、midamble 数、模式、失败消息与禁用输入标志。
- `RICIAN_PAPER_SUMMARY.csv`：每点计数、SER、Paper 95% packet bootstrap
  区间和 Paper−同帧 Ideal 的配对 packet bootstrap 区间。
- `RICIAN_PAPER_CHECKPOINT.mat`、`RICIAN_PAPER_RESULT.mat`：完整数据和
  传递源码闭包 SHA-256、输入基线 SHA-256。恢复时拒绝不同源码/输入；
  每 100 个新帧保存经摘要复核的临时检查点，再替换本任务的检查点。
- `RICIAN_PAPER_CASE1_SER.png`、`RICIAN_PAPER_CASE2_SER.png`、
  `RICIAN_PAPER_CASE1_CASE2_SER.png`：原始点连线，不拟合、不平滑、不强制排序。

```matlab
addpath('D:/codex/Lora（SER performance of different estimation strategies）/senlora_symmetric_v8');
output = runSenloraSymmetricV8RicianPaperComparison(WorkerCount=4);
```

这属于 SNR 曲线比较，不会启动此前单独规定的全轨 Formal。
