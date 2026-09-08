# 阶段 5 参数版本 1 失败记录

时间：2026-09-04（Asia/Shanghai）

参数版本 1 未冻结，也未进入正式实验。

- 独立 validation 误接纳率：0.028169。
- 独立 validation 覆盖率：0.079241。
- 预注册门：误接纳率不高于 0.02、覆盖率不低于 0.01。
- 失败机理：每 SNR 4 帧的 calibration 样本过少，且选择仅约束误接纳点估计，未约束统计上界；在 calibration 中满足点估计的门限未能稳定泛化到 validation。

参数版本 2 使用全新 pass-index 子域，增加 calibration/validation 帧数，并按 calibration 误接纳率的 95% Wilson 上界选门。该变更未参考任何正式 SER、V1/V2 正式结果或论文 marker。

