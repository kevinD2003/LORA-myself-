# 归一化 K=10 dB 实际接收机 SER 实验

本目录是独立的 SER-only 实验。它只读引用冻结的 PREC、V8 Symbol-VP / Rolling-N8、论文复现接收机与 V4 波形源码，并使用相邻 `normalized_k10_pdp_v1` 中已注册的归一化 Rician 信道。不会修改、重跑或覆盖 `all_curves_symbolvp_k10/results/formal1000` 中的冻结 AWGN 原始包。

固定边界：868 MHz、550 km、BW=Fs=125 kHz、CR3、112 数据 chirp、无 LDRO、V4 轨迹；原生帧 120 行，论文帧 SF7 为 129 行且导频间隔 12，SF12 为 157 行且导频间隔 3。Rician 信道固定为 K=10 dB、总平均功率 1、链路余量 0 dB、无逐包归一化，抽头延迟为 0/8/16/24/32 微秒，散射相对功率为 0.38/0.4535322280719623/0.12360195131516263/0.033685461414424/0.009180359198451017。

唯一主指标为译码前 FFT 硬判决 112 个数据 chirp 的 SER。CR3 编码结构仍由接收机内部使用，但新队列不计算、不保存、不汇总也不绘制 BER。任何接收机失败均计 112 个错误，不丢包、不补样。

## 预登记队列

- `gate100`：SF7/SF12 的 Case1、Case2、半轨 `t=0`，共 6 点 × 100 包；种子根 `3000000000`。仅检查结构、身份、连续种子、分母、有效输出与零失败，不以 SER 排序或论文阈值作为门限。
- `formal1000`：新 Rician 50 点 × 1000 包；种子根 `3100000000`。四个固定 MATLAB 分片，每 5 包原子保存。
- `pairedHalf100`：两种 SF 各 100 个配对包 × 五时刻；种子根 `3200000000`。同一配对包在五时刻共享 payload、Rician 抽头及语义噪声，仅改变轨迹时间和确定性 V4 多普勒。该诊断从不与正式结果混池。

每个物理点同时运行 `prec`、`vp`、`paper`、`idealNative`、`idealPaper`。IdealNative 只对应原生帧；24 行论文验收仅使用 `paper` 和 `idealPaper`。

## 运行

在 MATLAB 中先固定计划：

```matlab
nkserExportPlan
```

四分片结构门和正式队列：

```powershell
./launchNkserShards.ps1 -Cohort gate100 -Workers 4
./launchNkserShards.ps1 -Cohort formal1000 -Workers 4
```

结构门完成后运行：

```powershell
python analysis/nkser_aggregate.py gate100
```

配对诊断按 SF 独立运行：

```matlab
nkserRunPairedHalf(7)
nkserRunPairedHalf(12)
```

正式汇总及绘图：

```powershell
python analysis/nkser_aggregate.py formal1000
```

```matlab
plotNkserResults
```

最终汇总只在表格层拼接 50 个冻结 AWGN 点和 50 个新 Rician 点；两边的原始包、断点、种子与身份始终分开。`ENDPOINT_24_ACCEPTANCE.csv` 分别给出名义比较和逐点单侧 95% 比较；不得将 24 个逐点结论表述为同时 95% 非劣。论文数值来自 PDF 矢量曲线读图，当前没有冻结的读图误差区间，因此读图误差与包抽样不确定性必须分开报告。
