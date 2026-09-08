# 任务计划：Figure 17 正式动态 Doppler BER 扫描

## 目标

复用已验证的动态 Doppler BER 引擎完成论文参考配置下的正式 656 点主扫描，
并对 24 个指定点进行 paper/exact 严格配对抽查。

## 阶段

- [x] 复核 pilot 结果与现有 BER 引擎接口
- [x] 确认 paired exact 的共同批次停止规则
- [ ] 编写并提交中文设计文档
- [ ] 编写并提交实施计划
- [ ] 测试驱动实现正式配置、结果统计与配对抽查
- [ ] 运行 MATLAB 回归、正式主扫描与 exact 抽查
- [ ] 审核正式输出与差异分析

## 关键约束

- 主图：paper_piecewise_linear、fixed independent symbols、无干扰、无 Doppler 补偿。
- 主网格：SF5:12、SNR -30:1:10 dB、两个既有 shared-window 场景。
- 正式零错误记录为 BER=NaN，另保存 one_count_level 和 upper_95_approx。
- 所有输出保留原始 bit/symbol 误码计数与确定性分层种子。
- exact 抽查与 paper 模型每批使用同一符号和 AWGN，直到两者都满足各自停止条件。
- 不改变 AWGN 基准，也不改写轨道或 Doppler 物理模块。

