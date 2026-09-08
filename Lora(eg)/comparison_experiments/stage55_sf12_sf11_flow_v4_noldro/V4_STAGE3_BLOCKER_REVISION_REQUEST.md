# V4 实验 A 阶段 3 阻塞现状与方案修订单

更新日期：2026-09-07  
方案标识：`V4-noLDRO-plan-R3-project-aligned`  
当前实施状态：`STAGE_03 = FAIL / DO_NOT_ADMIT_STAGE_4`

> 本文件供人工修改方案使用。它不是新的已批准方案，也不改变现有阶段门。人工修订并明确批准前，不运行新的 calibration、validation、smoke、formal，不进入实验 B。

## 1. 当前结论

阶段 1、阶段 2 已通过；阶段 3 的确定性机制测试已通过，但实验 A 的 Stage55 符号级质量门在允许的三轮参数预算内未通过独立 validation。

因此严格按现有方案停止：

- 不运行实验 A smoke；
- 不运行实验 A formal；
- 不生成 `EXPERIMENT_A_FINAL_AUDIT.md`；
- 不进入实验 B；
- 不把部分完成或高覆盖率冒充正式完成；
- 不通过第四轮调参、放宽 2% 门、降低接纳数或删除失败测试来制造 PASS。

## 2. 已完成内容

### 2.1 阶段 1：来源、接口和版本冻结

状态：`PASS`

- 冻结方案标识、方案 SHA-256、SF11 对齐记录和论文身份；
- 34 个 `upstream_sf11` 文件与规范 project 同名源码逐项 SHA-256 一致；
- SF11、V2、V3 建立只读目录摘要；
- 建立 `source_manifest.json`、`plan_manifest.json`、`result_contract.json`、`seed_protocol.json`、`calibration_protocol.json`、`frame_timing_manifest.json`；
- 活动 MATLAB path 不包含 `src/upstream_sf11`；
- calibration、validation、smoke、formal 使用独立种子域。

审计：`results/audits/STAGE_01_SOURCE_AND_INTERFACE_AUDIT.md`

### 2.2 阶段 2：公共 SF12 no-LDRO PHY

状态：`PASS`

- `physicalSf=12`、`effectiveDataSf=12`、`LDRO=false`；
- 4096 个直接物理标签，`dataBinSpacing=1`；
- 4096/4096 标签无噪声全枚举通过；
- 独立公式生成的 9 个 chirp golden vectors 通过；
- 独立 12-bit Gray 和交织向量通过；
- 第 11、12 位参与标签和交织；
- 非 4 倍数标签正常；
- 100000 个 Rician/复 AWGN 样本的单位功率、I/Q 方差机制检查通过。

审计：`results/audits/STAGE_02_COMMON_PHY_AUDIT.md`

### 2.3 阶段 3：实验 A 确定性机制

机制测试状态：`PASS`

已实现并验证：

- 独立 Track A 圆轨道模型；
- Case 前导起点为 `-366 s` 和 `0 s`；
- `8U + 2 down + 0.25 down + (DDD M)×7 + DD + terminal M`；
- 23 个直接物理标签、8 个 M、总时长 `41.25T = 1.351680 s`；
- Paper 初始 Point 和 Midamble CFO 均为有符号整数 FFT-bin estimator；
- Paper-native 调用链不含 sub-bin estimator；
- residual CFO 累加，更新只对后续时隙生效；
- terminal M 不改变本包过去判决，也不传给下一独立包；
- No-Doppler 无噪声诊断为零 SER；
- Track A Stage55 不调用 Hamming、块置信或相位对 CFO；
- VP 只能在数据符号完成后影响更晚的物理时隙；
- 相同 packet key 的标签、信道和噪声可复现。

## 3. 三轮 calibration / validation 真实结果

固定 validation 门：

- SNR：`-21 dB`；
- 每个 Case：2000 个独立 packet；
- `false-acceptance <= 2%`；
- `coverage >= 1%`；
- 每个 Case 接纳总数不少于 200；
- false-acceptance 分母是实际进入 tracker 的 VP 数；
- 不使用 SER、BER、论文 marker 或 Stage55-Paper 排序选择参数。

### 3.1 A-param-v01 / a_validation_v1

Calibration：`PASS`  
Validation：`FAIL`

| Case | packets | 可产生 VP | 实际接纳 | 误接纳 | false-acceptance | coverage |
|---|---:|---:|---:|---:|---:|---:|
| -366 s | 2000 | 46000 | 43375 | 2610 | 6.0173% | 94.2935% |
| 0 s | 2000 | 46000 | 42159 | 6213 | 14.7371% | 91.6500% |

结果：覆盖很高，但两个 Case 的误接纳均超过 2%。

证据：`results/validation/track_a/A-param-v01/track_a_validation.json`

### 3.2 A-param-v02

Calibration：`FAIL`  
Validation：`NOT_APPLICABLE`

更严格候选把 residual-peak ratio 设置过高，绝大多数候选接纳数为 0；没有候选同时满足误接纳与覆盖门，因此没有进入 validation。

第一次运行在抛出正确失败前没有保存失败 artifact。保存逻辑修复后，以完全相同的候选和确定性种子域复跑，只用于补齐证据；结果仍然失败，没有修改门或结果范围。

证据：`results/calibration/track_a/A-param-v02/track_a_calibration.json`

### 3.3 A-param-v03 / a_validation_v3

Calibration：`PASS`  
Validation：`FAIL`

选中候选 26：

```text
decisionPeakRatioThreshold = 6
maximumNormalizedEntropy = 0.1
residualPeakRatioThreshold = 1.01
innovationLimitBins = 0.25
residualStepBins = 0.05
historyDecay = 0.85
huberThresholdBins = 0.15
maximumRateBinsPerSec = 12
```

| Case | packets | 可产生 VP | 实际接纳 | 误接纳 | false-acceptance | coverage |
|---|---:|---:|---:|---:|---:|---:|
| -366 s | 2000 | 46000 | 3820 | 175 | 4.5812% | 8.3043% |
| 0 s | 2000 | 46000 | 2098 | 1965 | 93.6606% | 4.5609% |

低 SNR 安全域没有 NaN/Inf，但覆盖基本为零；它不能覆盖 -21 dB 主质量门失败。

证据：`results/validation/track_a/A-param-v03/track_a_validation.json`

## 4. 当前机制问题

### 4.1 直接观察

Case 0 是高 Doppler-rate 条件。无噪声诊断中：

- 第一个数据符号中心真实 CFO 约为 `-3.2214 bin`；
- Point 初始整数估计为 `-3 bin`；
- 若早期两个正确 VP 均被接纳，斜率可观测后可以跟踪后续变化；
- 严格门可能漏掉第二个早期正确 VP，使 rate 保持 0；
- CFO 误差随后越过半 bin，随机 payload 的硬标签发生整数偏移；
- 错误标签有时仍呈现高峰值、低熵和较小局部 residual，因此可能被当成高质量 VP；
- 一旦错误 VP 进入 tracker，会形成错误分支的自洽跟踪，导致 Case 0 的误接纳显著增加。

### 4.2 质量门的结构性张力

当前无编码符号级适配器只观察单符号 FFT 和自身预测：

- 放松门：能尽早获得两个 rate 测量，但噪声错误也更容易进入 tracker；
- 收紧门：误接纳未必足够下降，同时容易错过最早的 rate 证据；
- 错过早期 rate 后，后续整数-bin 错误可能在局部质量指标上看起来很“自洽”；
- Track A 又明确禁止使用 Hamming 软迭代、真值、未来数据和轨道先验。

在现有机制与三轮预算内，没有找到同时满足 2% 误接纳、1% 覆盖和至少 200 次接纳的参数。

### 4.3 尚不能宣称的结论

- 不能仅凭当前结果断言任何可能的无编码 Stage55 机制都不可行；
- 只能断言“当前已实现的符号质量机制，在当前候选预算和固定 validation 门下未准入”；
- 不能把 validation 性能当作 formal 方法比较；
- 不能从 validation 结果选择有利曲线或宣称 Paper/Stage55 的正式优劣。

## 5. 当前审计状态

| 项目 | 状态 | 说明 |
|---|---|---|
| 来源与只读边界 | PASS | 规范源码和快照一致，SF11/V2/V3未修改 |
| 公共 no-LDRO PHY | PASS | 独立 golden vectors 和全标签测试通过 |
| Track A Paper-native机制 | PASS | 整数bin、因果、terminal M隔离通过 |
| Track A Stage55无Hamming身份 | PASS | 独立符号级路径 |
| Calibration轮次预算 | PASS | 恰好执行3轮，没有追加第4轮 |
| Independent validation | FAIL | v1和v3均超过2%误接纳门 |
| Track A smoke | BLOCKED | validation未通过 |
| Track A formal | NOT_APPLICABLE | 未启动 |
| Track A最终审计 | NOT_APPLICABLE | 未到阶段5 |
| Experiment B | BLOCKED | 实验A结束审计未通过 |
| V4最终完成 | BLOCKED | 阶段链未完成 |

完整阶段审计：`results/audits/STAGE_03_EXPERIMENT_A_SMOKE_AUDIT.md`

## 6. 不允许直接采取的操作

在方案修订前禁止：

1. 运行第四轮参数搜索；
2. 继续使用 `a_validation_v1/v2/v3` 数据选参数；
3. 将 false-acceptance 门从 2% 放宽；
4. 将 coverage 门降到 1%以下或接纳数降到200以下；
5. 把零接纳的退化接收机认定为通过；
6. 引入 Hamming、Payload truth、true CFO/rate、轨道真值或未来符号；
7. 删除失败测试、扩大容差或修改误接纳分母；
8. 跳过实验A结束审计直接进入实验B；
9. 将现有 validation 输出称为 smoke 或 formal；
10. 将不同代码、参数、种子或签名的结果拼接。

## 7. 需要人工修订并明确批准的决策

请直接修改本节。未选择的项保持 `UNDECIDED`。

### 决策 A：实验 A 的后续处理

当前选择：`UNDECIDED`

可选方向：

- `A1_STOP_AND_REPORT`：接受当前机制未准入，实验A正式标记未完成，V4不进入实验B。
- `A2_REDESIGN_TRACK_A_STAGE55`：允许先修改符号级Stage55机制，再建立全新代码/参数/validation版本；固定物理条件、Paper身份和质量门不变。
- `A3_DECOUPLE_EXPERIMENT_B_GATE`：允许实验A以失败审计结束，但解除“实验A未通过不得进入实验B”的依赖；实验A不冒充完成，实验B独立推进。
- `A4_OTHER`：请写出完整规则。

填写：

```text
DECISION_A = UNDECIDED
RATIONALE_A =
```

### 决策 B：若重构 Track A Stage55，允许的新增可见机制

当前选择：`UNDECIDED`

候选机制必须只使用截至当前时刻的接收机可见信息。可考虑：

- `B1_CAUSAL_TWO_MEASUREMENT_BOOTSTRAP`：早期候选先进入 pending，两个不同时间测量通过联合斜率/残差一致性后再一起提交；不得回写过去数据判决。
- `B2_MULTI_SYMBOL_CAUSAL_CONFIRMATION`：使用固定长度的过去符号窗口确认整数分支；只允许影响确认完成后的未来时隙。
- `B3_FAIL_CLOSED_BRANCH_LOCK`：检测到分支不一致时停止VP更新并报告失锁，不将可疑高置信错误标签加入tracker。
- `B4_COMBINATION`：组合以上机制，并明确发布/应用时刻。
- `B5_OTHER`：请给出数学定义和可见输入。

填写：

```text
DECISION_B = UNDECIDED
ALLOWED_OBSERVATIONS =
FORBIDDEN_OBSERVATIONS = payload truth; true CFO/rate; orbit truth; future samples
PENDING_RELEASE_RULE =
FIRST_EFFECTIVE_TIME_RULE =
```

### 决策 C：新的开发与validation预算

当前选择：`UNDECIDED`

如允许重构，必须明确新的预算，不能默认延用或无限增加：

```text
NEW_ALGORITHM_VERSION =
MAX_NEW_PARAMETER_ROUNDS =
MAX_CANDIDATES_PER_ROUND =
NEW_VALIDATION_DOMAIN_NAMES =
PACKETS_PER_CASE_AT_MINUS21_DB =
LOW_SNR_SAFETY_PACKET_COUNTS =
KEEP_FALSE_ACCEPTANCE_MAXIMUM_2_PERCENT = YES
KEEP_COVERAGE_MINIMUM_1_PERCENT = YES
KEEP_ACCEPTED_MINIMUM_200 = YES
```

建议默认：新算法版本与旧三轮完全隔离；最多2轮、每轮最多32组；每轮通过后仍以每Case 2000个全新packet作validation。

### 决策 D：既有失败证据的保留规则

建议填写：`KEEP_ALL_AS_SUPERSEDED_FAILURE_EVIDENCE`

```text
DECISION_D = KEEP_ALL_AS_SUPERSEDED_FAILURE_EVIDENCE
ALLOW_OVERWRITE_V1_V2_V3 = NO
ALLOW_MERGE_WITH_NEW_RESULTS = NO
```

### 决策 E：实验 B 是否仍依赖实验 A PASS

当前选择：`UNDECIDED`

```text
EXPERIMENT_B_ENTRY_RULE = REQUIRE_A_PASS | ALLOW_AFTER_A_FAILED_CLOSEOUT
```

若选择 `ALLOW_AFTER_A_FAILED_CLOSEOUT`，仍须先生成实验A失败结束审计，明确A未完成；不得把解除依赖解释成实验A通过。

## 8. 建议的修订后阶段门

若选择重构实验A，建议新增阶段 `3R`，替代直接重复原阶段3：

1. 冻结新机制的可见输入、pending状态和发布时间；
2. 新增相同前缀/不同未来、延迟发布、错误分支和失锁测试；
3. 以机制指标选择参数，不使用SER/BER排序；
4. 使用全新 calibration 和 validation 域；
5. 通过原2%/1%/200门后才运行新smoke；
6. 阶段3R审计PASS后才进入阶段4；
7. 原v1/v2/v3始终保留为失败证据。

若选择解除实验B依赖，建议顺序为：

1. 生成 `EXPERIMENT_A_FINAL_AUDIT.md`，总体标记 `FAIL`；
2. 明确 Track A formal 未运行、结论边界仅到validation；
3. 记录用户批准的新实验B准入规则及其方案哈希；
4. 再进入实验B阶段6，不回填实验A PASS。

## 9. 修订批准记录

请在修改完成后填写：

```text
REVISED_PLAN_ID =
REVISION_DATE =
APPROVED_BY =
DECISION_A =
DECISION_B =
DECISION_C =
DECISION_D =
EXPERIMENT_B_ENTRY_RULE =
ADDITIONAL_CONSTRAINTS =
```

修订稿批准后，实施方应先计算本文件 SHA-256，将其加入新的 `plan_manifest`，再执行任何代码或实验变更。
