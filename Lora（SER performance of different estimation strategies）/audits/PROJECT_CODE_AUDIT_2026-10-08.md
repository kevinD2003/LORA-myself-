# 项目代码审计与问题报告

审计日期：2026-10-08，Asia/Shanghai。  
项目：`D:/codex/Lora（SER performance of different estimation strategies）`。  
审计方式：本次独立只读审阅、静态检查、已有结果复载；未调用其他代理，未修改接收源码、参数、检查点或结果，未启动波形仿真，也未执行会重新导出结果的 runner/plot/validator。审计结束后仅新增本报告和项目说明文档。

## 1. 总体结论

**审计完成，但不能给全项目“无条件正确/已通过最终验收”的结论。**

- 最新两组四曲线结果的数据完整性、整数错误计数、SER 分母、源码/输入签名和 MAT/CSV 一致性通过本次独立复核。
- 97 个活动 MATLAB 文件的 `checkcode` 均为 0 发现。这是静态检查结果，不是算法正确性、统计充分性或性能达标证明。
- 当前 V8 的完整相位轨迹融合、原生帧、统一入口以及接收后离线 Ideal 的主要实现路径未发现此前“只把 Dynamic rate 锚定到 Static CFO”的错误。
- 发现 9 项需要处理或明确的问题，另列 5 类风险/研究限制。最优先的是 Formal 验收条件缺失、Review 恢复/seed 身份不兼容、中央镜像点的重采样结构、失败包口径不一致和 Case-SNR 遥测缺失。
- **V8 Formal 仍不具备启动/验收条件**：Case2 的预注册绝对 SER 容差仍为 `null`。旧 EXP1 的 Formal 已完成，并不意味着 V8 Formal 已完成。

本报告不是对论文逐页、逐公式复现的认证，也不是对所有历史候选、所有潜在输入和硬件实现的穷尽证明。

## 2. 范围与方法

### 2.1 覆盖范围

1. 公共层：`configs/`、`src/`、`scripts/`、`tests/`。
2. 当前方法：`senlora_symmetric_v8/` 的正式入口、相位融合、Joint-block 解码、信道生成、Theory、运行器、统计/绘图和关键测试。
3. 实际依赖：V6-native 所调用的 V6/V3/V2、父库的 PHY、前导 ML、滚动预测、CR3/Hamming、PREC 及 RNG/参数加载路径。
4. 数据：冻结 Review、最新 Case-SNR Rician 20,000 行和 Figure12 AWGN/Rician 10,000 行。
5. 版本材料：根 README、冻结清单、详细流程和已有验证说明。

历史候选和备份用于版本定位与调用链核对，没有逐行证明每一份弃用实现。97 文件静态检查包括活动目录中的历史模块，但不包括 `audit/` 内的 before-image 副本。旧 EXP1 的全部逐包数据没有在本次再次全量重算。

### 2.2 本次实际执行的检查

| 检查 | 本次结果 | 含义/限制 |
|---|---|---|
| 活动文件起止快照 | 119 份 `.m/.json/.md` 和根规格文件，审计前后哈希相同 | 审计期间所检查的源码与既有说明没有被本次改动 |
| MATLAB 静态检查 | 97 文件，0 文件有发现，0 条 `checkcode` 发现 | 不等于动态测试全部通过 |
| 公共 PHY | SF12、4096 FFT/bin、Ts=0.032768 s、768 信息位、112 数据符号 | 与当前代码一致，不是文档中的 1024 bin |
| 父库冻结清单 | 52 项匹配 | 本次运行 `exp1ValidateFrozenParent`，只读检查依赖及哈希 |
| V8 冻结源码 | 6 份匹配 | `d0=0.10`、`d1=0.80` 的已冻结接收源码未变化 |
| Review 冻结证据 | 3 份匹配 | RESULT、CHECKS、RAW_PACKETS 文件 SHA256 与冻结清单一致 |
| Review 完成量 | 900/900 镜像对-包，1800 帧；错误 V8/V6/Ideal=20/20/16 | 原始观测，不代表已满足 Formal 容差 |
| 最新 Case-SNR | 20,000 行、20 单元、每单元 ID 1–1000 | 整数错误计数与汇总相符；失败/禁用标志为 0 |
| 最新 Figure12 | 10,000 行、10 单元、每单元 ID 1–1000 | 同上，SER 为错误数/112000 |
| 完整结果与检查点 | 两组 RESULT 与 CHECKPOINT 完全相等，状态摘要有效 | 未调用续跑，不重写 CSV/PNG |
| 执行来源 | 两组 source/input SHA256 均匹配 | 不是只看文件是否存在 |
| 函数解析 | CommonBootstrap、SymbolLikelihood、ModulateSymbol、V8、PREC 解析到预期目录 | 本次未发现这些关键函数的路径串用 |
| Review 当前恢复签名 | 不匹配：identity 与 executionSourceSha256 不同 | 旧数据未损坏，但不能从当前入口直接按新身份恢复 |
| Review 包身份重算 | 当前 Frozen plan 的 900/900 组不匹配；保存的执行身份重算 0/900 不匹配 | 源码签名一致性与包身份复现是不同的检查 |

本次没有重新运行解码测试或生成测试帧。历史日志记录的 Paper/Pilot 共 9 项 PASS 以及置信区间绘图验证 PASS，被作为既有证据阅读，**不写成本次新测试通过**。

### 2.3 最新数据复核的总数

错误列顺序为 `PREC / VP / comparison / native Ideal / comparison Ideal`：

- `pilot_time_aligned_case_snr_rician`：`1553940 / 962462 / 1299437 / 872393 / 872080`。
- `figure12_pilot_time_aligned`：`608306 / 19519 / 42587 / 17336 / 17380`。

上述总数混合多个 SNR 或信道，不能把其总体平均直接当成某个固定工作点的 SER。`comparison` 是时间对齐变体，不是原论文 Eq17。

## 3. 已确认的问题

优先级：P1=正式验收阻塞；P2=需在下一轮发布/正式运行前处理；P3=文档、元数据或使用风险。这里区分“代码路径确实存在的问题”与“当前发布数值已经错误”：本次未发现最新 30,000 行 SER 因这些问题被篡改。

### F01 — P1：V8 Formal 的 Case2 容差未预注册

**证据**：

- [v8_frozen_receiver_manifest.json](<D:/codex/Lora（SER performance of different estimation strategies）/senlora_symmetric_v8/v8_frozen_receiver_manifest.json:15>) 中 `case2AbsoluteSerTolerance=null`。
- 状态为 `frozen-awaiting-case2-formal-tolerance`，`formalStarted=false`。
- `V8_FROZEN_RECEIVER.md` 已明确记载此限制。

**影响**：Case2“与 Ideal 的差异在容差内”没有数值判据，无法作预注册的非劣/等效验收。Review 中“不显著更差”或均值差为 0 不等于通过一个未定义的容差。

**建议**：先书面冻结容差、目标上界、检验方向、置信水平、相邻/镜像的判定和多重比较规则，再使用未见 Formal 种子。明确这些条件前不把旧 EXP1 Formal 或五点 1000 包测试作为 V8 Formal。

### F02 — P2：Review 中央相邻点没有保留同包配对重采样

**证据**：

- [runSenloraSymmetricV8JointBlockReview.m](<D:/codex/Lora（SER performance of different estimation strategies）/senlora_symmetric_v8/runSenloraSymmetricV8JointBlockReview.m:398>) 对所有相邻点统一调用 `localIndependentBounds`。
- 该函数在第 457 行起独立抽取两组索引。
- 本次从保存的 18 点表确认，中央相邻点 `-3.93216 s → 0 s` 都属于 pair 9，两个 side 共享同一组 payload/noise seed 和 packet ID。

**影响**：同一镜像对的相邻比较本应保留同包相关性，独立抽样可能给出不同的方差和区间。本次中央左侧原始错误为 0、右侧为 2；由于左侧样本为常数，当前区间未必因此改变，不能据此声称当前 SER 数值错误。但重采样结构对后续非零样本并不正确。

**建议**：同 `pairIndex` 的相邻两侧使用配对差值重采样；不同独立 pair 才用独立两样本重采样。增加能暴露正/负相关差异的合成统计测试，而不重新生成 RF 波形。

### F03 — P2：失败包处理与完成状态在运行器之间不一致

**证据**：

- 公共 [exp1EvaluatePacket.m](<D:/codex/Lora（SER performance of different estimation strategies）/src/exp1EvaluatePacket.m:103>) 的异常包按全部数据符号/信息位错误计入，与 EXP1 冻结规格一致。
- V8 AWGN [runSenloraSymmetricV8CaseSnrCurve.m](<D:/codex/Lora（SER performance of different estimation strategies）/senlora_symmetric_v8/runSenloraSymmetricV8CaseSnrCurve.m:193>) 将失败错误数设为 `NaN`，第 379 行起排除失败包，以 `validPackets*112` 作分母。
- Rician 对应运行器采用相同成功包条件口径，且输出仍可为 `RICIAN_CASE_SNR_COMPLETE`，失败数量另放在字段中。
- 四曲线运行器则把比较解码失败计为 112 错，并使用 `COMPLETE_WITH_VALIDATION_FAILURE` 状态。

**影响**：有失败时，不同系列的 SER 不再是同一口径。若失败更常发生于困难包，成功包条件 SER 会偏乐观；即使保存了失败字段，“COMPLETE”和图上的 1000 包标签也容易被误读。

**当前数据**：此次复核的最新两组失败为 0，未发现由失败包排除导致的当前数值偏差。

**建议**：显式区分 `attempted/all-packet SER` 和 `successful-packet conditional SER`；统一失败门。至少在有失败时不发布正常成功状态，并让图/汇总注明实际分母。

### F04 — P2：Case-SNR 四曲线的 gain、VP block 遥测丢失

**证据**：

- [runSenloraPaperPointFourCurves.m](<D:/codex/Lora（SER performance of different estimation strategies）/senlora_symmetric_v8/runSenloraPaperPointFourCurves.m:266>) 初始化 `gain/ vpBlocks=NaN`，仅在 `Stage="Figure12"` 时复制 native 参考值。
- 本次复载确认 Case-SNR 20,000 行的 `rateGain` 和 `acceptedVpBlocks` 全为缺失；Figure12 10,000 行则没有缺失。

**影响**：SER 保持正确，但无法用这份 Case-SNR 四曲线表分析 Static→Dynamic 融合和 VP 行为；不能把缺失当成 gain=0 或 VP=0。

**建议**：从已验证的 native 基线按相同包 ID/seed 只读复制对应遥测，或明确删去不可用字段/标注来源。无需为了补齐这些字段重新解码已完成包；若改运行器，需新版本或受控签名迁移。

### F05 — P2：轨道函数与配置字段存在“看似可配置、实际未使用”的差异

**证据**：

- [exp1TrackAOrbit.m](<D:/codex/Lora（SER performance of different estimation strategies）/src/exp1TrackAOrbit.m:5>) 硬编码 `re=6371e3`、`height=550e3`、`mu=3.986004418e14`、`c=299792458`，实际仅从配置读取载频。
- 父配置同时列出光速 `3e8`、轨道高度、倾角、地球自转和仰角等字段，但这些字段没有进入该函数的二维距离/Doppler 计算。

**影响**：默认高度/半径大体一致，不据此判定现有冻结波形错误。但用户只改配置中的高度、倾角或地球自转，可能以为信道改变，实际 Doppler 仍不变。当前距离公式对应简化共面过顶通道，不能把未使用的倾角/仰角字段说成已仿真的轨道条件。

**建议**：明确 Track-A 是冻结的简化模型，列出实际使用常数；若以后让轨道可配置，应同时版本化模型、测试和全部结果签名，不能静默替换当前冻结波形。

### F06 — P3：详细流程文档把 4096 维写成 1024 维

**证据**：[CURRENT_CODE_DETAILED_FLOW.md](<D:/codex/Lora（SER performance of different estimation strategies）/senlora_symmetric_v8/CURRENT_CODE_DETAILED_FLOW.md:163>) 写“1024 维 log probability”。

**实际**：当前 `physicalSf=effectiveDataSf=12`、no-LDRO，`dataAlphabetSize=samplesPerSymbol=4096`；BlockLikelihood 和 SymbolLikelihood 使用 4096 bin。

**影响/建议**：代码未因此出错，但说明和公式推导容易套用 LDRO/SF10 口径。应修正文档，不通过修改代码去匹配错误文字。本次新项目说明采用 4096，原说明文件未被改写。

### F07 — P3：部分遥测名称不等于其字面物理含义

**证据**：父库 [v4RollingTrackerPass.m](<D:/codex/Lora(eg)/comparison_experiments/stage55_sf12_sf11_flow_v4_noldro/src/stage55/v4RollingTrackerPass.m:167>) 用 `isfinite(InitialRateBinsPerSec)` 标记 `usesCrossFrameRate`。V8 传入的却是同帧前导估计的 rate。

**影响**：字段可为 true，但并没有跨帧估计。不能凭该字段判定独立帧方案违规，也不能把它直接作为跨帧消融证据。

相关计数还要区分：`blockAccepted` 是质量过门；最后 block 不写未来历史；`acceptedVirtualPilots` 是已应用 block 的符号等价数，实际历史每接受一个 block 只增加一条 CFO 观测。它不等于同数量的独立逐符号 VP。

**建议**：改进名称或增加明确定义。父库是冻结依赖，后续如改源文件，需同步版本化，不在审计中直接修改。

### F08 — P3：根目录的“当前状态/快速开始”容易指向旧实验

**证据**：根 README 的主身份仍是 `EXP1-SF12-ORBIT-POSITION-V2`、157T 共同波形和已完成的 EXP1 Formal；当前 V8、不同 Paper frame 和最近四曲线主要位于子目录。

**影响**：直接运行 `runExp1Formal` 得到的是旧 EXP1，不是 120T V8 的 9000 镜像对-包 Formal。四曲线运行器默认 `PaperPoint` 也不等于最新 `PilotTimeAligned` 结果。

**建议**：增加入口/实验系列索引，把阶段状态绑定到实验 ID。新项目说明提供此索引；本次不改原 README，以免影响主线程正在使用的材料。

### F09 — P2：现有 Review 缓存与当前 Frozen 入口不兼容，包身份也不能按新计划重算

**本次补充只读实测**：

- 保存的 Review signature identity 为 `EXP5-SENLORA-SYMMETRIC-NATIVE-V8`；当前计划为 `EXP5-SENLORA-SYMMETRIC-NATIVE-V8-FROZEN`。
- 调用纯签名构造函数生成当前签名，发现 `identity` 与 `executionSourceSha256` 两项不匹配。未执行 Review runner。
- [runSenloraSymmetricV8JointBlockReview.m](<D:/codex/Lora（SER performance of different estimation strategies）/senlora_symmetric_v8/runSenloraSymmetricV8JointBlockReview.m:255>) 严格比较 `jsonencode(state.signature)`，因此当前入口不能直接复用这一旧检查点。
- [senloraSymmetricV3SeedPlan.m](<D:/codex/Lora（SER performance of different estimation strategies）/senlora_symmetric_v3/senloraSymmetricV3SeedPlan.m:17>) 把 `plan.identity` 放进 RNG key。本次只重算 seed、没有生成波形：当前 plan 的 900/900 组 payload/noise seed 不匹配保存数组；使用保存的 `executionSignatureAtRun.identity` 则 900 组全部匹配。

**影响**：旧 1800 帧与冻结证据仍完整可信；问题在于“现在可从相同 root/pair/packetId 重算同一包、直接恢复完成检查点”的复现预期不成立。仅把旧 signature 改成 Frozen 会掩盖命名域改变，不能当作透明迁移。

**建议**：保留旧数据和原执行签名；回放旧包使用已保存的 ledger/执行身份。新的 Frozen Review 使用版本化输出目录和明确的新身份，或设计能验证旧执行/seed 身份的只读兼容路径。不要清空旧检查点，也不要把新旧命名域的包混为同一集合。

## 4. 风险与研究边界，不作为已证实泄漏/损坏

### R01：禁止信息与冻结身份的验证目前仍依赖调用约定

`localFlag/localForbidden` 在字段缺失时视为 false。正式入口主要检查 `plan.parametersFrozen`，而整套源码/参数冻结更多由外层 runner 校验。传入的完整 `config/plan/observation` 也含有 SNR、轨道网格或噪声方差等额外字段，尽管当前核心路径没有读取其禁止用途。

本次没有发现真实 Doppler、真实符号、实际轨道位置或目标 SER 被传给 V8 的估计/判决过程。风险是未来改代码时“缺字段也通过”和大配置接口可能削弱防误用。建议禁止信息标志必需、类型明确，并测试改变额外字段不会改变接收输出；不要把自报 false 当成静态/动态检查的替代品。

### R02：旧持久化层的数据完整性门弱于新四曲线层

旧 `exp1RunCell` 缓存更多依赖执行签名；Review 恢复主要检查签名、字段与形状，没有新四曲线那样的状态数组摘要。冻结清单记录的 Review 文件哈希提供外部保护，本次三份证据确实匹配；不能因此说旧缓存发生过损坏。

建议统一执行身份与数据完整性门：同一源码签名并不保证 MAT 内计数没有变化。任何迁移只改声明过的元数据，并保留 before-image 和数组等价性检查。

### R03：核心行为测试仍需加强

V8 ModelTest 有数值相位端点测试，但多项测试是源码 `contains(...)` 检查。Paper/Pilot 测试对权重、无噪声轨道、符号/频率边界和额外字段隔离有价值，不等于完整 Joint-block 回归。

建议优先补行为测试：当前 block 选择/未来历史更新的分离、拒绝质量门后的输出、最后 block、gain 端点、强噪声/边界残差、同包差值重采样及失败包分母。分析统计的测试可以是小型合成数组，不需要大批量 RF 仿真。

### R04：MATLAB heap corruption 根因未定位

既有运行记录多次出现 Windows `0xC0000374`；短进程、串行和固定 ID 断点重试最终完成。完整记录和本次复载没有发现计数/签名异常，但不能把“当前结果核验通过”解释成 MATLAB 环境已修好。

本次只读检查正常退出 0。后续应保留失败与正常退出记录，避免根据输出质量重选包；必要时另行进行环境诊断，不在本审计中安装、升级或修改 MATLAB 配置。

### R05：发表/验收结论不能越过数据和模型边界

- 当前正式 V8 是 Joint-block CFO/Hamming 版本：第一遍解码主要提供预测与诊断，第二遍重新选择当前 block 的 CFO。它不是“把第一遍重编码符号固定为第二遍独立标签”的原始草稿路径。
- 质量门决定是否写入后续历史，不决定是否采用当前 block 已选定的补偿结果。这一语义须在方法定义中明确。
- 代码采用离散 CFO 网格与 Hamming bit-LLR 综合评分。“Joint ML”工程名称不自动证明全帧、全码字、连续 CFO/rate 空间的全局最优性。
- Native 为 120T；当前 Paper/Pilot 为 234.25T，约 1.952 倍时长。相同 payload/noise seed 不等于相同物理帧、相同总能量或相同数据时间点。
- Pilot 时间对齐变体使用右侧已观测导频，最小依赖是一导频后瞻；当前 MATLAB 函数先读取整帧全部导频，是批处理实现，不是已完成的实时单符号缓存实现。
- AWGN/packet-flat Rician 不包含路径损耗随位置变化、频率选择性多径、采样误差、真实同步获取等完整链路因素。
- Theory 是未编码 FFT 判决的总体期望，不是每批有限样本点的强制下界。当前 AWGN 五点 VP/同帧 Ideal 错误总数为 78/76；不能靠抬高 VP、压低理论或重选 seed 消除反转。
- 稀少错误、零错误和“不显著”不等于等效证明。逐点 CI 不是全轨同时置信带；镜像/相邻多重比较在 Formal 前需要明确。

## 5. 修复/决策顺序

1. **先明确 Formal 判据**，特别是 Case2 容差；并明确接受的是当前 Joint-block 方法定义。
2. **先闭合 Review 恢复和 seed 身份**，再修统计与失败门：中央同包配对、失败分母和状态；补小型行为测试。
3. **补机制记录**：复用已验证 native 遥测，说明 block/符号等价 VP 的单位。
4. **修文档/配置接口**：4096 维、实际轨道常数、实验入口、非流式实现说明。
5. **再评估 Formal**：冻结代码/参数/判据，使用真正未见的 Formal 包集合；不根据已有曲线拟合、平滑或强制排序。

以上是待授权事项，不是本次已执行的修复。文档生成不会改变现有源码签名、结果数组或原图。

## 6. 审计证据定位

- `configs/parent_source_manifest.json`：52 项父库冻结证据。
- `senlora_symmetric_v8/v8_frozen_receiver_manifest.json`：6 源码/3 Review 文件哈希及缺失的 Formal 容差。
- `results/senlora_symmetric_v8/joint_block_review/`：Review 原始包、18 点、配对/镜像/相邻表。
- `results/senlora_symmetric_v8/pilot_time_aligned_case_snr_rician/`：20,000 行最新 Case-SNR。
- `results/senlora_symmetric_v8/figure12_pilot_time_aligned/`：10,000 行最新轨迹及四曲线。
- `results/senlora_symmetric_v8/figure12_awgn_uncertainty/`：AWGN 原始均值及点态区间。
- 既有 `PILOT_TIME_ALIGNED_TEST.log`：9 项 Paper/Pilot 测试历史 PASS；本次未重跑。
- 既有 `AWGN_UNCERTAINTY_VALIDATION_FINAL.log`：置信区间绘图的历史验证；本次未重绘。

本次新运行的 MATLAB 审计输出保留在当前对话工具记录中，未额外写日志或测试结果 MAT，避免侧会话对主线程结果目录产生修改。
