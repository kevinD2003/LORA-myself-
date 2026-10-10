# SF11 三方法对照：源码功能索引

[项目入口](../README.md) · [结果索引](result_index.md)

文件按功能分类，链接指向实际源码位置；名称与目录保留原样。描述取源码开头注释，完整行为以源码和测试为准。

## 回归测试（6）

| 文件 | 内容 |
|---|---|
| [fuxianDecoderTest.m](../tests/fuxianDecoderTest.m) | MATLAB 测试类 |
| [fuxianFactorialTest.m](../tests/fuxianFactorialTest.m) | MATLAB 测试类 |
| [fuxianFinalResultTest.m](../tests/fuxianFinalResultTest.m) | MATLAB 测试类 |
| [fuxianLayoutTest.m](../tests/fuxianLayoutTest.m) | MATLAB 测试类 |
| [fuxianReplayTest.m](../tests/fuxianReplayTest.m) | MATLAB 测试类 |
| [fuxianReportTest.m](../tests/fuxianReportTest.m) | MATLAB 测试类 |

## 实验、报告与维护入口（9）

| 文件 | 内容 |
|---|---|
| [run_fuxian_full.m](../run_fuxian_full.m) | Full common-frame replay and final two-figure report. |
| [run_fuxian_full_background.m](../run_fuxian_full_background.m) | Logged wrapper for the long comparison. |
| [run_fuxian_pilot_source_factorial.m](../run_fuxian_pilot_source_factorial.m) | 跨帧状态×导频来源的2×2消融。 |
| [run_fuxian_smoke.m](../run_fuxian_smoke.m) | Small common-ledger replay before the full experiment. |
| [run_fuxian_stage55_three_method_replay.m](../run_fuxian_stage55_three_method_replay.m) | Common-frame trajectory replay. |
| [run_fuxian_tests.m](../run_fuxian_tests.m) | Execute and save all class-based comparison tests. |
| [run_fuxian_v2_full.m](../run_fuxian_v2_full.m) | Stage55主导的SF11-V2三方法正式重放与报告。 |
| [run_fuxian_v2_full_background.m](../run_fuxian_v2_full_background.m) | 带日志和状态文件的长时正式入口。 |
| [run_fuxian_v2_smoke.m](../run_fuxian_v2_smoke.m) | 四帧共同账本的Stage55/SF11-V2接线验证。 |

## 接收与补偿（6）

| 文件 | 内容 |
|---|---|
| [fuxianCommonPayloadDecode.m](../fuxianCommonPayloadDecode.m) | Apply the frozen common hard/soft decoder. |
| [fuxianHuangDecode.m](../fuxianHuangDecode.m) | Frozen-CFO Huang receiver on the common physical frame. |
| [fuxianKnownMidambleQualityDecode.m](../fuxianKnownMidambleQualityDecode.m) | 与Stage55同质量模型的已知Midamble分支。 |
| [fuxianPaperMidamblePointDecode.m](../fuxianPaperMidamblePointDecode.m) | Piecewise-constant known-pilot tracking. |
| [fuxianPaperMidamblePointDecodeV2.m](../fuxianPaperMidamblePointDecodeV2.m) | 带因果更新时延的SF11论文接收机。 |
| [fuxianSenLoRaDecode.m](../fuxianSenLoRaDecode.m) | Stage55 VP-quality with explicit pilots ignored. |

## 轨道与信道（1）

| 文件 | 内容 |
|---|---|
| [fuxianPlotTrajectoryComparison.m](../fuxianPlotTrajectoryComparison.m) | Write only the SER and BER figures. |

## 辅助工具与测试基础设施（6）

| 文件 | 内容 |
|---|---|
| [audit_fuxianduibi.m](../audit_fuxianduibi.m) | Final requirement-level audit for this isolated project. |
| [audit_fuxianduibi_v2.m](../audit_fuxianduibi_v2.m) | 审计Stage55主导的SF11-V2正式公平比较。 |
| [build_fuxian_stage55_report.m](../build_fuxian_stage55_report.m) | Build final statistics and two primary figures. |
| [fuxianBuildStatistics.m](../fuxianBuildStatistics.m) | Region and orbit-window SER/delivered-BER tables. |
| [fuxianMidambleLayout.m](../fuxianMidambleLayout.m) | Insert known pilots while retaining all payload data. |
| [fuxianSourceRoot.m](../fuxianSourceRoot.m) | Locate the Stage55 main-method source after reorganization. |

## 配置与冻结参数（1）

| 文件 | 内容 |
|---|---|
| [fuxianComparisonConfig.m](../fuxianComparisonConfig.m) | Freeze Stage55 and paper-transfer parameters. |

