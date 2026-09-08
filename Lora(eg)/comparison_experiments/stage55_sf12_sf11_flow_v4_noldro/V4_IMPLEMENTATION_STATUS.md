# V4 实施状态

当前状态：R4 阶段 3R 两轮 calibration 均未通过，实施按阶段门停止。

- 唯一方案标识：`V4-noLDRO-plan-R3-project-aligned`；
- 外部 R3 方案与指定 SF11 project 是规范来源，目录内旧说明不得覆盖 R3；
- 阶段 1、2 审计通过；历史阶段 3 保持 FAIL；R4 冻结和新机制测试通过，但两轮新 calibration 均无候选通过两个 Case；
- calibration、validation、smoke、formal 必须在对应阶段门后独立运行；
- V2/V3/SF11 只读边界由 SHA-256 清单审计，不依赖 Git。

阶段 3R 审计结论为 `FAIL / DO_NOT_ADMIT_STAGE_4`；未运行新 validation、安全检查、smoke/formal，未进入实验 B。
