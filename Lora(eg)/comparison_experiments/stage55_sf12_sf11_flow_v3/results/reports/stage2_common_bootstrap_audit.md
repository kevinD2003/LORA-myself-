# 阶段 2 公共 bootstrap 审计

时间：2026-09-04（Asia/Shanghai）

结论：通过。

全量回归：9 passed、0 failed、0 incomplete。

- 共同入口严格要求 8 个完整已知 upchirp。
- 无噪声连续相位输入的 CFO 与速率绝对误差门均为 `2e-6`，符号起始相位误差门为 `5e-4 rad`。
- 三方法状态由同一个 bootstrap 结果复制，CFO 数组、相位数组和速率逐元素一致。
- bootstrap 输出明确记录 `usesPayloadTruth=false`、`usesOrbitTruth=false`。
- 接口输入仅为接收样本、V3 配置和显式搜索步长；无 Payload/轨道真值输入。
- 搜索步长仅是阶段 2 机制测试值，`receiverParameterManifest.json` 仍为 `unfrozen`，未越级冻结阶段 5 参数。

静态与边界审计：V3 MATLAB Code Analyzer 为 0 问题；34 个冻结 SF11 文件哈希不一致为 0；未读取 V1/V2 正式结果。

