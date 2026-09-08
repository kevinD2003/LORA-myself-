# 任务计划：动态 Doppler BER Smoke

## 目标

在 Git 开发分支内复用前四轮轨道与 Doppler 函数，建立完整时域动态
Doppler BER 引擎，运行 24 个 smoke 点并生成中文报告。

## 阶段

| 阶段 | 状态 |
|---|---|
| GitHub 与本地目录只读审查 | 完成 |
| 前四轮接口、测试和数据审查 | 完成 |
| 中文设计规范 | 完成 |
| 用户审阅设计规范 | 完成 |
| 中文实施计划 | 完成 |
| TDD 实现 BER 引擎 | 完成 |
| MATLAB smoke 与完整回归 | 完成 |
| 输出、内存和单位审查 | 完成 |

## 约束

- 不重建轨道、可见窗口、Doppler 频率或场景选择函数。
- 不使用 AWGN order-statistic 算法生成动态 Doppler BER。
- smoke 主模式为 `fixed_orbit_start_independent_symbols`。
- 主模型为 `paper_piecewise_linear`。
- 不生成最终 Figure 17。
- 审查和报告文件使用中文。
