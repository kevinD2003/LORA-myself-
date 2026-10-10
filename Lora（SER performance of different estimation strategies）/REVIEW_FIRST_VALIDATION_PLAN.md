# Stage55 全轨道统一补偿：少次数验证与用户审查方案

> 历史方案说明：本文件保留为 V1/V2 执行记录。后续候选的目标、
> 曲线形态与验收流程由 `TREND_CONSISTENT_TARGET_AND_VALIDATION_PLAN_V3.md`
> 取代。该替代只修改目标和验证方案，不修改现有代码或既有结果。

- 方案 ID：`EXP3-STAGE55-REVIEW-FIRST-ORBIT-V1`
- 文档状态：**DRAFT - 等待用户审查批准**
- 生成日期：2026-09-22
- 当前动作权限：仅允许代码/配置只读审计和少次数验证准备；**不得启动 Formal**
- Formal 启动条件：用户明确回复“审查通过，可以进行 Formal”

## 1. 目标

在保持当前 SF12、AWGN、no-LDRO、CR3、112 个数据符号和 157T 共同时间轴不变的条件下，设计并验证统一的 Stage55 补偿框架，使其满足：

1. 当前 Case1 完整 SER-SNR 曲线不退化；
2. 当前 Case2 完整 SER-SNR 曲线不退化，改善允许；
3. 当前本地 Paper 的 Case1、Case2 性能端点不被人为降低；
4. Paper 轨道曲线保留参考论文 Figure 12 Midamble-Point 的轨道变化形态；
5. Paper 中间轨道位置不存在缺乏物理解释的突变；
6. 新 Stage55 在全部正式轨道位置低于 Paper；
7. 所有 112 个数据符号都保存在线状态和离线真实残差；
8. 在少次数验证结果提交用户审查前，不得进行大规模 Formal。

“Stage55 全轨道低于 Paper”是候选版本的晋升条件，不是通过调参强制制造的结果。如果独立确认不满足，该候选必须判定为未通过。

## 2. 冻结条件

以下条件在本方案中不得修改：

| 项目 | 冻结值 |
|---|---|
| SF | 12 |
| BW / Fs | 125 kHz / 125 kHz |
| LDRO | off |
| Coding | 当前 CR3 实现 |
| Information bits | 768 |
| Data symbols | 112 |
| Bootstrap | 8 个符号 |
| Paper midambles | 37 个 |
| Common timeline | 157T |
| Channel | AWGN + 连续轨道 Doppler |
| Case1 | `t0 = -366 s` |
| Case2 | `t0 = 0 s` |
| Static 分支 | 当前已验证实现 |
| Dynamic VP 分支 | 当前已验证实现 |
| Paper 分支 | 当前本地实现，不得故意削弱 |

## 3. 核心接收机结构

### 3.1 Static 与 Dynamic 内部算法保持不变

```text
Static hypothesis:
    使用当前 Case1 静态 CFO 补偿
    rate = 0
    不改变已验证参数

Dynamic hypothesis:
    使用当前 Case2 联合 CFO/rate 初始化
    使用当前 confidence-VP tracker
    不改变已验证参数
```

### 3.2 全轨道 VP 监测，但不全轨道强制反馈

每个 payload 符号都执行：

```text
候选符号判断
confidence 计算
残余 CFO 测量
innovation 计算
VP 候选记录
```

但只有证据充分时，VP 才能修改正式补偿状态。

### 3.3 双假设并行

```text
Static 主路径：默认输出，保护 Case1
Dynamic 影子路径：后台预测，不立即影响实际输出
```

只有 Dynamic 的接收机可观测证据持续优于 Static 时，才允许切换输出。

### 3.4 动态证据

不得只依据 `abs(rateHat)` 单点阈值。至少同时检查：

1. 前四个与后四个前导的 rate 估计是否同号且一致；
2. rate 置信区间是否排除 0；
3. Dynamic 相对 Static 的 receiver likelihood 增益；
4. 连续可靠 VP innovation 是否具有同方向趋势；
5. 剩余 payload 的预测漂移是否超过容许值。

建议诊断量：

\[
D_{\rm lower}(n)
=
\max\left(0,|\hat r(n)|-k\sigma_r(n)\right)T_{\rm remain}(n)
\]

只有 `D_lower` 超过冻结门槛，才允许 Dynamic 成为主输出。

### 3.5 回退保护

- Static 默认优先；
- 进入 Dynamic 使用较高门槛；
- 退出 Dynamic 使用较低门槛，形成滞回；
- CFO innovation 与 rate innovation 分别限幅；
- 低置信度 VP 只能记录，不能更新；
- rate 更新需要多个一致 VP；
- 更新后 likelihood 下降时撤销本次更新；
- Dynamic 连续变差时回退 Static；
- 不允许依据轨道时间、真实 CFO、真实 rate、最终 SER 或 Paper 结果切换。

## 4. Paper Figure 12 轨道形态目标

### 4.1 论文参考只用于形态

论文五个锚点：

```text
[-366, -274.5, -183, -91.5, 0] s
```

当前本地 Paper 的 Case1、Case2 数值优于论文，因此不得为了数值复现而降低本地 Paper。

在 `log10(SER)` 域定义论文归一化形态：

\[
u_i=
\frac{
\log_{10}SER_{\rm ref}(t_i)-\log_{10}SER_{\rm ref}(-366)
}{
\log_{10}SER_{\rm ref}(0)-\log_{10}SER_{\rm ref}(-366)
}
\]

映射到本地两个端点：

\[
\log_{10}SER_{\rm target}(t_i)
=
\log_{10}SER_{\rm local,C1}
+u_i\left[
\log_{10}SER_{\rm local,C2}-\log_{10}SER_{\rm local,C1}
\right]
\]

### 4.2 Paper 预登记验收条件

| 条件 | 验收标准 |
|---|---|
| Case1 端点 | 与当前本地 Paper 逐包一致 |
| Case2 端点 | 与当前本地 Paper 逐包一致 |
| 归一化形态 | log-SER RMSE `<= 0.10 decade` |
| 单点形态偏差 | 相对映射目标 `<= 0.20 decade` |
| 中间位置 | 不得差于本地 Paper Case2 |
| 异常突变 | 不允许出现参考形态没有的 `> 0.20 decade` 额外跳变 |
| 实现正确性 | midamble 数量、时刻、相位推进和 CFO 更新全部通过审计 |

目标曲线、论文参考曲线和本地仿真曲线必须使用不同图例，不得把目标曲线当作测量结果。

## 5. 随机性分割

必须使用互不重叠的 seed 域：

```text
gate calibration seeds
VP/uncertainty calibration seeds
smoke seeds
review-validation seeds
formal-confirmation seeds
refinement seeds
```

禁止：

- 用 review-validation 或 Formal 的 SER 选择阈值；
- 看见确认结果后在同一批 packets 上回调；
- 只补跑有利位置；
- 删除或忽略失败包。

## 6. 执行流程

### G0：只读代码与配置审计

审计内容：

1. Static、Dynamic 内部算法是否保持原样；
2. Paper 的 37 个 midamble 时刻和更新路径；
3. 跳过 midamble 时的真实时间和相位推进；
4. Figure 12 条件与当前项目条件差异；
5. VP 候选、接纳、错误接纳、rate 更新和回退路径；
6. 普通接收机是否读取轨道或 payload 真值；
7. 结果目录是否与旧 Formal 隔离。

G0 有阻断项时，不进入任何新仿真。

### G1：最小 Smoke

用途：只检查程序链路，不用于性能结论。

```text
Case1 × [-30, -24, -21] dB
Case2 × [-30, -24, -21] dB
3-5 packets/cell
```

Smoke 必须确认：

- 输入配对；
- 失败包为 0；
- Case1 默认输出 Static；
- Case2 默认输出 Dynamic；
- 保存和断点续跑正常；
- 112 个符号的监测字段完整；
- 当前 Case1/Case2 接收机能够逐包复现。

### G2：少次数用户审查实验

这是 Formal 前的强制停止点。

#### G2-A：Case1/Case2 预览

```text
SNR = [-30, -27, -24, -21] dB
20 packets/SNR/Case
```

方法：

```text
Huang/PREC
当前 Stage55
新候选 Stage55
Paper Midamble-Point
Ideal/AWGN
```

#### G2-B：轨道预览

固定九个位置：

```text
[-366, -320.25, -274.5, -228.75, -183,
 -137.25, -91.5, -45.75, 0] s
```

SNR：

```text
[-24, -21.12] dB
```

预算：

```text
20 packets/position/SNR
```

少次数结果只允许用于发现明显错误，不用于发表统计显著结论。

## 7. 用户审查门

G2 完成后，主代理必须停止，不得自动启动 Formal。

必须提交：

```text
REVIEW_VALIDATION_SUMMARY.csv
REVIEW_CASE1_SER.png
REVIEW_CASE2_SER.png
REVIEW_ORBIT_SER.png
REVIEW_RESIDUAL_ACCUMULATION.png
REVIEW_RESIDUAL_HEATMAP.png
REVIEW_VP_DIAGNOSTICS.csv
REVIEW_CONFIG_AND_SEEDS.json
USER_REVIEW_GATE.md
```

`USER_REVIEW_GATE.md` 至少包含：

- 代码摘要和父依赖摘要；
- 配置 hash；
- seed 范围；
- 每单元包数；
- 完成/失败包数；
- Case1/Case2 Static/Dynamic 选择比例；
- 每位置五方法 SER；
- Paper 与 Stage55 的配对差值；
- VP 候选数、接纳数、错误率和最大空窗；
- 帧首、帧中、帧末残差；
- 回退次数；
- 已知异常和未解决问题。

只有用户明确回复：

```text
审查通过，可以进行 Formal
```

才能进入 G3。

如果用户没有明确批准，任务保持在 `AWAITING_USER_REVIEW`。

## 8. 必交图表

### 8.1 全轨迹 SER 图

文件：

```text
REVIEW_ORBIT_SER.png
```

要求：

- 横轴：轨道起点 `t0`；
- 纵轴：SER，log scale；
- 两个 SNR 使用两个 panel；
- 同时显示 Huang、Paper、当前 Stage55、新 Stage55、Ideal；
- `-21.12 dB` panel 叠加 Figure 12 归一化形态和本地端点映射目标；
- 清楚区分论文参考、映射目标和实测曲线。

### 8.2 Case1 SER-SNR 图

文件：

```text
REVIEW_CASE1_SER.png
```

少次数预览使用四个 SNR 点；Formal 使用完整 `-30:-21 dB`。

必须同时显示当前 Stage55 和新候选，避免图形覆盖掩盖退化。

### 8.3 Case2 SER-SNR 图

文件：

```text
REVIEW_CASE2_SER.png
```

要求同 Case1。Case2 改善允许，退化不允许。

### 8.4 残差累积图

文件：

```text
REVIEW_RESIDUAL_ACCUMULATION.png
```

瞬时残余 CFO：

\[
e_f(n)=f_{\rm true}(n)-f_{\rm applied}(n)
\]

累计 CFO RMSE：

\[
E_{\rm CFO}(n)
=
\sqrt{\frac{1}{n}\sum_{k=1}^{n}e_f^2(k)}
\]

累计相位误差：

\[
\phi_{\rm residual}(n)
=
2\pi T_s\sum_{k=1}^{n}e_f(k)
\]

至少显示：

```text
-366, -274.5, -183, -91.5, 0 s
```

方法：当前 Stage55、新 Stage55、Paper、Ideal。

真实 CFO 和真实误差只能离线绘图，不得反馈给接收机。

### 8.5 全轨道残差热图

文件：

```text
REVIEW_RESIDUAL_HEATMAP.png
```

```text
x = payload symbol index 1:112
y = orbit position
color = residual CFO RMSE / per-symbol SER
```

两个 SNR 分别输出或使用独立 panel。

## 9. 每符号必须保存的数据

```text
symbolIndex
absoluteTimeSec
trueCfoBins                    # 仅离线诊断
appliedCompensationBins
residualCfoBins                # 仅离线诊断
predictedRateBinsPerSec
rateUncertainty
staticLikelihood
dynamicLikelihood
selectedHypothesis
decisionPeakRatio
vpCandidate
vpAccepted
vpFalse                        # 仅离线诊断
innovationBins
innovationAccepted
phasePairUsed
historyCount
rollbackTriggered
hardSymbolError                # 仅离线诊断
```

普通接收机不得读取标记为“仅离线诊断”的字段。

## 10. G2 少次数审查条件

### 工程条件

- 所有预览单元完成；
- 失败包为 0；
- 相同 packet 的五方法输入指纹一致；
- 当前 Case1/Case2 能够复现；
- 所有 112 点监测完整；
- Paper midamble 数量和时刻正确；
- 无 payload/orbit truth 泄漏；
- 所有图来自真实逐包结果；
- 不使用平滑曲线掩盖异常。

### 性能预警条件

- Case1 新候选不得出现明显高于当前版本的点；
- Case2 不得明显退化；
- Paper 中间轨道不得出现异常尖峰；
- 新 Stage55 应在大多数预览位置低于 Paper；
- 帧末残差不得出现无法解释的发散；
- 错误 VP 必须与补偿偏移、SER 增长进行逐符号关联。

任一项明显失败，停止并返回代码/机制审计，不进入 Formal。

## 11. Formal 硬验收条件

### 11.1 Case1

优先要求相同输入下逐包一致：

```text
detected symbols identical
hard bits identical
SER identical
```

若候选确实需要切换，则 paired non-inferiority margin 预登记为：

```text
absolute SER margin = 0.002
relative margin = 5%
```

取更严格者。

### 11.2 Case2

要求：

```text
SER_new <= SER_current
```

使用 packet-level paired CI 判断。改善允许，退化不允许。

### 11.3 Stage55 相对 Paper

每个正式位置、每个 SNR：

\[
\Delta SER_i
=
SER_{\rm Paper,i}-SER_{\rm Stage55,i}
\]

必须满足：

```text
点估计 > 0
paired 95% CI 下界 > 0
```

否则不得宣称全轨道优于 Paper。

### 11.4 中间位置

预登记要求：

\[
SER_{\rm Stage55}(t_i)
\le
SER_{\rm Stage55}(0)
\]

中间位置差于 Case2 时，先判定为 gate/tracker 有效性风险。

### 11.5 VP 质量

必须报告：

```text
VP candidates/packet
accepted VP/packet
false VP rate
first accepted VP index
maximum VP gap
CFO-only update count
rate update count
rollback count
```

预警/阻断建议：

- `-21.12 dB` false-VP rate >2%：阻断；
- `-24 dB` false-VP rate >5%：阻断；
- payload 长区间无 VP：标记 coverage 不足；
- rollback 连续触发：阻断 Dynamic 晋升。

### 11.6 残余 CFO

报告：

- 每符号 RMSE；
- 95% 分位；
- 帧首、帧中、帧末；
- Hz 和物理 bin；
- 累计相位误差。

`0.5 bin = 15.26 Hz` 作为重要诊断线，但在 `-24 dB` 下不直接作为硬通过条件，因为 Ideal SER 本身约为 0.06。

## 12. 用户批准后的 Formal 预算

### Case1/Case2

```text
SNR = -30:-21 dB
1000 packets/SNR/Case
```

### 全轨道

```text
9 positions
2 SNR
1000 packets/position/SNR
```

### 统计

```text
10000 packet-level paired bootstrap draws
pointwise 95% CI
```

如果需要声明全轨道同时显著优于 Paper，应额外预登记多重比较处理或 simultaneous confidence band。

## 13. 最终晋升规则

候选只有同时满足下列条件才允许晋升：

```text
Paper Figure 12 归一化形态通过
Paper 本地 Case1/Case2 端点保持
Stage55 Case1 完整 SNR 曲线不退化
Stage55 Case2 完整 SNR 曲线不退化
Stage55 所有正式轨道位置显著优于 Paper
中间位置不差于 Stage55 Case2
逐符号残差、VP 和回退行为可解释
无 truth/orbit/SER 泄漏
独立确认 seeds 通过
用户明确批准 Formal
```

任一硬条件失败，候选保留为探索结果，不得使用同一确认数据继续调参后重新宣称通过。

## 14. 本次用户审查清单

请重点审查：

1. `0.10 decade` 的 Paper 形态 RMSE 是否合适；
2. `0.20 decade` 的单点偏差和异常跳变门槛是否合适；
3. Case1 non-inferiority margin 是否应进一步收紧为逐包完全一致；
4. 九个轨道位置是否足以代表“全轨迹”；
5. 少次数验证 20 包/单元是否合适；
6. Formal 1000 包/单元预算是否接受；
7. Stage55 中间位置必须不差于 Case2 是否保留为硬条件；
8. 用户审查通过的明确回复格式是否接受。
