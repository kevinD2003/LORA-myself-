# 进度记录：动态 Doppler BER Smoke

## 2026-07-31

- 检查 GitHub 仓库默认分支、权限和最近提交。
- 在隔离浅克隆中确认 `main` 状态干净。
- 确认远端尚未包含前四轮动态 Doppler 文件。
- 读取前四轮 13 个 MATLAB 文件、两份测试结果和全部指定 CSV/JSON。
- 确认场景端点来自 shared visibility window，而不是论文近似常数。
- 用户批准建立开发分支并迁入现有已验证实现。
- 已创建分支 `codex/dynamic-doppler-ber-smoke`。
- 已完成并提交中文 BER smoke 设计规范，提交为 `b5c1905`。
- 用户已批准设计规范。
- 已完成逐步骤中文实施计划，覆盖迁入、配置、fixed BER、
  exact/continuous 模式、runner、24 点 smoke 和最终回归。
- 按 SHA-256 原样迁入 13 个前四轮文件，33/33 原动态测试通过。
- 配置 TDD：观察 2 项 UndefinedFunction RED，随后 2/2 GREEN。
- fixed BER TDD：观察 3 项 UndefinedFunction RED，随后完成完整时域
  批处理、自然二进制统计和双随机流。
- exact/continuous TDD：观察 4 项预期 RED，随后完成 exact 字段选择、
  跨批时间推进和梯形相位边界连续性。
- runner TDD：观察 UndefinedFunction RED，随后生成 CSV 和中文报告。
- 为 fixed 模式增加受批上限约束的相位模板缓存，11 项 BER 测试保持通过。
- 中文报告换行缺陷先由新增测试观察 RED，再修正为平台无关 GREEN。
- 实际运行 24 点 smoke 两次；最终一次与当前源码完全对应。
- 最终验证：51/51 测试通过，Code Analyzer 0 问题，24 行数据无坏行。
- 已生成 `dynamic_doppler_ber_smoke.csv`、
  `dynamic_doppler_ber_smoke_report.md` 和
  `test_dynamic_doppler_ber_results.txt`。
