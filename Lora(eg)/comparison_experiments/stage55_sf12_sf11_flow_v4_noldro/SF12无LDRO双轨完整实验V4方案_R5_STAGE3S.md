# SF12 无 LDRO 双轨完整实验 V4 方案（R5：Point 锚定早期因果锁定）

修订日期：2026-09-08。

方案标识：`V4-noLDRO-plan-R5-track-a-point-anchored-lock`。父方案为 R4；R3/R4 已签名失败事实永久保留。本版只修正 Track A Stage55 启动机制，公共 PHY、Paper-native、统计门、固定 formal 预算和实验 B 依赖继续继承。

实施授权：用户明确要求将本修正写入方案并持续执行，允许自动修复确定性代码、测试与审计缺陷并重跑受影响范围。不得把性能不利或质量门失败伪装为代码错误；不得放宽门、删除失败测试、拼接签名或追加未注册样本。

## 1. R4 错误定位

R4 允许跳过 D1/D2 后在最近三个 D 中重新寻找双测量组合。Case 0 中 Point 为 -3 bin，D1 真实 CFO 约 -3.2214 bin，D2 约 -3.5211 bin；rate=0 时 D2 已越过半 bin。R4 可在 D6/D8 等位置将两个错误但局部自洽的硬标签提交，造成 92%–99% 的 Case 0 误接纳。

R5 禁止晚期启动，改为 Point+D1 provisional 预测 D2，再由 D2 确认。

## 2. 固定物理与身份

- SF12、BW/Fs=125 kHz、LDRO=false、4096 直接标签；
- Track A 两个 Case、23D、8M、41.25T；
- Paper-native 仍只使用整数 FFT-bin Point/Midamble；
- Stage55 不读取 M，不使用 Hamming、相位对、真值、轨道先验或未来样本；
- terminal M 不影响本包过去判决或下一包；
- validation 仍为误接纳≤2%、coverage≥1%、实际接纳≥200；
- 实验 B 仍要求实验 A 完整结束审计 PASS。

## 3. 精确时序

Point 中心/可用时刻为 9.5T/10T；D1 中心/可用为 10.75T/11.25T；D2 为 11.75T/12.25T。D1前rate=0。

```text
provisionalRate=(d1CfoCandidate-pointCfo)/(10.75T-9.5T)
predictedD2Center=d1CfoCandidate+provisionalRate*T
lockedRate=(d2CfoCandidate-d1CfoCandidate)/T
```

Point 是训练锚点，不计 VP。D1一旦形成 provisional 状态并影响D2，即按实际提交VP计数；D2失败不得撤销D1。离线算法逻辑处理延迟为0，runtime仅作诊断；人工延迟测试必须顺延首次生效时隙。

## 4. 状态机

```text
POINT_ANCHORED_PENDING -> PROVISIONAL -> LOCKED -> LOST
```

- 仅D1可启动。D1质量、residual、速率任一门失败即LOST，不允许D2–D23重捕获。
- D1通过后提交D1，provisional CFO/rate只影响D2及以后。
- D2必须通过单符号门和provisional残差门；通过后提交D2并用D1/D2建立LOCKED，Point不进入VP history。
- D2失败即LOST。
- LOCKED继续使用单符号质量、预测innovation、history残差、rate边界、rolling-8、衰减和Huber。
- LOCKED中连续3个D未提交、非有限估计、秩失败或可见整数分支冲突均进入LOST。
- LOST后包内不重捕获、不新增VP，保持最后可信CFO/rate预测，所有D仍计入分母；包间全部重置。

## 5. 版本、种子和候选

算法：`Stage55-A-point-anchored-provisional-lock-v2`。

```text
mechanism=710000000 calibration_v1=720000000 calibration_v2=721000000
validation_v1=730000000 validation_v2=731000000
safety_v1=740000000 safety_v2=741000000 smoke=750000000
formal=760000000 bootstrap=770000000
```

第一轮32组全因子：decision peak `[1.5,3.0]`、entropy `[0.50,0.80]`、residual peak `[1.01,1.10]`、max rate `[12,20]`、D2确认残差 `[0.15,0.30]`。

第二轮32组：decision peak `[2.5,4.0]`、entropy `[0.35,0.65]`、residual peak `[1.01,1.05]`、max rate `[10,18]`、D2确认残差 `[0.10,0.20]`。

固定：residual step 0.05 bin、LOCKED innovation 0.35 bin、history残差0.30 bin、historyDecay 0.85、Huber 0.15 bin、连续拒绝3、history长度8。

每轮每候选每Case固定500 packet，共1000物理packet/32000候选接收机评估；每25物理packet checkpoint。两个Case分别满足2%/1%，calibration coverage门对应至少115次提交。候选按最小Case coverage、两Case等权CFO RMSE、编号排序，不使用SER/BER/Paper排序。

## 6. Validation、安全与 smoke

唯一候选在对应全新域运行每Case 2000 packet、-21 dB validation；coverage至少460次提交，显式200次门保留。通过后在-30/-25 dB每Case各500 packet检查数值、因果和LOST安全，再以新域每Case 16 packet运行完整 smoke、恢复、统计、报告和成本估算。

## 7. 新测试门

必须验证Point时间、D1前rate=0、Point不计VP、Case 0无噪声D1/D2正确、D1仅影响D2以后、D1/D2失败立即LOST、禁止晚期启动、D1/D2不可变标签、前缀因果、处理延迟、连续拒绝、checkpoint、错误D1真实计分、无禁止输入、Paper回归和R3/R4证据哈希。

## 8. 阶段门

阶段3S依次执行来源冻结、机制实现/测试、calibration v1、必要时v2、validation、安全、smoke和最终审计。每个子阶段先审计。确定性缺陷修复后重跑受影响范围；若两轮质量门耗尽仍失败，保留FAIL，不以调参方式追加轮次。进一步结构修正必须登记新方案/算法/种子/签名后再执行。

只有阶段3S PASS，才进入实验A formal、实验A结束审计、实验B和V4总审计。
