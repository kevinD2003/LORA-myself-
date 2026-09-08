# 任务计划：Doppler 近似验证

## 目标

实现并验证论文式（18）至式（20）的单符号及逐符号 approximation，
生成全部 MATLAB 图、CSV、JSON 和测试记录，不运行 BER。

## 阶段

| 阶段 | 状态 |
|---|---|
| 中文设计规范和实施计划 | 完成 |
| TDD RED：新增测试并观察失败 | 完成 |
| Figure 17 几何函数 | 完成 |
| 分段线性 approximation 核心函数 | 完成 |
| MATLAB 批量运行器及输出 | 完成 |
| 完整回归和 Code Analyzer | 完成 |
| PDF 回渲染与视觉检查 | 完成 |
| 原 AWGN 哈希及需求核验 | 完成 |

## 约束

- 目标目录：`D:\codex\lora(CFO)`。
- 不运行 BER。
- 不修改原 AWGN 函数。
- exact 路径使用完整 RF 瞬时频率。
- 审核及计划文件使用中文。

## 已遇到问题

| 问题 | 次数 | 处理方式 |
|---|---:|---|
| MATLAB MCP 会话在前期探算后失效 | 1 | 改用独立 MATLAB `-batch` 做只读探算 |
| 论文印刷回绕项与项目有符号速度方向相反 | 1 | metadata 同时记录印刷值和实际修正值 |
| 独立 MATLAB 退出时出现 Java shutdown 文本 | 2 | 结果有效；正式运行采用稳定测试入口并检查退出码 |
| MATLAB R2022a 的 `fromFile` 返回 `matlab.unittest.Test`，不能与空 `TestSuite` 拼接 | 1 | 使用 cell 收集后一次性拼接各测试套件 |
| AWGN 基准文件位于依赖仓库而不是 Doppler 输出目录 | 1 | 从 `D:\codex\Lora(theory)` 的实际路径计算并核对哈希 |
| `rg.exe` 在目标目录被系统拒绝执行 | 1 | 改用 PowerShell `Select-String` 完成只读需求扫描 |
