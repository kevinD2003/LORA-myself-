# 论文 PREC 与 SenLoRa 对比说明

> 目录整理（2026-10-08）：[所属项目入口](../../README.md)。本文的 MATLAB 命令和反引号内的代码、数据及文档路径以该项目根目录为基准；历史数值和验收结论保留其原记录时间。

## 算法来源

项目内 `satelliteFig3PaperPrecDecode.m` 封装自以下师兄代码，不直接
`addpath` 整个师兄目录，避免脚本变量、同名函数和局部函数污染项目：

- `D:\codex\师兄代码\matlab\CFO相关\频移算法\PREC.m`
  - SHA-256: `3AB8FBC23C595485E0CC9E478223C1A4048BD034A666EE97D7499AF55DF77E98`
- `D:\codex\师兄代码\matlab\CFO相关\频移算法\卫星信道\卫星信道\MonteCarlo_BER_RMSE_PRC_EC_TQ28.m`
  - SHA-256: `85E657783A2A791DE2843526334DE6BBAD816CF2050E8D5A164A5D19A1C1CFD1`

这些文件中的 PREC/PRC 是脚本或脚本局部函数，无法从本项目直接按输入参数调用。
封装保持以下论文步骤：8 个前导复数平均、`eta=0:0.1:0.9` 相位旋转、全局最大
FFT 峰值、一次 CFO 估计、固定 CFO 补偿全部载荷、FFT 硬判决。没有引入轨道
先验、载荷反馈、虚拟导频、速率估计或真值输入。

## 信道选择

正式比较只使用当前 Figure-3 连续动态卫星多普勒：SF11、250 kHz、868 MHz、
550 km 和 15 度倾角。论文 PREC、无补偿和 SenLoRa 必须接收相同载荷、相同噪声
和相同轨迹。

论文 TQ28 数据只用于独立复现，不混入正式 Figure-3 对比。

## 连续相位假设差异

师兄的 TQ28 PRC 代码对每个 LoRa 符号重新使用局部采样下标，因此前导之间的 CFO
相位被重置，直接平均 8 个前导能获得约 9 dB 噪声抑制。当前信道保持跨符号连续
累积相位，8 个前导带有不同整体相位，直接复数平均会相消。

无噪声审计表明，严格论文估计的正负号和索引正确，但平均后的干净信号幅度约为：

- 高频偏场景：单前导的 14%；
- 高速率场景：单前导的 20%。

因此严格论文 PREC 在低 SNR 下可能发生整数 CFO 捕获错误。这是算法/信号模型
假设差异，不允许通过隐藏的相位对齐或非相干功率累加来修饰。如果以后增加适配版，
必须标为 `continuous-phase adapted PREC`，不得标为论文原始 PREC。

## 当前阶段入口

- 固定 CFO 对照：`test_stage46_paper_prec_reference`
- 连续相位假设审计：`test_stage47_paper_prec_continuous_phase`
- 双场景最小 BER：`run_stage47_paper_prec_vs_senlora_smoke`

Stage 47 仅用于接线和趋势检查，不是正式 BER 统计。正式累计必须另建结果目录，
不得复用原项目 Stage 45 checkpoint。
