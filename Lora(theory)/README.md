# 理论与历史实验

本目录包含早期 LoRa AWGN 实验、旧项目副本、理想 SER 独立实验及历史诊断材料。

| 内容 | 入口 |
|---|---|
| 独立理想 Stage55 条件 SER | [ideal_stage55_ser](ideal_stage55_ser/README.md) |
| 原始理论 BER 与基础仿真 | [reproduction_report.md](reproduction_report.md)；[LoRa_basic_report.md](LoRa_basic_report.md) |
| 旧连续过境工作副本 | [continuous_pass_prec_vs_senlora](work/continuous_pass_prec_vs_senlora/) |
| 旧 PREC/Stage55 副本 | [lora_prec](work/lora_prec/) |
| 早期师兄源码提取 | [senior_doppler_extract](work/senior_doppler_extract/) |
| 历史控制台与诊断日志 | [日志分类索引](logs/README.md) |
| 规范项目的现行入口 | [Lora(eg)](<../Lora(eg)/文件导航.md>) |

历史副本的代码、MAT 诊断文件和缓存位置保持原样。本次只整理根目录下无人引用的历史文本日志；`test_results.txt` 由基础仿真脚本生成并引用，保留在原位置。`.matlab_*` 和 `.repo-inspection/` 等环境资料保持原位置。
