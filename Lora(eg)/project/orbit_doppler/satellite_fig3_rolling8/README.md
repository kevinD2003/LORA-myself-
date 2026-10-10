# Stage55 SF11 规范项目

本目录是规范 SF11 / 250 kHz Stage55 实现，包含连续相位轨道信道、Huang-PREC-CP、SenLoRa 质量感知虚拟导频、分阶段回归及冻结结果。独立 SF12 / no-LDRO 主实验见 [V4](../../../comparison_experiments/stage55_sf12_sf11_flow_v4_noldro/README.md)。

## 查找入口

- [项目规范与来源](docs/project/CANONICAL_PROJECT.md)
- [项目状态](docs/project/PROJECT_STATE.md)：包含不同时间的历史阶段结论，阅读时核对阶段与日期。
- [Stage55 当前冻结算法说明](docs/learning/STAGE55_CHATGPT_PROJECT_GUIDE.md)
- [中文算法学习说明](docs/learning/SenLoRA_算法与仿真实验详解.md)
- [质量感知虚拟导频说明](docs/methods/STAGE55_VP_QUALITY_AWARE.md)
- [源码功能索引](docs/code_index.md)
- [全部文档](docs/README.md)

## 结果位置

| 内容 | 目录 |
|---|---|
| Stage55 SenLoRa / PREC 的 SER、BER 轨迹 | [2026-08-13 轨迹结果](results/stage55_senlora_prec_ser_ber_trajectory_20260813/) |
| 虚拟导频质量最终评估 | [最终评估](results/stage55_vp_quality_final_evaluation/) |
| Stage55 新鲜重跑汇总 | [总体报告](results/stage55_vp_quality_fresh_overall_report_20260812/) |
| Stage53 完整过境正式结果 | [正式结果](results/stage53_formal_repeated_passes/) |
| Stage45 历史 BER | [历史 BER](results/stage45_formal_ber_minus30_to_minus14/) |

运行本目录回归（默认包含 SF11 三方法对照测试）：

```matlab
cd('D:/codex/Lora(eg)/project/orbit_doppler/satellite_fig3_rolling8')
runStage55ProjectTests
```

MATLAB 文件保留在原目录，以保持 `mfilename` 路径推导、测试发现和结果输出路径。历史维护脚本在 [scripts/maintenance](scripts/maintenance/README.md)，学习和审计资料归入 `docs/`。
