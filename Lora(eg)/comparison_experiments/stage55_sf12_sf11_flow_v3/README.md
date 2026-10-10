# SF12 Stage55 V3

[按功能查找源码](docs/code_index.md) · [文档索引](docs/README.md)

本目录把规范 SF11 Stage55 流程移植到 SF12/LDRO/CR3。它是独立实验工程，不能读取或续跑 V1/V2 检查点，也不能修改规范 SF11 工程。

三个正式方法名固定为：

- `Huang-PREC-static-CP-SF12`
- `Stage55-VP-quality-CR3-SF12`
- `Paper-Midamble-Point-SF12-CR3-adapted`

Paper 分支是 CR3、112 载荷符号、共同 8-upchirp bootstrap 和连续帧条件下的适配机制，不是论文 Figure 10/11 原条件曲线。早期 V2 论文条件锚点已在本次整理中移除，不是 V3 的运行依赖。

实施必须依次通过 `docs/design/V3_IMPLEMENTATION_PLAN.md` 中的阶段门。`src/upstream_sf11` 是只读来源快照；SF12 适配实现位于其他 `src` 子目录。

当前状态：阶段 0 至 8 全部完成，最终统一审计通过。正式报告入口为 `results/reports/V3_FINAL_REPORT.md`。
