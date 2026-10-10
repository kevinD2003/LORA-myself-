# LoRa：不同估计策略的 SER 性能

本目录实现 `EXP1-SF12-ORBIT-POSITION-V2`：在冻结的 SF12、125 kHz、no-LDRO、CR3、112 数据符号、157T 共同时间轴和 AWGN 条件下，扫描五个轨道起点，比较 Huang/PREC、Paper Midamble-Point、Stage55 和 Ideal Doppler，并在三个预登记位置执行 `Stage55-VP-off` 消融。

## 当前状态

- G0 基线审计：`PASS_WITH_NOTES`，见 `audits/AUDIT_G0_BASELINE.md`。
- G1 Pilot：`PASS_WITH_NOTES`，5 个单元、1000 个配对包、0 失败。
- Formal：10 个单元、10000 个配对包、0 失败。
- VP 消融：6 个单元、6000 个配对包、0 失败；与 Formal 对应包逐数组一致。
- G2 结果审计：`PASS_WITH_NOTES`，见 `audits/AUDIT_G2_RESULTS.md`。
- Mode-gate 探索：6 个单元、600 个 Formal 配对包，确认中间轨道退化主要来自硬门控；见 `results/exploration_mode_gate/EXPLORATION_REPORT.md`。
- Rate-aware gate v3：独立校准 200 包/单元、独立确认 100 包/单元；保持 `-366/-274.5/0 s`，显著改善 `-183/-91.5 s`，并保存全部 112 个数据符号的在线状态与离线残差；见 `results/rate_aware_gate/confirmation/RATE_GATE_CONFIRMATION_REPORT.md`。
- 父基线：`Lora(eg)/comparison_experiments/stage55_sf12_sf11_flow_v4_noldro`。
- 父基准 commit：`4d509fd5c2c6e0656916c4a8dd82a7ff56686f39`；实际执行身份为该基准加 `configs/parent_source_manifest.json` 锁定的本地依赖闭包。
- 冻结接收机：Huang V9、Stage55 V16、Paper V6；运行时校验完整 MATLAB 传递依赖闭包、动态 JSON 输入和 smoke 参考文件。
- 目标环境：MATLAB R2022a。

本工程只读引用父基线的 `config/`、`src/` 和必要脚本，不修改父代码，也不写入父结果目录。所有新结果只写入本目录下的 `results/` 和 `figures/`。

## 快速开始

在 MATLAB R2022a 中：

```matlab
cd('D:\codex\Lora（SER performance of different estimation strategies）')
addpath('scripts')
runExp1Tests
runExp1Smoke
```

后续阶段：

```matlab
runExp1Pilot       % 5 positions × -24 dB × 200 packets
runExp1Formal      % 5 positions × 2 SNR × 1000 packets
runExp1Ablation    % 3 positions × 2 SNR × 1000 paired packets
```

所有运行均支持断点续跑；已有单元只有在签名完全一致时才会复用。Pilot 与 Formal 使用不同随机包集合；消融使用 Formal 的同一包身份重新生成相同波形。

## 关键口径

- `t0` 是共同波形首样本的轨道时间。
- 共同时间轴为 `8 bootstrap + 112 data + 37 Paper midamble = 157T`。
- 普通方法共享 payload、噪声和连续 Doppler 相位；Huang/Stage55 跳过 midamble 时仍推进时间和相位。
- 主指标为 data-symbol SER。失败包按全部数据符号/信息位错误计入，不静默丢弃。
- 残余 CFO 在相同数据符号中心时刻计算。
- `Stage55-VP-off` 保留模式选择、联合前导初始化、初始 rate 和逐符号预测，只关闭 payload VP 更新。
- `-21.12 dB` 在本工程中是选定锚点；未重新核实 `Es/N0` 到采样 SNR 的全部口径前，不宣称严格复现论文 Fig.12。
- PER 定义为“该包至少有一个数据符号错误”；另保存 hard-bit packet error。

## 目录

```text
configs/   冻结实验配置、父源哈希和 seed 计划
src/       帧生成、接收机封装、统计与持久化
scripts/   smoke/pilot/formal/ablation、聚合和绘图入口
tests/     R2022a 回归测试
audits/    G0/G1/G2 审计材料
results/   分阶段结果；不会覆盖父实验
figures/   汇总图
```
