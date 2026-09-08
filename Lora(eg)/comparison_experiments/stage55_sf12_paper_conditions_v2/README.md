# SF12 论文条件下 Stage55 与 Midamble-Point 两方法对比 V2

本目录是独立第二版工程。第一版源码和正式结果保留在相邻目录
`stage55_sf12_paper_conditions`，两版检查点和结果不得混用。

本项目实现论文 SF=12、BW=125 kHz、Case 1/Case 2 条件下的两方法配对对比：

- `Paper-Midamble-Point`：使用 7 个有效 Midamble，末端第 8 个仅计 ToA；
- `Stage55-VP-quality-SER`：只使用 23 个 payload 判决形成的质量感知虚拟导频。

主指标是 payload SER 与逐符号 CFO RMSE。项目不实现或报告 CR1 BER/PER，
也不把本适配称为原生 SF11 Stage55 完整接收机。

## 运行顺序

在 MATLAB 中进入本目录后运行：

```matlab
addpath('config','src','scripts')
runSf12MechanismCalibration
runSf12Tests
runSf12Smoke
runSf12FormalComparison
buildSf12ComparisonReport
auditSf12Comparison
```

V2 在正式运行前先冻结并验证最终创新门限，再运行测试。
`runSf12FormalComparison` 默认执行方案规定的 2 Case × 10 SNR 配对 Monte Carlo，
计算量较大，并按每个 Case/SNR 独立写入 checkpoint。机制标定完成前正式入口会拒绝运行。

## 目录

- `config/`：冻结物理参数与 SF12 接收机参数清单；
- `src/`：公共帧、Point bootstrap、两种接收机和配对统计；
- `scripts/`：标定、冒烟、正式实验、报告和审计入口；
- `tests/`：物理链、公平性、随机账本和统计测试；
- `results/`：新实验输出，不覆盖 SF11 或论文独立复现结果。
- `V2修改与审计说明.md`：V1 问题、V2 修正范围和非目标。

详细结论边界见 [SF12论文同条件两方法对比报告.md](SF12论文同条件两方法对比报告.md)。
