# SenLoRa 轨道多普勒项目状态

> 规范位置：本目录是 2026-08-23 起唯一继续开发和运行回归的 Stage55 版本。
> 合并来源与备份位置见 `CANONICAL_PROJECT.md`。

更新时间：2026-08-11

## 当前目标与固定条件

- 单一地面设备；轨迹对应同一可见窗口，不是两个设备。
- 物理参数与 `D:\codex\lora(CFO)` 一致：SF=11、BW=Fs=250 kHz、fc=868 MHz、轨道高度 550 km、倾角 15°。
- Figure-3 动态多普勒包含逐采样频偏、频偏速率和跨符号连续累积相位。
- 两个场景：
  - 高频偏：`startTimeSec = -window.deltaTimeOutSec`；
  - 高速率：`startTimeSec = window.deltaTimeInSec`。
- 每帧 8 个已知零前导、112 个载荷符号；每个载荷符号始终由固定 8 槽 rolling 导频历史补偿，可靠虚拟导频逐个替换最旧前导观测。
- SenLoRa 软信息用于置信筛选；虚拟导频标签仍来自补偿后硬 LoRa 判决，最终交付 BER 改用原始 bit LLR 的 ML 软 Hamming(7,4) 译码，并保留硬译码审计分支。
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

- 该阶段最初在独立副本中完成；2026-08-23 已验证并合并到当前规范目录，
  后续不得再向原副本双向回写。
- 新增 `satelliteFig3PaperPrecDecode.m`：封装师兄代码中的论文公式（4-1）至（4-7）。
- 新增 Stage 46 固定 CFO 对照和 Stage 47 连续相位假设测试。
- 新增 `run_stage47_paper_prec_vs_senlora_smoke.m`，四条曲线为理论、无补偿、
  论文 PREC 和 SenLoRa rolling-8；所有接收机使用同一 Figure-3 信号与噪声。
- 固定 CFO 无噪声测试通过；论文 0.1-bin 相位旋转搜索的最大误差不超过 0.05 bin。
- 连续相位根因：论文/师兄仿真逐符号重置 CFO 相位，当前信道不重置；严格复数
  前导平均在两个场景只保留约 14%/20% 干净信号幅度，低 SNR 下可能错误捕获整数 CFO。
- Stage 47 一帧检查图只用于确认接线，严禁作为正式 BER 结论。
- 详细来源、哈希和实验边界见 `docs/PAPER_PREC_COMPARISON.md`。

## 2026-08-10 连续过境双算法阶段

- 实时状态与上下文恢复入口：`CONTINUOUS_PASS_IMPLEMENTATION_LOG.md`。
- 新主比较限定为 `Huang-PREC-static-CP` 与 `SenLoRa-VP`；旧Hard rolling-8不再作为论文主基线。
- 两者共享基于师兄黄鹏PREC/PRC的eta/FFT CFO估计；连续相位适配只把8前导直接复数平均改为逐前导FFT功率累加。
- 静态PREC忽略速率并冻结CFO；SenLoRa仅由已知前导相位初始化速率，随后由置信虚拟导频更新；两者均不使用轨道速率先验。
- Stage 48无噪声高速率机制检查：静态/SenLoRa CFO RMSE为 `0.759277/0.00684328 bin`，SenLoRa接纳52个载荷导频。
- 原Stage 1--47及新增测试共25项全部通过；Stage 48图不是正式BER。
- Stage 49新增连续帧绝对相位状态与完整过境调度：508个完整帧，其中432个完全可见、74个完全盲区、2个边界过渡。
- 5处边界的最大相位桥误差为 `7.75e-11 rad`；分帧与联合生成的相位/波形差均不超过 `6.98e-9`。
- Stage 50在 `-21 dB` 完整生成508帧并稀疏成对解码110个完全可见帧；主图横轴为轨道时间，通信曲线在中央盲区断开。
- Stage 50全可见稀疏样本中，静态PREC/SenLoRa总体BER为 `0.0380036/0.0403538`；在物理定义的高动态区（每帧漂移至少0.5 bin）为 `0.0892914/0.0336963`，SenLoRa的结构性跟踪收益已经可辨识。
- 低动态区静态PREC更好，必须保留并在正式重复过境统计中验证；Stage 50不是正式Monte Carlo，不得据此调门限或挑种子。
- SenLoRa接纳57个虚拟导频且真值审计误接纳为0；全过境模相位边界误差最大 `1.74e-11 rad`，时间误差最大 `4.03e-14 s`。
- Stage 51只依据解析Hamming AWGN理论在 `-23:-19 dB` 网格冻结固定SNR：主点 `-21 dB`（目标约 `1e-3`），补充点 `-20 dB`（目标约 `1e-4`）；接收机输出和随机数均未参与选择。
- Stage 52已实现可续跑的重复完整过境累计器；每SNR至少5次完整过境且两方法各至少300错误，不足则最多20次；置信区间按完整过境配对bootstrap。
- Stage 52真实单过境接线：`-21 dB` Huang/Sen总体BER为 `0.039865/0.040056`，`-20 dB` 为 `0.017101/0.014076`；仅为wiring，不能宣称显著性。
- 高动态区（每帧漂移至少0.5 bin）SenLoRa在 `-21/-20 dB` 的BER为 `0.046288/0.015604`，对应静态PREC为 `0.097466/0.048584`；低动态区静态PREC更好，正式报告必须同时保留。
- 单过境虚拟导频接纳/误接纳：`-21 dB` 为 `163/0`，`-20 dB` 为 `381/1`；共同初始化差为0，相位边界最大误差 `1.74e-11 rad`。
- 当前完整回归为30/30通过；下一阶段从新目录运行正式重复完整过境统计。

## 2026-08-10 Stage 53--54最终状态（覆盖上一条“下一阶段”状态）

- 正式重复完整过境结果位于 `results\stage53_formal_repeated_passes`；`-21/-20 dB` 均完成5次完整过境，每方法/SNR为 `1,520,640 bit`，满足至少300错误的预注册停止条件。
- 一次与Stage 52 wiring seed重叠的试跑已隔离在 `results\stage53_abandoned_seed_overlap_with_wiring`，明确禁止进入正式统计；正式seed基数改为并冻结为payload `2026150800`、noise `2026150900`、bootstrap `2026151000`。
- 成对过境BER差 `Huang-Sen`：`-21 dB = -0.002395`，95% CI `[-0.004144,-0.000646]`；`-20 dB = +0.002413`，95% CI `[+0.001367,+0.003404]`。
- 高动态区两SNR均为SenLoRa更好；低动态区两SNR均为静态Huang更好。该双向差异必须原样报告，不得改seed、平滑或调阈值制造单向结论。
- 全过境packet delivery（Huang/Sen）：`-21 dB = 136.99/112.75 bit/s`，`-20 dB = 339.95/309.22 bit/s`。SenLoRa的BER收益没有转化为总体PER优势，原因是误码分散到更多帧。
- Stage 54结果位于 `results\stage54_complexity_goodput`：Huang每帧精确200个2048点FFT；SenLoRa为552--1248个FFT并含LLR/软Hamming/残差投影，实测慢 `6.76--7.34x`，但两者均满足 `0.98304 s` 实时帧截止。
- 正式最大相位桥/传递误差 `1.7433e-11 rad`，最大时间误差 `4.0297e-14 s`；共同bootstrap与首载荷相位差为0。
- 最新完整回归：33/33个独立 `test_*.m` 全部通过。
- 最新恢复入口：先完整阅读 `CONTINUOUS_PASS_IMPLEMENTATION_LOG.md`，再读取本节、`results\stage53_formal_repeated_passes` 和 `results\stage54_complexity_goodput\STAGE54_COMPLEXITY_GOODPUT_REPORT.md`。

## 2026-08-10 Stage 55 修正接收机（新结果目录）

- Stage 53--54 产物保持冻结；Stage 55 修改接收机后只写入新目录，不得与旧结果续跑或合并。
- 虚拟导频 margin ratio 从 `0.25` 改为经独立门级审计的 `0.15`；完整 `-20 dB` 过境平均接纳 `6.7361` 个/帧，误接纳为 0。
- 新增因果跨帧 rolling-8 前导 CFO 状态，不用轨迹先验或载荷真值；独立测试中速率 RMSE 从 `0.5236` 降到 `0.0243 bin/s`。
- 修正速率释放接线错误：虚拟导频更新必须受配置的 `±0.1 bin/s` 偏离限制，不再误用 `±2.0 bin/s`。
- `-20 dB` 单次完整过境：`304128 bit`，硬/ML软 BER 为 `3.3210e-4 / 2.9593e-5`，CFO RMSE `0.058916 bin`，误接纳 0；rolling-8 热身后硬 BER `1.9370e-4`，与硬 Hamming 理论 `2.1650e-4` 同量级。
- `-21 dB` 单次完整过境：硬/ML软 BER 为 `5.6917e-3 / 1.0357e-3`，CFO RMSE `0.066967 bin`，误接纳 0。
- `-20 dB` 逐符号覆盖：每帧平均 `84.13/112` 个符号受至少一个新虚拟导频影响（`75.12%`）；每符号平均使用 `3.276` 个载荷虚拟导频；8 槽全部更新占 `13.72%`。无论更新程度如何，总活跃导频历史均为 8。
- 最新完整回归：`39/39` 个独立 `test_*.m` 全部通过；7 个修改后核心文件的 MATLAB Code Analyzer 均为 0 条警告。

## 2026-08-11 Stage55 虚拟导频严格消融

- `satelliteFig3SenLoRaIterativeDecode.m` 与 `satelliteFig3SenLoRaVirtualPilotDecode.m` 新增 `EnableVirtualPilots`；默认值为 `true`，原 Stage55 调用行为不变。
- 新入口 `run_stage55_vp_control_comparison.m` 对同一接收帧成对运行 `Stage55-NoVP` 与 `Stage55-VP`。两者共享噪声、轨道、前导码、跨帧状态、初始速率与最终 ML 软译码，唯一变量为是否允许载荷虚拟导频。
- 新结果位于 `results\stage55_vp_control_comparison`，包含逐帧、10秒窗口、112个符号位置、16个Hamming块位置的 SER/BER/PER/CFO 统计及四张高动态区域图。
- 1-pass、864个配对帧基线中，四组 VP SER 均比 NoVP 高 `1.38%--5.10%`，VP CFO RMSE 也均较高；部分区域的最终软 BER/PER改善。因此当前虚拟导频不能写成普遍优势，旧 Huang--Stage55 差异也不能全部归因于虚拟导频。
- 平均接纳 `3.30--7.15` 个虚拟导频/帧、误接纳为0、逐符号影响覆盖率 `53.4%--76.2%`。当接纳数为0时，两分支结果逐项完全一致，控制开关无泄漏。
- 详细边界、数值与复现命令见 `STAGE55_VP_CONTROL_COMPARISON.md`。全部8项Stage55测试通过（其中2项为本次新增）；全项目41项中39项可执行测试通过，另2项仅因本工作副本缺少整个冻结的 `results\stage53_formal_repeated_passes` 目录而无法读取旧MAT产物，不是本次代码回归失败。
