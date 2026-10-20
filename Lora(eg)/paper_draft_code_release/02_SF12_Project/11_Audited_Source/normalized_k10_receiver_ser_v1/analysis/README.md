# 汇总产物

`nkser_aggregate.py` 不生成波形或替代观测，只验证并汇总现有证据。

- `SER_100_POINTS.csv`：100 个物理点的五方法宽表。
- `SER_500_METHOD_ROWS.csv`：100 点 × 5 方法的整洁 SER 表及逐点区间。
- `PAIRED_METHOD_DIFFERENCES.csv`：每点十种方法对的同包差值区间。
- `PAIRED_HALF_TIME_DIFFERENCES.csv`：共随机量半轨诊断相对 `t=-366 s` 的配对差值，并为三个实际接收机报告估计器均值变化。
- `ENDPOINT_24_ACCEPTANCE.csv`：2 SF × 2 信道 × 3 条件 × Paper/IdealPaper。名义与逐点单侧 95% 结论分列。
- `FAILURES.csv`：所有保留在分母中的运行失败；无失败时仍保留表头。
- `FAILURE_IDENTITY_SOURCE_SEED_MANIFEST.json`：冻结 AWGN 的 79 项身份、新 Rician profile/来源、种子与证据清单。
- `STATUS.json`：完成性、失败数、端点计数及统计解释。
- `figures/`：12 张 SER 的 PNG/PDF 和 `SER_OVERVIEW_12.png/.pdf`；不生成 BER 图。

非零结果采用包级 bootstrap。零观测错误保持实测 SER=0，图中的空心向下三角使用保守的包级单侧 95% 上界。论文读图数值没有冻结误差区间，不能把仿真区间解释为同时覆盖论文读图误差。
