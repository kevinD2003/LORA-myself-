# SF12 V3 与 SF11 规范项目的固定差异

本文件是长期报告必带内容，不得因流程对齐而删除。

| 项目 | SF11 规范主项目 | SF12 V3 |
|---|---:|---:|
| SF | 11 | 12 |
| 带宽/采样率 | 250 kHz | 125 kHz |
| 每符号采样数 | 2048 | 4096 |
| 符号时间 | 8.192 ms | 32.768 ms |
| FFT bin | 122.0703 Hz | 30.5176 Hz |
| LDRO | 普通 SF11 处理 | 开启，只允许 spacing-4 标签 |
| 有效数据位宽 | 11 bit | 10 bit (`SF-2`) |
| CR | 3 | 3 |
| Hamming 块数 | 16 | 16 |
| 信息位数 | 704 bit | 640 bit |
| 载荷符号 | 112 | 112 |
| 无 Midamble 帧时长 | 0.98304 s | 3.93216 s |
| Paper `n_int` | 48 | 3 |
| 112 符号内 Midamble | 2 | 38 |
| 主信道 | AWGN+Doppler | Rician K=10 dB+Doppler |
| 正式 SNR | 主要 -21、-20 dB | -30:-21 dB |
| Paper 初始化 | SF11 移植值 | 共同 8-upchirp bootstrap |

V3 Paper 分支固定称为 `Paper-Midamble-Point-SF12-CR3-adapted`，不能称为论文原条件复现。

