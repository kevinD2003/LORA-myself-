# 阶段 1 SF12-LDRO-CR3 审计

时间：2026-09-04（Asia/Shanghai）

结论：通过。

动态回归（MATLAB R2022a）：5 passed、0 failed、0 incomplete。

- 配置身份：`physicalSf=12`、`effectiveDataSf=10`、`dataAlphabetSize=1024`、`dataBinSpacing=4`。
- 1024/1024 合法逻辑标签逐个调制、4096 点 FFT、LDRO 区域聚合、硬判决和软 MAP 往返一致。
- 所有发射物理 bin 均为 4 的倍数。
- Hamming(7,4) 16/16 码字与 SF11 码表公式逐项一致。
- 16 个完整随机块（112 符号、640 信息位）硬 Hamming 与 ML 软 Hamming 无噪声往返一致。
- 无噪声、无 Doppler 的 SER、硬 BER、软 BER、PER 均为 0。
- 编码矩阵尺寸固定为 `10 x 7 x 16`，第 11、12 物理 bit 未进入 LDRO 数据码字。

静态回归：本阶段 V3 MATLAB 文件 Code Analyzer 为 0 问题。

边界审计：本阶段未实现或标定 bootstrap、Stage55/Paper 接收机、连续过境、门限或正式性能；未读取 V1/V2 正式结果。

