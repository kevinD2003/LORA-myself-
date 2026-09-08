# Stage55 条件下的 SF11 Midamble-Point V2 移植说明

## 目标

本版本把独立SF11桥接实验中验证过的接收机机制移植到Stage55公共物理账本，
Stage55-VP-quality仍为主方法。现有`fuxianduibi`旧解码器、正式结果和审计保持冻结。

## 保持不变的Stage55条件

- SF=11、带宽250 kHz、载频868 MHz、CR=3。
- 704信息bit、112个数据符号、8个公共bootstrap符号。
- 相同轨道、连续Doppler相位、SNR、payload seed和noise seed。
- 第48、96个数据符号后插入两个纯上啁啾，`n_int=48`。
- 三种方法处理同一122符号物理帧；Stage55和Huang不使用显式Midamble。
- 公共ML-soft Hamming(7,4) delivered BER译码器。

## 移植的接收机机制

1. 显式Midamble继续使用Stage55现有原生残差估计器。
2. Midamble后的第一个数据符号仍使用旧估计，更新从第二个数据符号开始生效。
3. Piecewise-constant频偏更新、固定零速率和单位创新增益保持论文方法结构。
4. 不使用payload真值或轨道真值。

## 未移植的独立校准参数

独立SF11中的Rician K、Midamble估计SNR损失和SF7/SF12图像校准参数不写入
Stage55物理链。Stage55的信道和接收波形是公平比较的最高优先级。公共bootstrap
也继续使用Stage55八上啁啾估计，而不是改成论文最后同步下啁啾。

V2结果应同时记录：`sourceProfileFittedOrTuned=true`，表示机制来源包含校准实验；
`stage55ResultTuned=false`，表示没有使用Stage55输出反向选择参数。

## 入口和结果隔离

- V2解码器：`fuxianPaperMidamblePointDecodeV2.m`
- 四帧冒烟：`run_fuxian_v2_smoke.m`
- 正式重放和报告：`run_fuxian_v2_full.m`
- 后台日志入口：`run_fuxian_v2_full_background.m`
- 正式审计：`audit_fuxianduibi_v2.m`
- 完整重放调用原公共runner，并传入`PaperReceiverVersion="sf11_v2"`
- 所有V2结果必须写入新目录，禁止覆盖现有`results/final`和旧重放目录。

正式结果目录：

- 重放：`results/stage55_sf11_midamble_v2_three_method_replay`
- 报告：`results/final_sf11_receiver_v2`
- 状态与日志：`results/sf11_receiver_v2_run`
