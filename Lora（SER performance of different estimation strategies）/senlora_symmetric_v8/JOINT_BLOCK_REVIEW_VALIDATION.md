# V8 Joint-block 独立 Review

状态：**Review 通过；Formal 未启动**

本次使用 `reviewRootSeed = 1032000000` 的全新种子，运行 9 个物理镜像对、
每对 100 个配对包，共 900 个镜像对-包、1800 帧。每帧由同一 payload/noise
依次运行 Joint-block V8、同帧 V6-native 和离线 Ideal。

## 总体结果

| 接收机 | 原始错误 / 总符号 | SER |
|---|---:|---:|
| Joint-block V8 | 20 / 201600 | 9.92063e-5 |
| V6-native | 20 / 201600 | 9.92063e-5 |
| Ideal | 16 / 201600 | 7.93651e-5 |

- Case1 V8−V6-native 同包 SER 差异：0，bootstrap 95% 区间 [0,0]；
- Case2 V8−Ideal 同包 SER 差异：0，bootstrap 95% 区间 [0,0]；
- 显著镜像差异：0/9；
- 显著相邻点差异：0/17；
- 明显相邻数量级跳变：0/17；
- 最大单包错误：2；
- 每包最少通过质量门的 block：11/16；
- 最大被选 block 残差：0.30 bin；
- 最大单包 CFO RMSE：0.0491 bin；
- 三方法接收失败：0；
- Joint-block truth/orbit/case/SNR/target/midamble 使用标志：全部 false。

`d0=0.10 bin`、`d1=0.80 bin` 在 Review 中保持不变，`gain` 全部有限且位于
[0,1]。本次没有提升正式 V8 入口、冻结参数或启动 Formal。

## 结果文件

目录：`results/senlora_symmetric_v8/joint_block_review/`

- `REVIEW_RAW_PACKETS.csv`：1800 帧逐包原始数据；
- `REVIEW_RAW_POINTS.csv`：18 个原始轨道点；
- `REVIEW_CASE_PAIRED_DIFFERENCES.csv`：Case1/Case2 同包差异；
- `REVIEW_MIRROR_DIFFERENCES.csv`：9 个镜像对检查；
- `REVIEW_ADJACENT_POINTS.csv`：17 个相邻点检查；
- `REVIEW_RESULT.mat` 与 `REVIEW_CHECKPOINT.mat`：完整数组与检查点；
- `REVIEW_CHECKS.mat`：Review 汇总检查；
- `REVIEW_RAW_POINTS.png`：原始点直接连接图，无拟合或平滑。

检查点与最终 MAT 关键数组一致；1800 条逐包记录和 18 条点记录完整；运行
时记录的所有源码依赖 SHA-256 在结果复核时仍匹配。完成后又追加核验并记录
了 `searchStepBins` 的解析值以及两份参数 JSON 的路径和 SHA-256；原始数值
数组未改变，执行源码哈希仍保留运行时取值。MATLAB 在结果已保存并
打印摘要后出现一次 Windows `0xc0000374 Heap corruption` 退出异常，随后独立
加载和校验所有结果通过，因此没有数据丢失。

## 下一步边界

Review 通过允许进入冻结决策，但不自动启动 Formal。必须先明确正式入口、
冻结源码及 `d0/d1`，再使用第三组未见种子建立 9000 配对包 Formal。
