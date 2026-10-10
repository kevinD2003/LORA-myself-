# Experiment B Stage55 CFO-bank revision v2

> 目录整理（2026-10-08）：[所属项目入口](../../README.md)。本文的 MATLAB 命令和反引号内的代码、数据及文档路径以该项目根目录为基准；历史数值和验收结论保留其原记录时间。

`Stage55-B-causal-CFO-bank-v2` changes only Stage55. Five predetermined initial CFO hypotheses `epsilonHatBins + {-2,-1,0,1,2}` run the same causal VP receiver in parallel. Each current D selects the branch with the highest current peak ratio for historical SER; each completed 7D CR3 block selects hard/ML bits using the highest receiver-visible Hamming ML score. No past SER is rewritten, no truth/future beyond the completed block is used, and Paper/Huang/conditions remain frozen.
