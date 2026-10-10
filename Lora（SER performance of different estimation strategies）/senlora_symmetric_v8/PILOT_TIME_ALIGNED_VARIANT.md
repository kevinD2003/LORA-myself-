# 导频时间对齐变体：六张图重新生成

用户已同意实现并明确标注这一变体。它不是论文原始第三种方法，
也不是把离线真实CFO送给接收机。原`senloraPaperMidamblePointDecode.m`
及旧结果保留不改，新增入口为`senloraPilotTimeAlignedDecode`。

## 统一流程

1. 从最后完整downchirp及112个已接收upchirp导频，各自用固定FFT16
   测量CFO。只读收到的波形，不输入轨道、SNR、真实符号或目标SER。
2. 将每个CFO关联到该已知chirp的相对帧中心时刻。一个数据符号先缓冲，
   等其右侧导频收到后，再用左右导频CFO估计数据中心CFO。
3. 权重只由帧布局的相对时间决定：首数据符号为5/9，其余为1/2；
   按频率模Fs的最短圆弧插值，避免Nyquist边界导致假跳变。
4. 使用这个中心CFO补偿一个完整数据符号，符号内部rate仍为0；
   在符号和中间导频时间段之间连续积分补偿相位，最后正常FFT/CR3解码。

这是接收机对观测CFO的时间插值，不是对SER数据拟合。不增加置信度门限、
rate-bank、轨道位置分支或高阶模型，也不通过改SNR/K或挑种子来贴合图。
时间插值隐式使用频率变化信息，因此标注`usesDopplerRate=true`，同时
`usesWithinSymbolRate=false`、`isOriginalPaperThirdMethod=false`。
末尾导频现在参与最后一个数据符号的对齐，不再是无效的终端观测。

## 不变项与开销

SF12、125kHz、无LDRO、CR3、112个数据符号不变；packet-flat Rician
K=10dB及AWGN不变。VP/PREC源码和冻结参数、独立理论都不改。
Native帧仍120T=3.93216s，变体沿用n_int=1导频帧234.25T=7.675904s。
这个额外导频、时长和一个导频的等待延迟不能隐藏成同一物理帧开销。
所有位置使用同一变体入口、同一参数集；Ideal只在接收机返回后离线运行。

## 验证

4项新测试和5项原始Paper回归测试均PASS。新测试覆盖正负分数CFO、
线性频率样本的中心对齐及5/9权重、末导频局部影响、Nyquist最短圆弧、
五轨道点无噪声零错和truth/SNR等额外字段不影响输出。三份新增/修改
MATLAB文件checkcode全部0 findings。旧Paper测试未改，原入口行为保留。

## 每点1000包及全部六图

运行：

```matlab
addpath('D:/codex/Lora（SER performance of different estimation strategies）/senlora_symmetric_v8');
runSenloraPaperPointFourCurves(Stage="CaseSnr",ReceiverMode="PilotTimeAligned",UseParallel=false);
runSenloraPaperPointFourCurves(Stage="Figure12",ReceiverMode="PilotTimeAligned",UseParallel=false);
```

输出到两个新目录，不覆盖旧图/CSV/MAT：

- `results/senlora_symmetric_v8/pilot_time_aligned_case_snr_rician/`：
  Case1、Case2与两Case合图；Rician -30:1:-21dB，20点×1000包。
- `results/senlora_symmetric_v8/figure12_pilot_time_aligned/`：
  AWGN、Rician及两信道轨迹合图；5个论文时刻/信道，10点×1000包。

四条曲线为PREC、用户VP、独立理论、明确标注的导频时间对齐变体。
原生PREC/VP/Ideal的同包30,000条基线只读复用，其签名、ID及种子核验
沿用已有保护；只重算变体及其同帧离线Ideal。新增结果列使用comparison/
aligned命名，不把变体写作paper曲线。原始错误计数决定SER，不拟合、
不平滑、不强制排序或非零。两信道轨迹保持Es/N0=15dB及
[-366,-274.5,-183,-91.5,0]s。

共享runner源码增加模式选择，因此旧版检查点签名不会与新版本混用；
修正前runner已保存至`audit/pilot_time_aligned_before/`用于恢复/差异核查。
接入烟测每点2包完成：Case-SNR40包，PREC/VP/变体错误数为
3168/1861/2688；Figure12共20包，为1218/53/140，接收异常0。
第一次烟测启动进程曾报Windows Heap corruption，未产生运行记录；
新进程重试正常完成并以0退出。烟测检查点状态摘要、源码/输入签名和
变体元数据核验通过；续跑结果完全不变，无重复加包。这些是接入烟测的
历史证据，不代替下文已经完成的1000包/点结果。

## 运行环境故障与串行接续

完整运行的并行池模式多次遇到Windows Heap corruption：4-worker运行
到1740包后退出；单计算线程重试启动阶段退出；1-worker模式完成至1840包
后退出。接收机错误标志仍为0，故障原因未独立定位。更换运行方式不等于
宣称MATLAB故障已修复。

为继续运行，driver新增`UseParallel=false`，使parfor在本地0-worker模式
执行，避免并行池；算法、参数、行顺序和seed不变。修改前driver和两份
检查点保存在`audit/pilot_time_aligned_before_serial/`。显式校验旧状态
摘要、旧driver副本/全部其他源码及输入签名后，仅更新driver源码hash与
状态摘要；Case-SNR1840行、Figure12 20行的所有计数/估计/完成标志均
逐项不变。该迁移有独立日志`PILOT_TIME_ALIGNED_SERIAL_MIGRATION.log`。
串行完整运行日志为`PILOT_TIME_ALIGNED_SERIAL_FULL.log`，不丢弃故障前包。

串行及重试又分别运行到2690、3390包后退出；Windows Application Error
记录MATLAB.exe/ntdll.dll、0xC0000374，尚不能由此判断故障根因。
因此使用既有`StopAfterPacket`按每点20包递增的短批次进程接续，单批
至多重试3次，每次仍经过同一源码/输入/检查点校验。它只是进程运行方式，
最终每点ID集合仍固定1-1000，不改算法、不挑种子、不丢弃已经完成的包。
对应日志为`PILOT_ALIGNED_BATCH_<Stage>_<limit>_<try>.log`。

## 全量结束后的核验

`audit/validatePilotTimeAlignedResults.m`检查两阶段30,000行、每点恰好
1-1000包且不重号、原始整数错误计数、SER分母112000、所有接收失败及
禁用输入标志、两信道配对种子、冻结原生基线、理论值和源码/输入签名。
它还比较CSV、结果MAT与检查点，并执行一次已完成断点续跑，要求状态
和逐包数据不变。核验会重新导出相同数据的六张图，不更改接收机源码。
该核验脚本checkcode为0 findings；这不代表全量数据已经核验通过。
全量核验已在2026-10-05 02:16完成，正常退出0，日志为
`PILOT_TIME_ALIGNED_FULL_VALIDATION_1.log`。两个阶段均PASS：Case-SNR
20,000行、20点，Figure12 10,000行、10点；每点恰好1000包，已完成续跑
不增加或改变包。源码/输入hash、状态摘要、CSV/MAT一致性、逐包冻结
基线、配对种子、理论值、失败和禁用输入标志均通过。接收失败0，所有
禁用输入标志false。MATLAB的堆损坏根因仍未定位，不宣称运行环境已修复。

## 完整结果（2026-10-05）

六张PNG已经生成并逐张视觉检查，均为四条指定曲线和原始点连线，未
拟合/平滑/强制非零/强制方法排序。最后的轨迹计算于02:14完成；全量
核验随后重新导出相同数据的全部六图。输出目录及文件名为：

- `pilot_time_aligned_case_snr_rician/`：`CASE1_FOUR_CURVES.png`、
  `CASE2_FOUR_CURVES.png`、`CASE1_CASE2_FOUR_CURVES.png`。
- `figure12_pilot_time_aligned/`：`FIGURE12_AWGN_FOUR_CURVES.png`、
  `FIGURE12_RICIAN_FOUR_CURVES.png`、`FIGURE12_AWGN_RICIAN_FOUR_CURVES.png`。
- 两目录均含`FOUR_CURVE_RAW_PACKETS.csv`、`FOUR_CURVE_SUMMARY.csv`、
  `FOUR_CURVE_RESULT.mat`与`FOUR_CURVE_CHECKPOINT.mat`。

轨迹SNR保持-21.12359947967774 dB。下表为时间对齐变体的真实计数，
每格均来自1000包×112符号=112000符号，理论不随轨迹位置修改。

| 时刻(s) | AWGN错误数 | AWGN SER | Rician错误数 | Rician SER |
|---:|---:|---:|---:|---:|
| -366 | 91 | 8.1250e-4 | 8358 | 0.0746250 |
| -274.5 | 96 | 8.5714e-4 | 7905 | 0.0705804 |
| -183 | 102 | 9.1071e-4 | 8300 | 0.0741071 |
| -91.5 | 88 | 7.8571e-4 | 7876 | 0.0703214 |
| 0 | 90 | 8.0357e-4 | 9681 | 0.0864375 |

AWGN理论为1.50310743607429e-4，Rician理论为0.0309640691298955。
AWGN的0秒点不再呈现旧即时导频CFO的10^-2级突增，但变体整体仍约为
理论的5.2-6.1倍；Rician约为理论的2.3-2.8倍。只能说这五个实际点改善
了原先高率端的形状，不能宣称严格平直、达到理论或成功复现原始论文。
用户VP保持冻结：AWGN五点SER为9.8214e-5至2.2321e-4，Rician为
0.0312768至0.0381161；不根据此次结果进一步改VP或PREC。

Case1/Case2的-21 dB端，变体SER分别为0.0726339/0.0649821，
VP为0.0313571/0.0288661，独立理论均为0.0284643。数据核验PASS不
代表各接收机都达到了理论性能，也不代表Rician下的所有有限样本差异
具有统计显著性。没有运行全轨Formal，也没有新增参数调优。

## 默认Paper输出兼容性修正

首次只读审计发现：共享runner新增模式/依赖签名后，默认PaperPoint若
仍写入旧目录，会拒绝已有旧签名检查点。这是运行器输出兼容性问题，
不是接收算法或30,000行结果的数据问题。

最小修正只将新版默认PaperPoint输出改为独立版本目录：

- Case-SNR：`paper_point_eq17_nint1_case_snr_rician_runner_v3/`。
- Figure12：`figure12_four_methods_nint1_runner_v3/`。

旧`paper_point_eq17_nint1_case_snr_rician/`和`figure12_four_methods_nint1/`
及其中完成的1000包/点结果均保留。新的Paper运行器签名为V3；Paper
解码器、帧布局和帧生成器都没有修改。时间对齐变体仍在原来的两个
独立目录，签名identity和所有科学参数不变。

修正前driver及两份已完成检查点保存在
`audit/pilot_time_aligned_before_paper_output_fix/`。已校验旧driver副本与
存储hash、全部其他源码/输入hash和状态摘要，显式仅更新变体结果及
检查点中的driver源码hash与状态摘要；20,000/10,000行的全部计数、
估计和标志逐项不变。迁移日志为
`PILOT_TIME_ALIGNED_OUTPUT_VERSION_MIGRATION.log`，driver checkcode为
0 findings。默认Paper两包/点回归烟测PASS：Case-SNR40行、Figure12
20行，接收失败和禁用输入标志均为0，新检查点写入两个V3目录。旧
Paper两个目录的14份文件hash逐一未变，原Paper解码器、帧布局与帧
生成器也与旧结果签名一致。

修正后再次核验完整30,000行、六图和不变续跑，两个阶段均PASS，正常
退出0，日志为`PILOT_TIME_ALIGNED_OUTPUT_VERSION_VALIDATION_RETRY_1.log`。
前一组命令因Windows对内联双引号的传参问题在进入烟测前退出；仅修正
调用方式，未因此修改MATLAB接收源码，也未删除相关失败日志。
针对默认输出兼容性这一发现的独立复审已完成：**PASS，无待处理发现**。
复审独立读取修正前后两份检查点，确认全部20,000/10,000行完成和数据
数组不变、仅运行器源码hash更新、输入和其他签名字段不变、状态摘要
正确，两份结果MAT与检查点完全一致。CSV逐点1000个ID、无失败或禁用
输入，V3命名空间及所有六张图/结果文件也已核查。首次审计的发现已
完成最小修正，不将首次FAIL记录改写为PASS。

本轮指定的六图/每点1000包任务完成，代码与参数不再调整。运行期间
MATLAB堆损坏的根因仍未定位；此次通过的数据核验和代码复审不等于
宣称运行环境修复，也不等于接收性能达到理论。全轨Formal未启动。
