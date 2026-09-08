# SF=11 Stage55 三方法公平对比结果

## 对比方法

1. Huang-PREC-CP：共同8 upchirp前导估计，payload期间冻结CFO。
2. SenLoRa Stage55 VP-quality：最终对话冻结的质量感知虚拟导频方法。
3. Paper Midamble-Point：论文分段常数方法的项目移植版本。

## 共同实验条件

- SF=11，带宽250 kHz，载频868 MHz，CR=3。
- 每帧保留704个信息位和112个数据符号。
- SNR为-21、-20 dB；3次独立完整轨次。
- payload seed基数2026551800；noise seed基数2026551900。
- 相同轨道、可见区、连续跨符号/跨帧Doppler相位。
- 相同ML-soft Hamming(7,4) delivered BER译码器。
- SER只统计112个原始数据符号。
- 所有方法处理完全相同的物理rx帧。

## Midamble移植

论文报告SF12、BW125 kHz时n_int=3。依据论文Eq. (19)，在其余
条件不变时：

    n_int proportional to B^2 / 2^(2*SF)

移植到本项目SF11、BW250 kHz：

    n_int = 3 * (250/125)^2 * 2^(2*(12-11)) = 48.

因此在第48、96个数据符号后插入两个纯upchirp。公共物理帧由120
增至122符号，时长由0.983040 s增至0.999424 s，开销为1.667%。
Huang与SenLoRa在接收算法中忽略这两个显式pilot；只有论文方法使用。

原论文初值来自最后同步downchirp；本项目帧没有同步downchirp。为了
保持三方法共同初始化，移植版使用最终Stage55相同的8-upchirp
Huang-PREC-CP bootstrap。此适配已明确记录，不冒充原论文帧结构。

## 区域汇总

| SNR | 区域 | 方法 | SER | Delivered BER |
|---:|---|---|---:|---:|
| -21 | 高频偏变化率 | Huang-PREC-CP | 0.48529 | 0.082963 |
| -21 | 高频偏变化率 | SenLoRa | 0.048784 | 0.00088178 |
| -21 | 高频偏变化率 | Paper Midamble-Point | 0.14713 | 0.019615 |
| -21 | 高频移 | Huang-PREC-CP | 0.073697 | 0.0044451 |
| -21 | 高频移 | SenLoRa | 0.048691 | 0.00084929 |
| -21 | 高频移 | Paper Midamble-Point | 0.057182 | 0.0015628 |
| -20 | 高频偏变化率 | Huang-PREC-CP | 0.42736 | 0.052502 |
| -20 | 高频偏变化率 | SenLoRa | 0.010330 | 0.000030879 |
| -20 | 高频偏变化率 | Paper Midamble-Point | 0.070523 | 0.0060181 |
| -20 | 高频移 | Huang-PREC-CP | 0.023560 | 0.00060758 |
| -20 | 高频移 | SenLoRa | 0.010718 | 0.000013244 |
| -20 | 高频移 | Paper Midamble-Point | 0.013476 | 0.000014900 |

## 结论

- 高频偏变化率区，两档SNR均满足：

      SenLoRa < Paper Midamble-Point < Huang-PREC-CP

  这一关系同时成立于SER和delivered BER。

- 高频移区三方法差距较小；Paper Midamble-Point仍明显改善Huang，
  SenLoRa整体最低或与Paper非常接近。

- Paper Midamble-Point使用固定已知pilot，性能稳定地位于静态PREC和
  质量感知SenLoRa之间；SenLoRa无需发送显式payload midamble。

- 新公共122符号帧对原冻结基线影响很小：SenLoRa最大SER差
  0.000636、BER差4.81e-5；Huang最大SER差0.00246、BER差0.00113。

## 主要输出

- results/final/sf11_stage55_three_method_ser_trajectory.png
- results/final/sf11_stage55_three_method_ber_trajectory.png
- results/final/sf11_three_method_region_summary.csv
- results/final/sf11_three_method_window_statistics.csv
- results/stage55_sf11_midamble_three_method_replay/
  fuxian_three_method_frame_records.csv
- results/audit.json

主结果目录只含两张PNG：SER与delivered BER。FIG版本同时保留，便于
MATLAB后续编辑。没有人为曲线拟合、结果缩放或按结果调节n_int。
