# Paper 与 Stage55 全轨道同趋势目标及验证方案 V3

- 方案 ID：`EXP4-TREND-CONSISTENT-PAPER-STAGE55-V3`
- 文档状态：**REVISED TARGET / PLAN ONLY**
- 日期：2026-09-23
- 当前状态：只修改目标与验证方案；接收机代码、配置和既有结果均未修改
- Formal 状态：**禁止启动**
- Formal 启动条件：未来候选通过 G2 后，用户明确回复
  `审查通过，可以进行 Formal`

## 1. 总目标

在冻结 SF12、BW=125 kHz、Fs=125 kHz、no-LDRO、CR3、112 个数据符号、
157T 共同时间轴和 AWGN+连续轨道 Doppler 的条件下，后续实现必须同时满足：

1. Paper 全轨道曲线与论文 Figure 12 Midamble-Point 的归一化趋势一致；
2. Paper 任一中间轨道位置不得差于本地 Paper Case2；
3. Paper 实测曲线允许比映射目标略差，但不得产生无物理解释的尖峰；
4. Stage55 全轨道必须低于同条件 Paper；
5. Stage55 使用与 Paper 相同的归一化轨迹趋势，但使用独立的 Stage55 端点映射；
6. Stage55 Case1 不得比当前版本差；
7. Stage55 Case2 必须优于或不劣于当前版本；
8. 目标曲线只用于离线验收，严禁进入接收机判决、补偿或参数更新。

“同趋势”不等于把仿真结果强制改成目标数值。只有接收机真实逐包结果通过独立
seed 验证时，才能宣称满足目标。

## 2. 冻结条件

| 项目 | 冻结值 |
|---|---|
| SF | 12 |
| BW / Fs | 125 kHz / 125 kHz |
| LDRO | off |
| Coding | 当前 CR3 |
| Information bits | 768 |
| Data symbols | 112 |
| Bootstrap | 8 个符号 |
| Paper midambles | 37 个 |
| Common timeline | 157T |
| Channel | AWGN + 连续轨道 Doppler |
| Case1 | `t0=-366 s` |
| Case2 | `t0=0 s` |
| 正式轨道位置 | `[-366,-320.25,-274.5,-228.75,-183,-137.25,-91.5,-45.75,0] s` |
| 正式 SNR | `[-24,-21.12] dB` |

论文 Figure 12 的数值仍标记为“由本地 PDF 图像数字化得到的近似值”，不得写成
作者原始数据。当前五个 SF12 Midamble-Point 近似锚点为：

```text
t_ref   = [-366, -274.5, -183, -91.5, 0] s
SER_ref = [0.022, 0.022, 0.023, 0.029, 0.045]
```

## 3. 已知问题及解决方案

本节规定未来代码候选必须采用的机制边界，但本次文档修订不执行这些代码修改。

### 3.1 问题与修复映射

| 已确认问题 | 直接原因 | 规定解决方案 | 必须保存的验证证据 |
|---|---|---|---|
| Paper 轨道曲线剧烈波动 | 不同轨道包在 Static-Point 与 Trend-Point 两套实现间切换 | Paper 全轨道只保留一个统一 Midamble-Point 接收机身份 | 每包接收机身份、分支计数必须证明全轨道一致 |
| Paper 出现巨大 CFO 周跳 | 每个 midamble 都进行全频域重新捕获并无条件接纳 | 初始捕获后只允许物理有界的局部 residual 搜索，加入置信度、边界和 innovation 检查 | 每个 midamble 的候选范围、peak ratio、innovation、接纳/拒绝和周跳计数 |
| Paper 更新不符合统一 Point 定义 | Trend 分支包含多点趋势回归和任意两数据符号延迟 | 删除 Paper 中的趋势回归和人为更新延迟；midamble 更新从下一个数据符号立即生效 | midamble 时刻、首个生效数据符号、更新前后 CFO |
| Paper 初始估计在低 SNR 下不稳定 | 单个已知 chirp 的全频域峰值容易被噪声极值替代 | 初始 CFO 仅使用已知前导、采用接收机可观测的稳健联合/功率合并捕获；之后切换到局部 Point 更新 | 初始搜索范围、候选峰、置信度和是否失锁 |
| Stage55 中段长期保持 Static | `strong` 证据继续受旧 CFO-domain gate 阻断，`moderate` 又要求所有证据同时成立 | 保留端点保护，但改为分层证据融合；可靠完整码块/payload 证据可以覆盖不稳定的 split-preamble 单项 | 每包各证据布尔值、分支原因、首次可用块和最终选择 |
| Stage55 在低 SNR 下 Dynamic 选择不足 | VP 稀少时完整 payload likelihood 不稳定，严格 AND 门导致回退 Static | 使用完整 Hamming 块的归一化码字似然、前导 rate 漂移和有界 residual 的联合评分；禁止按单符号切换 | 每块两假设得分、选择、回退、VP 数量和残差 |
| Stage55 错误 VP 反馈造成偏移 | 错误 hard label 可能污染 CFO/rate 历史 | VP 全轨道监测，但只有满足 label 一致性、peak ratio、innovation 和 phase-pair 条件时才能反馈；更新后恶化必须撤销 | VP candidate/accepted/false、innovation、更新增益和 rollback |
| Case1 可能被 Dynamic 误切换 | 低 SNR rate 点估计可能产生伪动态证据 | Static 分支保持冻结；Case1 保护要求最终输出逐包与当前 Static 完全一致，证据不足时整块/整包回退 Static | detected symbols、hard bits 和 packet SER 逐包等价 |
| Case2 可能因新门控退化 | 新选择器可能错误回退 Static | 当前 Dynamic 作为冻结保底假设；新候选无法证明更优时，完整块/整包保留当前 Dynamic 输出 | 新旧 Case2 逐包差值和选择原因 |

### 3.2 Paper 统一接收机方案

未来 Paper 候选必须遵循以下单一路径：

```text
已知前导稳健初始捕获
        -> piecewise-constant Midamble-Point
        -> 每 3 个数据 chirp 后使用 1 个已知 midamble
        -> 局部、有界、置信度控制的 residual CFO 更新
        -> 下一数据符号立即生效
```

具体约束：

1. 全轨道使用同一函数和同一参数，不允许依据 CFO 区域切换为 Trend-Point；
2. 初始捕获只能使用接收机已知前导，不得读取轨道、Case、SNR 或真值；
3. 第一次捕获完成后，不得在每个 midamble 上重新搜索整个 FFT 频域；
4. residual 搜索半宽只能由冻结的最大 Doppler rate、midamble 物理间隔和符号时长确定；
5. residual 位于搜索边界、peak ratio 不足或 innovation 超限时，本次更新拒绝并保持上一状态；
6. 接纳的更新必须限幅，并从紧随该 midamble 的第一个数据符号开始生效；
7. Paper 只进行 piecewise-constant Point 更新，不拟合 payload 趋势，不使用 payload 判决反馈；
8. 37 个 midamble 的实际时刻、接纳、拒绝和首个生效符号全部保存；
9. 任一包出现超过 `0.5 bin = 15.26 Hz` 的不可解释残差时标记预警；
10. 超过冻结 innovation 上限的 CFO 周跳必须为 0，否则候选阻断。

该修复的目的是真实消除失锁和分支不连续，不是把 Paper 人为压到目标线上。

### 3.3 Stage55 分层双假设方案

未来 Stage55 候选保持两个冻结内部假设：

```text
Static hypothesis：当前 Case1 静态实现
Dynamic hypothesis：当前 Case2 joint-preamble + confidence-VP 实现
```

只修改两者之外的选择与回放层：

1. Static 与 Dynamic 对同一个完整接收包并行运行；
2. 每个 Hamming 完整码块分别保存 Static/Dynamic 归一化码字似然；
3. 禁止在一个 Hamming 码块内部混合两条补偿路径；
4. 前导提供 joint-rate、split-rate、一致性和不确定度证据；
5. payload 提供完整码块 likelihood、VP coverage、innovation 和 residual 趋势证据；
6. 高置信度前导证据可以在无 VP 时选择 Dynamic，以保护 Case2 低 SNR；
7. 当前导 split 估计不稳定但多个完整码块持续支持 Dynamic 时，允许码块证据覆盖该单项否决；
8. 单个 VP、单个码块或单个 rate 点估计均不得独立触发全包切换；
9. 更新后 likelihood 或 residual 连续恶化时，撤销该完整码块并回放另一假设；
10. 证据不足时根据冻结的端点保护规则回退，不得读取 Case 身份：
    - 低动态、Static 证据稳定时保留完整 Static；
    - 高动态、当前 Dynamic 证据稳定时保留当前 Dynamic；
11. 最终硬比特、符号、CFO、选择原因和回退必须来自同一完整码块路径；
12. Paper 输出和目标曲线不得进入 Stage55 的评分或选择。

### 3.4 趋势保证的正确位置

趋势约束只能存在于离线验收层：

```text
接收机输入：rx samples + 已知协议参数
接收机输出：真实逐包检测结果和状态
离线验收：用输出计算 SER、端点映射目标、形态偏差和置信区间
```

如果实测曲线不满足同趋势条件，应判定候选失败并更换独立 refinement seeds，
不得在结果绘图阶段进行平滑，也不得把 `u(t)` 或目标 SER 反馈给接收机。

### 3.5 实施顺序

未来代码工作必须严格分两步，避免同时改变比较基准和被比较方法：

1. 先实现并独立验证 Paper 统一接收机；Paper 通过趋势、Case2 上界和周跳门后冻结；
2. 再以冻结后的 Paper 为比较基准实现 Stage55 分层双假设；
3. Paper 未冻结前不得依据 Paper 临时结果调整 Stage55；
4. Stage55 失败不得回头削弱 Paper；
5. 每一步均使用新的候选身份、校准 seeds、Smoke seeds 和 Review seeds。

## 4. 唯一的归一化趋势

在 `log10(SER)` 域定义论文归一化趋势：

```text
u_i = [log10(SER_ref(i))-log10(SER_ref(Case1))]
      /[log10(SER_ref(Case2))-log10(SER_ref(Case1))]
```

所有方法共享同一个 `u_i`。九位置中的非论文锚点使用分段线性插值获得 `u(t)`；
禁止使用仿真 SER 对 `u(t)` 重新拟合。

当某端点的测量 SER 为 0 时，形态计算使用预先冻结的绘图下界
`0.5 / measuredSymbolCount`，但统计比较仍使用真实错误计数，不得把该下界当作错误。

## 5. Paper 目标

### 5.1 Paper endpoint-mapped target

对每个 SNR 独立使用 Paper 的 Case1、Case2 冻结端点定义：

```text
log10(Paper_target(t)) = log10(Paper_Case1)
                       + u(t) * [log10(Paper_Case2)-log10(Paper_Case1)]
```

### 5.2 Paper “同趋势且略差”定义

除两个端点外，Paper 实测曲线必须满足：

```text
0 <= log10(Paper_measured(t))-log10(Paper_target(t)) <= 0.10 decade
```

即实测 Paper 可与目标相同或最多差约 10.9%，不得人为给 Paper 注入噪声以制造
“略差”。若真实接收机优于目标，应如实保留，并在报告中标为优于目标。

同时满足：

- 映射形态 log-SER RMSE `<=0.05 decade`；
- 任一点绝对形态偏差 `<=0.10 decade`；
- 相邻位置不得出现 `>0.10 decade` 的反向跳变；
- Paper 中间位置点估计不得高于 Paper Case2；
- Paper 中间位置相对 Case2 的配对 95% CI 上界不得为正；
- CFO 周跳率、错误 midamble 更新率和残差异常必须逐位置报告。

## 6. Stage55 目标

### 6.1 Stage55 独立 endpoint-mapped target

Stage55 不直接复用 Paper 的纵轴数值，而只复用同一个 `u(t)`：

```text
log10(Stage55_target(t)) = log10(Stage55_Case1)
                         + u(t) * [log10(Stage55_Case2)-log10(Stage55_Case1)]
```

因此 Paper 与 Stage55 的趋势完全相同，但 Stage55 可以整体位于 Paper 下方。

### 6.2 Stage55 形态条件

- Stage55 映射形态 log-SER RMSE `<=0.05 decade`；
- 任一点相对 Stage55 映射目标偏差 `<=0.10 decade`；
- 相邻位置不得出现 `>0.10 decade` 的反向跳变；
- Stage55 任一中间位置不得差于 Stage55 Case2；
- 不允许用轨道时间、轨道真值、最终 SER、Paper 输出或目标曲线选择接收机分支。

### 6.3 Stage55 相对当前版本

Case1 使用最严格保护：

```text
detected symbols identical
hard-decoded bits identical
packet SER identical
```

如无法逐包完全一致，候选直接阻断，不使用 non-inferiority margin 放宽。

Case2 要求新版本优于或不劣于当前版本：

```text
Delta_case2 = SER_current- SER_new
point estimate >= 0
paired 95% CI lower bound >= 0
```

### 6.4 Stage55 相对 Paper

每个正式轨道位置和每个正式 SNR：

```text
Delta_orbit = SER_Paper-SER_Stage55
point estimate > 0
paired 95% CI lower bound > 0
```

任一点不满足时，不得宣称“Stage55 全轨道低于 Paper”。

## 7. 禁止的实现方式

以下行为无论图形是否好看都判定为失败：

- 将 `t0`、卫星位置或轨道真值输入接收机分支选择；
- 根据 Paper 输出、最终 SER 或目标曲线调整当前包的补偿；
- 在结果生成后平滑、替换或裁剪实测 SER；
- 人为降低 Paper，使 Stage55 更容易胜出；
- 用同一批 Review/Formal 包选择阈值后再次宣称通过；
- 删除失败包、错误 VP、CFO 周跳或不利位置；
- 把 Figure 12 数字化近似值标记为作者原始数据。

## 8. 随机性与候选身份

后续代码候选必须使用新的身份，不得继续使用 V2 身份或 V2 review seeds。

必须预留互不重叠的 seed 域：

```text
Paper mechanism calibration
Stage55 mechanism calibration
G1 smoke
G2 review validation
Formal confirmation
post-failure refinement
```

G2 或 Formal 失败后，只能新建候选身份并切换到 refinement 域；不得在失败数据上
继续调参后复用同一确认集。

## 9. 执行门

### G0：只读实现审计

未来实现前必须确认：

- Paper 全轨道使用同一个接收机定义；
- Paper 更新无全频域错误重捕获、无无条件错误接纳；
- Stage55 Static/Current-Dynamic 保护边界明确；
- 所有选择只依赖接收机可观测量；
- 目标曲线只存在于离线报告代码；
- 既有 V2 和 Formal 结果保持只读。

### G1：最小 Smoke

```text
Case1/Case2 × [-30,-24,-21] dB × 5 packets
关键中间位置 [-274.5,-183,-91.5,-45.75] s
× [-24,-21.12] dB × 5 packets
```

G1 只检查：零失败、配对输入、完整监测、Case1 精确保持、Case2 不退化迹象、
无 CFO 周跳和无分支混合。G1 不用于曲线结论。

### G2：少次数用户审查

```text
Case1/Case2: SNR=[-30,-27,-24,-21] dB, 20 packets/cell
Orbit: 9 positions × [-24,-21.12] dB, 20 packets/cell
```

G2 必须输出原始实测曲线、Paper/Stage55 各自映射目标、形态偏差、配对差值、
逐符号残差、VP/midamble 质量和全部失败包。任一硬条件明显失败即停止。

### G2 用户审查门

G2 完成后强制停止。只有用户明确回复：

```text
审查通过，可以进行 Formal
```

才能进入 Formal。

### Formal

仅在批准后执行：

```text
Case1/Case2: -30:-21 dB, 1000 packets/cell
Orbit: 9 positions × 2 SNR × 1000 packets/cell
paired bootstrap: 10000 draws
```

## 10. 必交结果

```text
TREND_TARGET_CONFIG.json
PAPER_ENDPOINT_MAPPED_TARGET.csv
STAGE55_ENDPOINT_MAPPED_TARGET.csv
PAPER_TREND_DEVIATION.csv
STAGE55_TREND_DEVIATION.csv
CASE1_PAIRED_EQUIVALENCE.csv
CASE2_PAIRED_NONINFERIORITY.csv
ORBIT_PAPER_MINUS_STAGE55.csv
PER_SYMBOL_RESIDUAL_AND_UPDATE_STATE.csv
REVIEW_CASE1_SER.png
REVIEW_CASE2_SER.png
REVIEW_ORBIT_SER_WITH_TWO_TARGETS.png
REVIEW_RESIDUAL_HEATMAP.png
USER_REVIEW_GATE.md
```

图中必须明确区分：

- Figure 12 数字化参考；
- Paper endpoint-mapped target；
- Stage55 endpoint-mapped target；
- Paper 实测曲线；
- Stage55 实测曲线。

## 11. 最终晋升条件

候选只有同时满足以下条件才允许晋升：

```text
Paper 同一接收机全轨道运行
Paper 与 Figure 12 归一化趋势一致
Paper 中间位置不差于 Paper Case2
Stage55 与相同归一化趋势一致
Stage55 Case1 逐包完全一致
Stage55 Case2 配对不劣且允许改善
Stage55 每个正式轨道位置显著低于 Paper
无 CFO 周跳、错误反馈或不可解释残差发散
无 orbit/truth/SER/Paper/target 泄漏
独立 Formal seeds 通过
用户明确批准 Formal
```

任何一项失败，候选只能保留为探索结果，不得晋升。

## 12. 当前边界

本次只完成目标和验证方案修订：

- 未修改任何接收机源码；
- 未修改任何配置代码；
- 未重跑 G1、G2 或 Formal；
- 未覆盖 V2 结果；
- 未批准任何候选晋升。
