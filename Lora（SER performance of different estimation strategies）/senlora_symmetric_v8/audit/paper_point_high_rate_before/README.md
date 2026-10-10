# SenLoRa Symmetric V8 当前状态与交接说明

更新时间：2026-09-28（Asia/Shanghai）

## 当前结论

当前最有希望的接收机是：

`senloraSymmetricV8JointBlockDecode.m`

它已经通过原机制种子的完整回放：9 个物理镜像对、每对 20 个配对包，
共 360 帧。最终原始符号错误数为：

| 接收机 | 错误数 / 总符号数 | SER |
|---|---:|---:|
| Joint-block V8 | 5 / 40320 | 1.24008e-4 |
| 原 V8 草稿 | 604 / 40320 | 1.49802e-2 |
| 同帧 V6-native | 6 / 40320 | 1.48810e-4 |
| 离线 Ideal | 4 / 40320 | 9.92063e-5 |

原 V8 在部分轨道点出现 6%--8% SER 尖峰。Joint-block V8 中最大单包错误
为 1 个符号；5 个不同包各贡献 1 个错误，其余包均为 0。Case1 和 Case2
镜像对均为 0 错。接收失败为 0，truth/orbit/case/SNR/target/midamble 使用
标志全部为 false。

独立 Review 已使用全新种子完成：9 个物理镜像对、每对 100 个配对包，
共 1800 帧。Review 原始错误数为 Joint-block V8/V6-native/Ideal =
20/20/16，对应 SER 为 9.92063e-5/9.92063e-5/7.93651e-5。
Case1 的 V8-V6 和 Case2 的 V8-Ideal 同包差异均为 0，配对 bootstrap
95% 区间均为 [0,0]；没有显著镜像差异或明显相邻点跳变。

Formal 尚未运行。Joint-block 已作为冻结实现接入正式
`senloraSymmetricV8Decode.m` 统一入口，`d0=0.10 bin`、`d1=0.80 bin` 和正式
源码已经冻结。当前只缺 Case2 V8−Ideal 的预注册绝对 SER 容差；该数值未
明确前不会启动 Formal。

## 不要混淆的实现

- `senloraSymmetricV8LegacyDecode.m`：修正过相位轨迹融合的原 V8 草稿，机制
  回放为 604 错，只保留为失败基线。
- `senloraSymmetricV8ResidualDecode.m` 和
  `senloraSymmetricV8ResidualReplay.m`：固定第一遍标签的残差回放实验。最优
  定向结果有改善，但仍产生镜像退化和大错误包，已判定不是完整解决方案。
- `senloraSymmetricV8JointBlockDecode.m`：正式 V8 入口调用的冻结实现，完整
  机制回放为 5 错。

`senloraSymmetricV8Decode.m` 已成为 Joint-block 的正式统一入口。失败的旧两遍
实现保存在 `senloraSymmetricV8LegacyDecode.m`，仅用于历史对照。

## 接收机边界

所有轨道位置使用同一入口、同一参数和同一流程：

- 原生帧：8 个前导 + 112 个 payload 符号；
- 无 Paper midamble 或空导频槽；
- 不输入轨道时刻、轨道位置、SNR、真实 Doppler、真实符号或目标 SER；
- Ideal 只用于接收结束后的离线比较；
- 不保留跨 block 的多分支，不做 rate-bank 分支拼接；
- 不使用二次或更高阶轨道模型；
- 所有反馈均来自接收机自身的 Hamming/CR3 解码和软信息。

Joint-block 接收机在每个 block 内会评估多个 CFO 残差候选，但这是一维联合
ML 搜索，不是持久分支：每个 block 只保留一个 CFO 和一个合法 Hamming
码字，其他候选立即丢弃，不会跨 block 拼接结果。

## 当前算法

### 1. 前导与第一遍

同一组 8 个前导生成 Static 固定 CFO 模型和 Dynamic 联合 CFO/rate 模型。
两条连续相位轨迹先在 payload 起点对齐，再按完整轨迹融合：

```text
predictedDrift = abs(rateHat) * nativeFrameDuration
gain = smoothstep(d0, d1, predictedDrift)

phaseV8(t) = phaseStatic(t)
             + gain * unwrap(phaseDynamic(t) - phaseStatic(t))
```

冻结值：

- `d0 = 0.10 bin`
- `d1 = 0.80 bin`

这两个值已随正式入口冻结。成功结果仍使用连续融合，并不是强制 `gain=1`
的纯 Dynamic 结果。

第一遍按该轨迹补偿完整 payload，并执行 Hamming/CR3 解码。

### 2. 第二遍 Joint-block CFO/Hamming ML

每个 7 符号 Hamming block 执行以下流程：

1. 在既有 `residualSearchBins` 中，仅保留 `innovationLimitBins` 范围内的
   CFO 残差候选；当前实际为 -0.5 到 0.5 bin、步长 0.05 bin。
2. 每个残差候选下重新补偿当前 7 个符号，计算符号软信息。
3. 对 CFO 残差和所有合法 Hamming 码字做联合 ML 评分。
4. 当前 block 只保留最高分的一个 CFO 和一个解码结果。
5. 只有软硬解码一致、码字 margin、decision peak ratio 和 CFO 搜索
   peak ratio 均通过既有门限时，该 block 才更新后续 block 的滚动
   CFO/rate 状态。

这一变化解决了原方案的死锁：当第一遍的当前 block 已因 CFO 漂移解错时，
不再要求它先产生正确 VP 才能恢复。Hamming 码约束可以协助当前 block
同时估计残余 CFO 和合法码字。

## 为什么原方案失败

原 V8 的大部分错误集中在少量失锁帧。360 帧中，16 帧贡献了 540/604 个
错误。前导联合 ML 在 payload 起点的 CFO 通常准确，但它估到的是前导时段
rate；在约 3.93 秒原生帧内，真实 rate 继续变化，一阶外推误差逐步增大。

固定第一遍标签的因果残差回放能修复有早期可信 VP 的帧，但一旦第一遍失锁
后没有合格 VP，就缺乏新观测。定向验证中，该方法把 14 帧从 315 错降到
127 错，但仍有 46 错的包，并把一个镜像包从 4 错退化到 27 错。因此没有
进入完整机制回放。

Joint-block ML 允许当前完整 block 使用 Hamming 约束恢复 CFO，打破了这一
观测死锁。

## 完整机制结果

结果目录：

`results/senlora_symmetric_v8/joint_block_mechanism/`

主要文件：

- `JOINT_BLOCK_RAW_PACKETS.csv`：360 帧逐包原始结果；
- `JOINT_BLOCK_RAW_POINTS.csv`：18 个原始轨道点；
- `JOINT_BLOCK_RESULT.mat`：完整数组；
- `JOINT_BLOCK_CHECKPOINT.mat`：完成检查点；
- `JOINT_BLOCK_RAW_POINTS.png`：原始点直接连接图，无拟合和平滑。

18 个位置中，以下 5 个位置各出现 1 个错误，其余位置为 0：

- -274.5 s
- -137.25 s
- 87.56784 s
- 224.81784 s
- 316.31784 s

每个非零点为 1/2240，即 SER 4.46429e-4。20 包条件下，0 与 1 个错误是
当前测量分辨率，不能解释成统计可信的反向突变。

其他机制指标：

- 最大单包错误：1；
- 最大被选 block 残差：0.25 bin；
- 最大单包 CFO RMSE：0.0487 bin；
- 每包最少通过质量门的 block 数：12/16；
- 接收失败：0；
- 禁用信息使用标志：全部 false。

## 验证状态

已完成：

- MATLAB 静态检查通过；
- 独立 block 解码器与 `v4DecodePayload` 在相同补偿样本上的硬符号、硬
  Hamming 位、软 Hamming 位和重编码符号一致；
- 定向 7 个最坏包及同种子镜像包：315 错降为 0 错；
- 完整原机制种子：604 错降为 5 错；
- 独立 Review 新种子：Joint-block/V6-native/Ideal 为 20/20/16；
- Review Case1 与 Case2 配对差异均为 0，95% 区间均为 [0,0]；
- Review 镜像显著差异数为 0，相邻明显跳变数为 0；
- 最终 MAT 与检查点关键数组完全一致；
- 机制 360 条、Review 1800 条逐包记录及各自 18 条轨道点记录完整。

MATLAB 在两次批处理结束、结果已经保存并打印后出现过 Windows
`0xc0000374 Heap corruption` 退出异常。随后独立加载并核对检查点、MAT、CSV
均通过，因此这不是接收机失败或结果丢失。后续长任务仍应依赖检查点，并
避免在退出前打印大型 table。

## 后续顺序

独立 Review 已完成并通过预定退化检查。下一步必须先做冻结决策，不能直接
以候选文件名启动 Formal：

1. 明确 Case2 V8−Ideal 的预注册绝对 SER 容差；
2. 建立只接受第三组未见 Formal 种子的 runner；
4. Formal 使用 9 个镜像对、每对 1000 包，共 9000 个配对包；
5. 保存完整检查点和传递依赖 SHA-256；
6. 执行成对包 cluster bootstrap，独立检查 Case1、Case2、镜像一致性和
   曲线形状。

Review runner 已使用 `matlab.codetools.requiredFilesAndProducts` 加显式关键
依赖记录完整源码闭包，并记录实际 `searchStepBins` 与参数 JSON 的 SHA-256；
恢复时会拒绝源码或参数证据不一致的检查点。

## 文件索引

- `senloraSymmetricV8Config.m`：V8 计划与冻结 `d0/d1`；
- `senloraSymmetricV8GenerateFrame.m`：原生帧生成；
- `senloraSymmetricV8BlendBootstrap.m`：完整相位轨迹融合；
- `senloraSymmetricV8Decode.m`：冻结后的正式统一 V8 入口；
- `senloraSymmetricV8LegacyDecode.m`：原 V8 草稿/604-error 失败基线；
- `V8_FROZEN_RECEIVER.md`：正式入口与冻结记录；
- `v8_frozen_receiver_manifest.json`：机器可读冻结清单；
- `senloraSymmetricV8BlockLikelihood.m`：单 block 软 Hamming ML；
- `senloraSymmetricV8JointBlockDecode.m`：正式入口调用的冻结 Joint-block 实现；
- `runSenloraSymmetricV8JointBlockValidation.m`：完整机制回放入口；
- `runSenloraSymmetricV8JointBlockReview.m`：独立 Review 入口；
- `senloraSymmetricV8ReviewSignature.m`：Review 源码与参数依赖签名；
- `plotSenloraSymmetricV8ReviewLogSer.m`：Review 的负轨半边 `10^-5`–`10^0` SER 图，零点不连线；
- `plotSenloraSymmetricV8FivePointReview.m`：指定五个负轨点的 SenLoRa、同帧 Ideal 与独立精确理论线；
- `CURRENT_CODE_DETAILED_FLOW.md`：当前 Joint-block 代码详细流程；
- `JOINT_BLOCK_MECHANISM_VALIDATION.md`：机制结果摘要；
- `JOINT_BLOCK_REVIEW_VALIDATION.md`：独立 Review 结果摘要；
- `FIVE_POINT_1000_VALIDATION.md`：五个负轨点各 1000 包的独立验证；
- `runSenloraSymmetricV8CaseSnrCurve.m`：两个 Case 的 `−30…−21 dB` 扫描；
- `CASE_SNR_CURVE_VALIDATION.md`：完整 SER–SNR 曲线结果；
- `senloraSymmetricV8GenerateRicianFrame.m`：每包平坦 Rician K=10 dB 信道帧；
- `senloraSymmetricV8RicianTheory.m`：无 Doppler Rician 理论 SER 积分；
- `runSenloraSymmetricV8RicianCaseSnrCurve.m`：Rician 条件下两 Case 的 SNR 扫描；
- `RICIAN_CASE_SNR_VALIDATION.md`：Rician 理论与实现结果及论文边界；
- `senloraSymmetricV8GeneratePaperRicianFrame.m`：仅 Paper 加入显式导频、复用原生帧数据噪声的 Rician 帧；
- `runSenloraSymmetricV8RicianPaperComparison.m`：复用 AWGN Paper adapted V6 的每点 1000 包 Rician 对比；
- `SenloraSymmetricV8PaperRicianTest.m`：数据/信道/噪声配对与统一 Paper 入口的自动测试；
- `senloraSymmetricV8ValidateRicianReferenceSummary.m`：拒绝缺失/非有限的基线参考点及被改写的理论值；
- `RICIAN_PAPER_COMPARISON_VALIDATION.md`：第三种策略的版本边界、配对方法与对比结果；
- `runSenloraSymmetricV8RicianPrecComparison.m`：既有 PREC V9 在原生莱斯帧上的每点 1000 包对比；
- `SenloraSymmetricV8PrecRicianTest.m`：PREC 冻结源码、无导频原生帧与同帧 Ideal 回放测试；
- `RICIAN_PREC_COMPARISON_VALIDATION.md`：PREC 移植条件、流程与计数验证；
- `senloraPaperMidamblePointDecode.m`：论文式(17)的即时、分段固定 CFO 方法，无 V6 趋势改造；
- `senloraPaperPointFrameLayout.m` 与 `senloraPaperPointGenerateFrame.m`：论文方法自有同步和导频帧，配对用户原生数据噪声；
- `runSenloraPaperPointFourCurves.m`：Case-SNR 与 Figure12 两信道四曲线、每点1000包入口；
- `SenloraPaperPointTest.m`：论文获取/更新机制、配对和理论测试；
- `FIGURE12_PAPER_POINT_PLAN.md`：取点、PHY适配边界、帧开销和验证记录；
- `RESIDUAL_REPLAY_TARGETED_VALIDATION.md`：被拒绝的残差回放证据。

## 重现当前机制结果

在 MATLAB 中：

```matlab
cd('D:/codex/Lora（SER performance of different estimation strategies）');
addpath('senlora_symmetric_v8');
output = runSenloraSymmetricV8JointBlockValidation(WorkerCount=2);
```

若源码签名与现有检查点一致，该命令读取完成检查点并重新生成汇总；若源码
已改变，runner 会拒绝不兼容检查点，不能把旧结果与新实现混合。

## 最新四曲线结果（2026-10-04）

论文Midamble-Point式(17)已加入现有Rician Case1/Case2曲线；两Case的
−30…−21 dB各点1000包，共20,000包。Figure12取点的AWGN/Rician轨迹
各5点、每点1000包，共10,000包。每张图只含PREC、VP、独立理论和
论文方法四条曲线，无拟合或强制排序，接收异常0、禁用输入全部false。
最终只读审计PASS，无待处理发现。源码/参数仍冻结，全轨Formal未启动。

输出目录为项目`results/senlora_symmetric_v8/paper_point_eq17_case_snr_rician/`
和`results/senlora_symmetric_v8/figure12_four_methods/`。原始错误计数、
完整验证证据、PHY/帧开销差异及审计边界见`FIGURE12_PAPER_POINT_PLAN.md`。
