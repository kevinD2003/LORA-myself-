# SF12论文同条件下Stage55与Midamble-Point两方法对比方案

## 1. 实验目标

在论文SF12、Case 1和Case 2条件下，对比两种载荷期Doppler跟踪方法：

1. Paper Midamble-Point：使用固定插入的已知Midamble；
2. Stage55-VP-quality-SER：使用接收机判决形成的质量感知虚拟导频。

本实验的首要目标是比较逐符号跟踪和SER，不比较现有SF11 Stage55的完整业务性能。
Stage55原始SF11结果、论文独立复现结果和所有旧审计保持冻结。

## 2. 结论边界

本实验回答：

> 在相同SF12论文物理信号、相同Point初始CFO、相同噪声和相同数据符号条件下，
> 固定显式Midamble与质量感知虚拟导频的跟踪性能有何差异？

本实验不直接回答：

- 原生SF11 Stage55是否优于论文完整系统；
- Stage55的跨帧状态是否有效；
- CR3软Hamming译码是否优于论文CR1；
- 作者未公开的Rician时间模型是什么。

正式报告不得把本实验称为“原生Stage55完整接收机”，应称为“Stage55质量感知
载荷跟踪核心的SF12论文条件适配”。

## 3. 冻结物理条件

| 参数 | 冻结值 |
|---|---:|
| SF | 12 |
| 带宽/采样率 | 125 kHz |
| 载频 | 868 MHz |
| 轨道高度 | 550 km |
| LDRO | 开启 |
| Rician K | 10 dB |
| AWGN定义 | 带宽B内平均噪声功率 |
| Payload | 120 bit |
| CR | 1 |
| 数据符号数 | 23 |
| 前导upchirp | 8 |
| 完整downchirp | 2 |
| 同步尾部 | 0.25 chirp |
| Case 1起始轨道时间 | -366 s |
| Case 2起始轨道时间 | 0 s |
| SNR网格 | -30:-21 dB |

不得使用图像校准配置中的K=12.75 dB、Doppler时间尺度0.5或人为Midamble SNR
损失。两种方法必须使用同一Rician实现、同一噪声数组和同一连续Doppler相位。

## 4. 公共初始CFO估计

两种方法均使用论文Point初始估计：

1. 接收最后一个完整同步downchirp；
2. 与纯upchirp相乘完成去啁啾；
3. 用同一FFT长度和峰值规则估计初始CFO；
4. payload开始前，两分支的初始CFO和初始相位必须逐项相等。

关闭Stage55跨帧状态和轨道速率先验。否则比较会同时混入跨帧预测优势。

## 5. Paper Midamble-Point分支

固定`n_int=3`。23个数据符号的布局为：

- 有效跟踪Midamble：在数据符号3、6、9、12、15、18、21之后，共7个；
- 式（20）总Midamble：`ceil(23/3)=8`；
- 第8个是末端Midamble，只计入ToA，不参与后续数据补偿。

接收机要求：

- 只使用最后同步downchirp和7个有效Midamble；
- 不使用payload判决作为导频；
- 每个Midamble使用原生物理SNR，不额外加噪；
- 按式（17）累积残余频偏；
- 使用分段常数补偿；
- 若保留一个数据符号处理时延，必须作为独立、预注册实现选项报告。

## 6. Stage55虚拟导频分支

该分支不把任何显式Midamble作为跟踪观测。虚拟导频只能来自23个payload数据符号，
且不得访问payload真值。

由于论文CR1和23符号帧不具备当前Stage55的CR3/112符号Hamming结构，主SER实验
采用不依赖FEC真值的质量门：

1. 补偿后FFT第一峰/第二峰比达到冻结门限；
2. 硬判决在相邻两次因果迭代中保持一致；
3. 细CFO残差不位于搜索边界；
4. CFO创新量不超过冻结物理门限；
5. 接纳后采用接收机可见CFO不确定度进行融合；
6. 虚拟导频只能影响后续符号，不能回溯修正产生它的符号。

该方法命名为`Stage55-VP-quality-SER`，避免与原生CR3、ML-soft Hamming的完整
Stage55混淆。

若后续需要正式BER，应另行实现和验证LoRa CR1的(5,4)软码本/交织链，不能复用
当前ML-soft Hamming(7,4)后直接宣称论文CR1 BER。

## 7. 两种物理帧口径

### 7.1 主口径：公共增强帧

两种方法接收同一个包含8个Midamble的物理帧：

- Paper分支使用前7个有效Midamble；
- Stage55分支忽略全部显式Midamble；
- SER只统计23个原始数据符号；
- 数据、信道、噪声和物理时间完全相同。

该口径用于比较接收跟踪性能。

### 7.2 开销口径：各自原生帧

- Paper原生帧：包含8个Midamble；
- Stage55原生帧：不发送Midamble。

该口径只报告ToA、发射符号数、能耗代理量和净有效吞吐量，不用于宣称两分支收到
完全相同的噪声波形。

## 8. 随机账本

采用三个互不重叠的随机种子域：

| 用途 | Payload种子基数 | 噪声种子基数 |
|---|---:|---:|
| 机制标定 | 2027121200 | 2027121300 |
| 独立验证 | 2027122200 | 2027122300 |
| 正式实验 | 2027123200 | 2027123300 |

正式种子公式必须只由Case、SNR索引和包索引决定，不得包含方法名称。两种方法必须
共享每一个包的payload、Rician系数和AWGN样本。

不得因某个种子结果不理想而更换种子。

## 9. Stage55-SF12机制标定

正式实验前必须在机制标定种子上重新确定SF12接收机量纲，不能继承SF11 bin单位：

1. 固定残余CFO扫描：0:0.05:2 bin；
2. 单符号CFO误差和95%分位数；
3. CFO标准差1倍/2倍覆盖率；
4. 相位对整周模糊概率；
5. 虚拟导频误接纳率；
6. 创新增益和创新门限；
7. 残差搜索边界命中率；
8. 一个符号因果更新时延。

所有频偏速率内部优先使用Hz/s，只有FFT搜索和绘图时转换为bin/s。

参数冻结后写入`sf12_receiver_parameter_manifest.json`，其中必须记录来源、单位、标定
种子和是否经过性能结果选择。

## 10. 正式Monte Carlo设计

实验矩阵：

```text
2个Case × 10个SNR点 × 2种方法
```

每个Case/SNR使用配对包。停止规则：

- 至少5000包；
- 两种方法均达到至少1500个payload符号错误时可以停止；
- 任一方法未达到错误数时，最多50000包；
- 两种方法必须在同一包数停止，不能独立停止。

正式结果同时保存：

- `symbolErrors`；
- `totalDataSymbols`；
- SER及95%区间；
- CFO平方误差和样本数；
- 接纳虚拟导频数；
- 错误接纳虚拟导频数；
- 有效Midamble数；
- 每个导频首次生效的数据位置；
- 每包随机账本。

## 11. 主指标和辅助指标

主指标：

1. 23个payload数据符号的SER；
2. payload逐符号CFO RMSE；
3. Case 1/Case 2下的SER随SNR曲线。

辅助指标：

- 导频接纳数量和覆盖率；
- 错误接纳数量；
- 跟踪更新时延；
- Paper/Stage55原生ToA；
- 显式导频开销；
- 运行时间和FFT次数。

CR1译码链完成前不把BER/PER列为正式结论。

## 12. 图表设计

正式主图只放两种方法：

1. Figure A：Case 1，SER-SNR；
2. Figure B：Case 2，SER-SNR；
3. Figure C：代表性SNR=-21 dB的逐符号CFO误差；
4. Figure D：导频位置、接纳数与影响覆盖率；
5. Table A：SER/CFO RMSE及95%区间；
6. Table B：ToA、导频数和开销。

不得平滑、拟合、交换曲线或从论文图读取点作为仿真输入。

## 13. 验收门

### 13.1 物理链

- 无噪声、无Doppler：两方法23个数据符号零错误；
- Case 1/2轨道起点与论文配置一致；
- Doppler相位逐采样积分且跨符号连续；
- 公共增强帧中两方法接收复数样本逐项一致；
- LDRO合法bin映射通过。

### 13.2 公平性

- 两分支公共Point初始CFO逐项一致；
- Stage55显式Midamble接纳数为0；
- Paper虚拟导频接纳数为0；
- Paper有效Midamble数为7、ToA总数为8；
- 两方法的payload/noise/channel账本完全一致；
- 接收机接口不包含payload真值或轨道真值。

### 13.3 统计与审计

- SER严格等于`symbolErrors/totalDataSymbols`；
- 每点包数和停止原因完整；
- 置信区间来自原始计数；
- 不把性能优劣作为测试通过条件；
- 代码静态检查0问题；
- 新结果不得覆盖SF11或旧论文结果。

## 14. 目录方案

```text
stage55_sf12_paper_conditions/
├─ config/
│  ├─ sf12PaperCommonConfig.m
│  └─ sf12ReceiverParameterManifest.json
├─ src/
│  ├─ sf12CommonPointBootstrap.m
│  ├─ sf12PaperMidambleDecode.m
│  ├─ sf12Stage55VpSerDecode.m
│  └─ sf12PairedFrameSimulation.m
├─ scripts/
│  ├─ runSf12MechanismCalibration.m
│  ├─ runSf12Smoke.m
│  ├─ runSf12FormalComparison.m
│  ├─ buildSf12ComparisonReport.m
│  └─ auditSf12Comparison.m
├─ tests/
├─ results/
│  ├─ calibration/
│  ├─ validation/
│  ├─ formal_common_frame/
│  └─ native_overhead/
└─ SF12论文同条件两方法对比报告.md
```

## 15. 实施顺序

1. 新建隔离目录和SF12公共配置；
2. 完成23符号公共帧与8个Midamble布局；
3. 实现公共最后downchirp Point bootstrap；
4. 接入Paper Midamble-Point分支；
5. 将Stage55质量感知载荷跟踪改造成无FEC真值的SER分支；
6. 完成SF12 CFO质量标定并冻结参数；
7. 运行无噪声和四包冒烟；
8. 用独立验证种子检查门限和误接纳；
9. 运行正式配对Monte Carlo；
10. 生成主图、原生开销表、中文报告和机器审计。

## 16. 成功标准

项目完成不以Stage55必须优于Paper为条件。完成标准是：

- 两种方法在论文SF12条件下实现正确；
- 公共物理样本和随机账本完全一致；
- 导频来源严格隔离；
- Case 1/2正式SER和CFO结果具备可追溯原始计数；
- 原生帧开销单独报告；
- 不使用论文图像校准参数；
- 所有测试、静态检查和审计通过。
