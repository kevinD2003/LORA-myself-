# SenLoRa 轨道多普勒项目状态

更新时间：2026-08-06

## 当前目标与固定条件

- 单一地面设备；轨迹对应同一可见窗口，不是两个设备。
- 物理参数与 `D:\codex\lora(CFO)` 一致：SF=11、BW=Fs=250 kHz、fc=868 MHz、轨道高度 550 km、倾角 15°。
- Figure-3 动态多普勒包含逐采样频偏、频偏速率和跨符号连续累积相位。
- 两个场景：
  - 高频偏：`startTimeSec = -window.deltaTimeOutSec`；
  - 高速率：`startTimeSec = window.deltaTimeInSec`。
- 每帧 8 个已知零前导、112 个载荷符号；rolling-8 指最近 8 个有效导频，并非固定第 5 个或固定载荷窗口。
- SenLoRa 软信息仅用于置信筛选；最终 BER 和虚拟导频标签均来自补偿后的硬 LoRa 判决及硬 Hamming(7,4) 译码。
- 接收机接口不接收载荷真值。真值只用于仿真误码、CFO 误差和误接纳审计。

## 正式 BER 定义

- SNR 网格：`-30:1:-14 dB`。
- 两个场景各绘制四条曲线：理论 AWGN Hamming(7,4)、无补偿、硬判决 PREC rolling-8、SenLoRa rolling-8。
- 每点达到所有仿真分支至少 300 个载荷 bit error，或达到 `1e7` payload bit。
- 用户允许结果达到 `1e-6` 后结束。实现采用可审计规则：两个场景的硬 PREC 与 SenLoRa 共四个分支，其单侧 95% BER 上界全部不大于 `1e-6` 时终止后续 Monte Carlo。
- 零错误点绘制精确单侧 95% 上界；只绘制原始 Monte Carlo 和置信区间，不拟合、不插值、不平滑。
- 理论曲线仍计算到 `-14 dB`；停止点之后的模拟值保持 NaN，CSV 标记为 `not_simulated_after_upper_target`。

## 最终 Stage 45 结果

正式目录：

`results\stage45_formal_ber_minus30_to_minus14`

关键结果：

- checkpoint：`terminationReached=true`，`terminationSnrIndex=13`，对应 `-18 dB`。
- `-20 dB`：
  - 理论 BER：`2.164999e-4`；
  - 高频偏 hard/Sen：`2.22401e-4 / 2.58806e-4`；
  - 高速率 hard/Sen：`1.98572e-4 / 1.98572e-4`。
- `-19 dB`，每场景 `10,000,320 bit`：
  - 理论 BER：`2.92780e-6`；
  - 高频偏 hard/Sen：`2.69991e-6 / 3.19990e-6`；
  - 高速率 hard/Sen：`4.59985e-6 / 3.09990e-6`。
- `-18 dB`：4256 帧、`2,996,224 bit`；四个补偿分支均为零错误，单侧 95% 上界均为 `9.998353848e-7`，完成原因为 `upper_95_at_or_below_target`。
- `-17` 至 `-14 dB` 未继续仿真，理论曲线保留。
- `-20/-19/-18 dB` 两个场景的 SenLoRa 误接纳数均为 0。
- 两场景公共噪声最大数值差：`2.8422e-14`。
- SenLoRa 接纳数量随 SNR 和场景变化，不是固定导频数。例如高频偏 `-22/-21/-20/-19/-18 dB` 分别接纳 `8/73/3815/48046/24932` 个。

主要产物：

- `formal_ber.png`、`formal_ber.fig`
- `formal_ber.csv`
- `formal_ber_latest.mat`
- `formal_ber_checkpoint.mat`
- `random_seed_ledger.csv`
- `MIGRATION_PROVENANCE.txt`

## 最终实现要点

- `generateContinuousSatelliteFrame.m`：逐采样轨迹、AWGN 和连续累积相位。
- `satelliteFig3Trajectory.m` / `satelliteFig3PiecewiseDoppler.m`：Figure-3 单可见窗口动态多普勒。
- `satelliteFig3RollingPilotTracker.m`：rolling-8、加权/Huber CFO-速率拟合、残差质量门、连续相位补偿。
- `satelliteFig3HardPrecDecode.m`：硬判决 PREC；与 SenLoRa 共用接收机可见的轨道速率先验和相同物理速率约束。
- `satelliteFig3SenLoRaIterativeDecode.m`：最多 5 次置信筛选与导频集合更新；完整 Hamming 块到达后才能因果地使用其置信结果。
- `satelliteFig3RateReplaySenLoRaDecode.m`：正式路径只有一个接收机可见轨道先验，不用载荷软分数在多条真值候选轨迹中择优。
- `run_stage26_formal_ber.m`：正式串行、可续跑、逐帧 checkpoint 入口。
- `run_stage44_parallel_formal_batch.m`：并行计算、主进程按帧序合并；与串行状态和 trace 精确一致。

## 验收证据

- 最新完整回归：全部 21 个测试函数通过。
- Stage 1：可见窗口、Figure-3 频偏/速率范围、无噪声信道和符号边界相位连续性通过；边界误差阈值 `1e-10 rad`。
- Stage 16：接收机补偿相位跨前导/载荷边界连续。
- Stage 23/25/27：正式四曲线接线、Hamming 理论和公共最终硬译码指标一致。
- Stage 30：SenLoRa 软信息只控制置信度，正式虚拟导频标签不使用软译码码字。
- Stage 31：置信结果严格因果，完整 7 符号 Hamming 块结束后才可加入历史。
- Stage 43：硬 PREC 与 SenLoRa 共用相同轨道速率先验和速率约束。
- Stage 45：95% 上界终止后不会继续运行后续 SNR，CSV 正确记录停止原因。
- 接收机主接口仅输入 `rxSymbols, config, knownWaveformBins`，没有载荷真值参数；正式 runner 的 `truth` 仅用于审计数组。
- Stage 39/41 已证明早期小样本中 SenLoRa 低于理论的点与同噪声的理想逐采样补偿完全一致，是有限样本波动，不是接收机获得了超理论物理增益。

## 后续继续开发规则

1. 先读取本文件及 `results\stage45_formal_ber_minus30_to_minus14`，不要从已废弃 Stage 26/32/34/40 统计继续累计。
2. 不得把旧诊断数据混入 Stage 45，不得改变随机种子后宣称同一正式实验续跑。
3. 修改接收机后必须新建结果目录并从零累计；保留迁移和算法签名。
4. 不允许为了曲线形状调种子、拟合、平滑或反向调门限。
5. 如果扩展到更低 BER，应提高比特预算并保留单侧置信上界规则；不能把零错误直接写成 BER=0。

## 2026-08-10 论文 PREC 独立对比阶段

- 本副本用于论文原始 PREC 与 SenLoRa 对比，不得回写或覆盖 `Lora(eg)`。
- 新增 `satelliteFig3PaperPrecDecode.m`：封装师兄代码中的论文公式（4-1）至（4-7）。
- 新增 Stage 46 固定 CFO 对照和 Stage 47 连续相位假设测试。
- 新增 `run_stage47_paper_prec_vs_senlora_smoke.m`，四条曲线为理论、无补偿、
  论文 PREC 和 SenLoRa rolling-8；所有接收机使用同一 Figure-3 信号与噪声。
- 固定 CFO 无噪声测试通过；论文 0.1-bin 相位旋转搜索的最大误差不超过 0.05 bin。
- 连续相位根因：论文/师兄仿真逐符号重置 CFO 相位，当前信道不重置；严格复数
  前导平均在两个场景只保留约 14%/20% 干净信号幅度，低 SNR 下可能错误捕获整数 CFO。
- Stage 47 一帧检查图只用于确认接线，严禁作为正式 BER 结论。
- 详细来源、哈希和实验边界见 `docs/PAPER_PREC_COMPARISON.md`。
