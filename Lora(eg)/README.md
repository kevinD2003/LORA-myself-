# LoRa 多普勒估计与补偿实验

本项目包含 LoRa 卫星通信的 MATLAB 仿真、SenLoRa/PREC/Midamble-Point 对比、独立历史结果和组会汇报。

从 [文件导航](文件导航.md) 按主题查找代码、说明、图表和数据；从 [文档中心](docs/README.md) 查找学习资料、方法边界与审计记录。

## 项目入口

| 内容 | 入口 | 定位 |
|---|---|---|
| 当前 SF12 / no-LDRO 实验 | [V4 README](comparison_experiments/stage55_sf12_sf11_flow_v4_noldro/README.md) | Unified V23；当前报告记录为 PASS / ADMIT_V23_FREEZE |
| Stage55 SF11 主项目 | [Stage55 README](project/orbit_doppler/satellite_fig3_rolling8/README.md) | 规范 SF11 实现、质量感知虚拟导频与完整过境复现 |
| 置信符号基础复现 | [基础复现 README](project/confidence_symbol_reproduction/README.md) | FFT、LLR、软 Hamming、置信度和演示 |
| 轨道与连续多普勒 | [轨道 README](project/orbit_doppler/README.md) | 轨道、连续相位信道、跟踪和 BER 仿真 |
| SF11 三方法对照 | [三方法 README](comparison_experiments/stage55_three_method/README.md) | 独立 SF11 / 250 kHz 结果 |
| SF12 / LDRO 历史对照 | [V3 README](comparison_experiments/stage55_sf12_sf11_flow_v3/README.md) | 独立 V3 / CR3 适配实验 |
| 组会材料 | [汇报入口](reports/README.md) | 最终 PPTX 与构建、验证文件 |
| 论文阅读临时图 | [临时文件说明](tmp/README.md) | 按论文页面、理论检查和裁剪图分类 |

## 目录约定

- `project/`：基础复现与规范 SF11 项目；各项目的 `docs/` 保存说明文档。
- `comparison_experiments/`：参数、版本和随机种子彼此隔离的对比实验。
- `docs/`：全项目文档入口与本次审计、文件清单、迁移映射。
- `reports/`：面向汇报的最终材料和构建证据。
- `tmp/`：论文检查截图等临时辅助材料。

MATLAB 源码、配置、测试与原始 `results/` 保留所属实验路径。历史图、检查点与冻结清单不能跨实验混用；各项目 `docs/code_index.md` 按功能列出源码，不需要逐个猜文件名。

## 常用验证入口

基础项目及 Stage55 全项目回归（本机 R2022a 下有既有套件构造器兼容错误，详情见本次审计报告）：

```matlab
cd('D:/codex/Lora(eg)/project/confidence_symbol_reproduction')
runSenLoRaProjectTests
```

当前 V4 回归：

```matlab
cd('D:/codex/Lora(eg)/comparison_experiments/stage55_sf12_sf11_flow_v4_noldro')
addpath('scripts')
runV4Tests
```

2026-10-08 的整理范围、已知历史缺失及验证结果见 [本次审计报告](docs/audit/2026-10-08/PROJECT_AUDIT.md)。
