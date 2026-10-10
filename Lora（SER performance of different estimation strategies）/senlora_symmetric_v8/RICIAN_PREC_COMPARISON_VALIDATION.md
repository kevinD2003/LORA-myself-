# 既有 PREC V9 的同条件莱斯信道移植

状态：**20,000 个 PREC 帧已完成，两个 Case 的每个 SNR 点均为 1000 包；
接收机异常计数 0。完整输出独立核对通过，最终只读复审 PASS。**

## 范围

原样复用旧 AWGN 工程的 `v4HuangPrecUnifiedDecodeV9`，不是另写或调优
PREC。该入口以 8 前导观测的等尺寸 CFO 域似然选择原有分支：大 CFO
分支为 `v4HuangStaticDecode`，中心域为师兄来源的
`v4HuangPrecDecodeV3`。两个分支均对整个 payload 使用一个固定 CFO，
不使用 rate、payload 反馈、VP 或 Paper midamble。

这些接收机文件按旧 `parent_source_manifest.json` 校验 SHA-256，源码
不修改。图例标注“Existing Huang PREC V9”，不把既有适配入口冒充未改造
的文献原版。V8 的源码和 d0/d1 不变，已发现的 Paper 元数据问题也不在
本次移植中修补；Paper 曲线仍标注 adapted V6。

## 实验条件

- Case1 t0=-366 s；Case2 t0=0 s。
- SNR -30:1:-21 dB；每个 Case×SNR 1000 包，共 20,000 个 PREC 帧。
- SF12，BW/Fs=125 kHz，no-LDRO，CR3/Hamming(7,4)，112 数据符号。
- PREC 和 V8 同为 8 前导+112 数据，120 符号/3.93216 s，无空导频槽。
- packet-flat Rician K=10 dB，单位平均功率；AWGN 在衰落后加入，方差
  10^(-SNR/10)，不按每包功率归一化。轨道及样本相位使用原生帧生成器。
- 复用原生 V8 扫描种子根 1032900000，逐包重算 ledger 并核对
  payload/noise/channel seeds。直接调用同一原生帧生成器，没有新帧格式。
- 同帧 Ideal 与 V8 已有结果只读复用，不重新抽样；测试重建两个 Case
  在 -30/-21 dB 的已保存 packet1，并核对 Ideal 错误计数完全一致。
- Paper 自身仍有 37 个导频/157 符号，所以合并图保留 Paper 同帧 Ideal；
  不声称 Paper 与其余两个接收机在同一物理时间轴上运行。

控制器用 SNR 生成噪声，不以 SNR 或 Case 选择 PREC 接收分支。原有观测
接口中的 `noiseVariance` 用于软 Hamming 似然；当前 Raw SER 的硬 FFT
峰值判决不依赖该字段。沿用该接口不等于额外证明软解码完全没有真实
噪声方差先验，不用返回的 `usesSnrInput=false` 掩盖这个区别。

## 流程与结果记录

1. 验证既有 Native/Paper 完整结果、源码闭包、参数及输入 SHA-256。
2. 按相同三组种子生成原生 120 符号莱斯帧。
3. 仅将 observation 与固定 PHY config 传入唯一 PREC V9 入口。
4. 接收机返回后再用 truth 统计 112 个原始符号错误和 CFO RMSE。
5. 每 100 个新帧保存摘要复核的临时检查点，续跑拒绝不同源码/输入。
6. 固定完成全部 1000 包/点后输出逐包与逐点 CSV，并按包 cluster
   bootstrap 给出 PREC 和 PREC−同帧 Ideal 的 95% 区间。
7. 图仅连接原始点，不拟合、不平滑、不强制 SER 排序。

本任务不启动全轨 Formal，不修补或重跑既有 Paper/V8 接收机。

接入验证：两个新增 .m 文件 MATLAB checkcode 均为 0 findings；两个自动
测试通过。每点 2 包、共 40 帧烟测的 PREC 原始错误数为 3168，失败与
禁用输入标志为 0；再次调用成功读取同一检查点，完成数仍为 40，未重复
增加包数。接入阶段只读审计未发现待修
代码缺陷。完整 1000 包/点运行、汇总 CSV 和六张图均已完成，并通过下述
独立核对。完整输出审计未发现计数或图形问题，唯一指出的文档状态陈旧
问题已经更正；该文档修补及完整输出的最终只读复审已 PASS，无待处理
发现，不沿用接入阶段的状态。复审未重新运行仿真。

## 完整结果与独立验证

完整批处理以 exit 0 结束，20,000/20,000 帧完成。PREC 原始错误总数
**1,553,940**，Case1/Case2 分别为 **436,348 / 1,117,592**。
每个 Case 各评估 1,120,000 个数据符号。

独立 MATLAB 核对通过：

- 原始 CSV 20,000 行、汇总 20 行，每点包 ID 为 1:1000；
- 全部 SER 与错误数/112000 一致，配对差异与逐包数据一致；
- 源码与全部输入基线 SHA-256 匹配，结果 MAT 与检查点完全一致；
- 旧 Native 的种子、channel power、V8/Ideal 错误列逐项完全一致；
- 合并的 Paper/其自身 Ideal 错误列与旧输出逐项完全一致；
- 每帧 120 个物理符号，CFO RMSE 有限，异常与禁用输入标志为 0；
- CFO 浮点数写入 CSV 再读取的最大误差为 5.0e-12（相对误差
  4.96e-15），属于文本浮点表示精度；整数错误计数完全一致；
- 六张 PNG 已视觉检查，坐标、图例及版本/帧长度标注完整。

MAT 一致性指 MATLAB 加载后的所有结构字段与数组 `isequaln` 完全一致，
不要求 MAT 容器文件字节哈希相同；容器创建时间不同不会改变包数据。

| SNR dB | Case1 PREC 错误 | Case1 PREC SER | Case1 Ideal 错误 | Case2 PREC 错误 | Case2 PREC SER | Case2 Ideal 错误 |
|---:|---:|---:|---:|---:|---:|---:|
| -30 | 96587 | 0.862384 | 95814 | 111979 | 0.999813 | 96044 |
| -29 | 86317 | 0.770688 | 85812 | 111953 | 0.999580 | 87568 |
| -28 | 74440 | 0.664643 | 74056 | 111927 | 0.999348 | 76324 |
| -27 | 61892 | 0.552607 | 61592 | 111901 | 0.999116 | 61634 |
| -26 | 44675 | 0.398884 | 44394 | 111839 | 0.998563 | 44777 |
| -25 | 31797 | 0.283902 | 31589 | 111765 | 0.997902 | 31341 |
| -24 | 20734 | 0.185125 | 20598 | 111675 | 0.997098 | 19085 |
| -23 | 10686 | 0.095411 | 10651 | 111594 | 0.996375 | 11627 |
| -22 | 5930 | 0.052946 | 5939 | 111509 | 0.995616 | 7253 |
| -21 | 3290 | 0.029375 | 3268 | 111450 | 0.995089 | 3027 |

在 -21 dB，PREC−同帧 Ideal 的配对 SER 差异及 95% packet bootstrap
区间：Case1 为 0.00019643 [-0.00003571, 0.00043750]；Case2 为
0.96806250 [0.96194643, 0.97406696]。Case1 该点接近 Ideal；Case2
几乎所有符号判错，不能把“异常计数 0”解释成成功解码。

这是原样保留的固定 CFO 接收机在高 Doppler rate 的长帧条件下的实际
结果，不通过调 rate、VP 或 SNR 分支把它改成另一种方法。Case1 -22 dB
PREC 比同帧 Ideal 少 9 个原始错误，保留该有限样本差异，没有强制曲线
排序。也没有把 PREC 与 V8/Paper 的性能高低预先固定。

## 文件

独立结果目录：`results/senlora_symmetric_v8/case_snr_rician_k10_prec_comparison/`

- `RICIAN_PREC_RAW_PACKETS.csv`：V8、同帧 Ideal、既有 Paper/自身 Ideal
  与新增 PREC 的逐包原始错误数，以及 PREC 模式、CFO RMSE、失败标志。
- `RICIAN_PREC_SUMMARY.csv`：20 个单元的原始计数、SER 与区间。
- `RICIAN_PREC_CHECKPOINT.mat`、`RICIAN_PREC_RESULT.mat`：签名和完整数组。
- `RICIAN_PREC_CASE1_SER.png`、`RICIAN_PREC_CASE2_SER.png`、
  `RICIAN_PREC_CASE1_CASE2_SER.png`：PREC、同帧 Ideal 和理论线。
- `RICIAN_ALL_METHODS_CASE1_SER.png`、`RICIAN_ALL_METHODS_CASE2_SER.png`、
  `RICIAN_ALL_METHODS_CASE1_CASE2_SER.png`：加入 PREC 的完整方法对比。

```matlab
addpath('D:/codex/Lora（SER performance of different estimation strategies）/senlora_symmetric_v8');
output = runSenloraSymmetricV8RicianPrecComparison(WorkerCount=4);
```
