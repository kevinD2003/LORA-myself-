# 与当前 V4 Unified V23 项目的正式对比

> 本报告中的 Dietl 曲线使用历史21点质心解释。对论文“size 10”作
> 逐字十点修订后的 -21 dB 同帧结果见 `PAPER_10POINT_ALIGNMENT_REPORT.md`。

日期：2026-09-25。正式结果入口：`results/project_formal_v23_verified/`。

## 条件与公平性

- 当前项目物理层：SF12、125 kHz、关闭 LDRO、CR3；每帧112个数据符号、768个信息位。
- 两种场景：高频移（起点 -366 s）和高变化率（起点 0 s）。
- 每个场景在 -30 至 -21 dB 的10个 SNR 点各运行1000个配对包，共20,000帧。
- 项目基线为当前 V23 的 Huang V9、Stage55 V16、Midamble V6；论文方法为 Fixed LR 和 Adaptive LR。
- 三个项目基线使用已冻结的逐包结果；每格重新生成首包并逐项验证与原记录一致。两种 LR 在完全相同的接收 IQ 上运行。
- 每格从1000个包抽样2000次，形成以包为单位的95% bootstrap 区间。
- 缓存签名覆盖 V4 `src` 与 `config` 的全部 MATLAB/JSON 文件以及20格冻结逐包记录的内容哈希。

## 代表性结果

下表为 -21 dB，完整曲线和100行数据分别在 PNG、CSV 和 MAT 中。

| 场景 | 方法 | SER | hard BER |
|---|---|---:|---:|
| 高频移 | Huang V9 | 0.000071 | 0 |
| 高频移 | Stage55 V16 | 0.000071 | 0 |
| 高频移 | Midamble V6 | 0.001955 | 0.000533 |
| 高频移 | Dietl Fixed LR | 0.755589 | 0.132074 |
| 高频移 | Dietl Adaptive LR | 0.578277 | 0.118172 |
| 高变化率 | Huang V9 | 0.994500 | 0.296072 |
| 高变化率 | Stage55 V16 | 0.016313 | 0.000858 |
| 高变化率 | Midamble V6 | 0.043491 | 0.006091 |
| 高变化率 | Dietl Fixed LR | 0.748071 | 0.127115 |
| 高变化率 | Dietl Adaptive LR | 0.584080 | 0.115965 |

在高变化率 -21 dB，Dietl Adaptive LR 与 Stage55 的逐包配对 SER 差为
0.567768，95%区间为 [0.546737, 0.589152]；hard BER 差为0.115107，
95%区间为 [0.107178, 0.123391]。这两个区间均完全大于0。项目 Stage55
在该条件下也低于 Midamble V6。低信噪比段各方法的误差较高，不能把单个
SNR 点推广到整个可见轨次。

## 与旧冒烟实验的区别

早期 `results/project_comparison/` 仅每格30包，Huang 使用 V2 接口。
该数据不能代表当前 Unified V23；尤其高变化率 -21 dB 的 Huang V9 SER
为0.9945，与旧 V2 的约0.0818不同。正式结论以本目录的1000包 V23
对比为准。

## 论文锚点边界

论文原条件下的 Fixed LR coded BER 趋势已接近 Tables V/VI；标准 CRC
算得的 PLR 与论文表格差距很大。论文未公开足够细节来唯一确定其丢包
口径。本项目对比只比较同帧接收机的 SER 与 hard BER，不将论文 PLR
数值一致性作为隐藏前提。细节见 `RESULTS_REPORT.md`。
