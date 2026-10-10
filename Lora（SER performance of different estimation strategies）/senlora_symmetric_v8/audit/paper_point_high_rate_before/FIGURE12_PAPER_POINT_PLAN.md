# Figure12 四曲线与论文 Midamble-Point 接入

本任务保留用户 PHY：SF12、125 kHz、无 LDRO、CR3、112 个数据符号。
VP 指冻结 `senloraSymmetricV8Decode`（d0=0.10、d1=0.80）；PREC 指既有
`v4HuangPrecUnifiedDecodeV9`。二者源码均按冻结清单校验，不修改。

## 论文第三种方法

新增入口 `senloraPaperMidamblePointDecode` 实现论文 Section VI-C.1、式
(17)/(18)：最后一个完整 downchirp 获取整数 FFT CFO；每个已知 upchirp
midamble 估计残差并直接累加 CFO；立即用于之后的数据，段内 CFO 固定。
不包含可观测模式切换、rate 拟合、历史趋势、亚 bin 细化、门限、延迟更新
或 payload 反馈。旧 adapted V6 保留，不作为本次论文曲线的来源。

论文方法自己的帧含 8 upchirp、2 downchirp、0.25 downchirp 同步时间、
112 数据及 ceil(112/3)=38 个 midamble。最后一个终端导频不影响 payload。
完整符号数 160，总时长 160.25T=5.251072 s；接收端观察 160 个完整符号
和独立保存的同步 quarter。VP/PREC 仍是 120T=3.93216 s 原生帧，无导频。
因此这是按原生开销对比，不是假称同一物理帧长。

各方法使用同一 payload、莱斯系数、按逻辑符号映射的前导/数据噪声；
论文方法额外 downchirp/midamble/quarter 噪声由独立 keyed seed 生成。
Rician 为既有 packet-flat K=10 dB、E|h|²=1 假设，不用 measured-power
归一化。SNR 控制生成器，不以轨道位置、Case、目标 SER 或真实 Doppler
选择接收策略。Ideal 在真实接收机返回后运行，仅保存作离线核对，不画为
第五条曲线。

## 图与包数

1. Case1/Case2：在现有 Rician -30:1:-21 dB 数据上加入新的 Eq17 方法。
   VP/PREC/同帧 Ideal 的既有 20,000 个原生包只读复用；新增论文帧各点
   1000 包。新图只画 PREC、VP、独立理论和论文 Eq17 四条曲线。
2. Figure12 取点：[-366,-274.5,-183,-91.5,0] s，时刻标签与论文相同。
   E_s/N_0=15 dB；SNR 精确按 15-10log10(4096)=-21.12359948 dB
   换算，不复用 -21 dB 曲线当作这个条件。
3. AWGN 与 Rician 分别生成轨迹图；每信道每轨道点 1000 包，共
   10,000 个 native/Paper 成对包。种子根 1033100000，与全轨 Formal
   1033000000 分离；不同轨道点独立生成/估计/解码。两信道共用匹配的
   payload/noise seed，Rician 额外施加抽取的系数。
4. 四条曲线均不拟合、不平滑、不强制排序。真实测得 0 保留，log 图
   不把 0 伪装成非零点。只有原始符号错误计数决定 SER，分母固定112000。

这些图复用 Figure12 的取点与能量条件，但不是论文 LDRO/CR1/120bit 的
原图数值复现。理论是当前 PHY 的无 Doppler 非相干 FFT SER 独立积分；
不拿论文图的灰线或目标 SER 反调 K、SNR、算法参数。

## 验证及执行

四项协议测试已 PASS：±23 bin CFO 无噪声零错；导频残差 2 bin 更新从
下一个数据立即生效；两信道数据噪声/系数与原生帧配对；AWGN 理论与
冻结精确理论表一致。五个核心 .m 文件 checkcode 0 findings。

每点 2 包接入烟测：Case-SNR 40 包，PREC/VP/Paper 原始错误为
3168/1861/3246；Figure12 两信道共20个成对包，错误为1218/53/489。
异常计数均为0。两个检查点续跑核对通过，未重复加包；只读代码审计已
PASS，无待处理发现。烟测不作为1000包/点结果。

Case-SNR 完整运行已完成：20 个点，每点1000包，共20,000个论文/原生
配对包；PREC/VP/Paper 符号错误总数为1,553,940/962,462/1,581,989。
接收失败0，禁用输入标志全部false。逐点包ID、CSV汇总、112000分母、
MAT/CSV整数计数、结果/检查点一致性、状态摘要、54个源码和8个输入
签名以及理论重算均已核对通过；复用的PREC/VP/native Ideal计数与种子
未改变。

Figure12完整运行已完成：AWGN/Rician各5点，每点1000包，共10,000个
论文/原生成对包。PREC/VP/Paper符号错误总数为608,306/19,519/238,353。
接收失败0，禁用输入标志全部false。逐点1000个唯一包ID、五个轨道时刻、
精确SNR、跨信道种子配对、原始整数计数、CSV汇总、112000分母、
MAT/CSV一致性、结果/检查点一致性、状态摘要、54个源码与5个输入
签名、gain/VP数/信道功率及独立理论重算均已核对通过。三种实测方法
在这10个点均有真实错误计数，无零SER点；未修改计数来保证非零。

Figure12的AWGN理论为0.000150310743607429，Rician理论为
0.0309640691298955。VP实测AWGN范围为9.82143e-5至2.23214e-4；
Rician范围为0.0312768至0.0381161。VP部分AWGN点低于理论属于本次
有限样本观测，不强行排序，也不据此宣布优于理论。论文方法在部分轨道
点有明显退化，保留原始结果；当前用户PHY不同于论文PHY，不能据此
宣称已复现论文原图数值。

最终只读审计PASS，无可操作发现：独立核验了两个完整输出目录的CSV、
每点包ID、汇总/分母、复用基线计数、跨信道种子以及全部六张PNG。
审计基线仍为4d509fd5c2c6e0656916c4a8dd82a7ff56686f39。审计员本次
未独立重新加载MAT内部状态和保存的哈希字段；这些已由主流程另行加载、
逐项核验通过，不把两种验证证据混称为同一次独立复载。

### Figure12原始错误计数（每个单元1000包×112符号）

| t0 (s) | AWGN PREC | AWGN VP | AWGN Paper | Rician PREC | Rician VP | Rician Paper |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| -366 | 18 | 16 | 322 | 3398 | 3862 | 9066 |
| -274.5 | 2192 | 11 | 217 | 7873 | 4004 | 7280 |
| -183 | 79709 | 14 | 9231 | 81708 | 3803 | 18185 |
| -91.5 | 105110 | 12 | 23295 | 105471 | 3503 | 30866 |
| 0 | 111376 | 25 | 67360 | 111451 | 4269 | 72531 |

### Case-SNR的-21 dB点（Rician）

| Case | PREC SER | VP SER | 理论 SER | Paper SER |
| --- | ---: | ---: | ---: | ---: |
| 1 (-366 s) | 0.029375 | 0.0313571428571 | 0.0284643251771 | 0.0759107142857 |
| 2 (0 s) | 0.995089285714 | 0.0288660714286 | 0.0284643251771 | 0.636267857143 |

六张PNG已逐一检查：Case1、Case2及合图；AWGN轨迹、Rician轨迹及合图。
每张只有要求的PREC、VP、理论、论文Midamble-Point四条曲线；连接原始
取点，无拟合/平滑。每个结果目录含完整CSV、MAT结果与续跑检查点。

```matlab
addpath('D:/codex/Lora（SER performance of different estimation strategies）/senlora_symmetric_v8');
runSenloraPaperPointFourCurves(Stage="CaseSnr",WorkerCount=4);
runSenloraPaperPointFourCurves(Stage="Figure12",WorkerCount=4);
```

独立输出目录为 `paper_point_eq17_case_snr_rician` 和
`figure12_four_methods`，位于 `results/senlora_symmetric_v8/`。
旧 Paper/PREC/VP 图和数据不覆盖，全轨 Formal 不启动。
