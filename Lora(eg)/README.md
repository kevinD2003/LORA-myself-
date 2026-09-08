# LoRa 多普勒估计与补偿实验

本仓库用于 LoRa 卫星通信场景下的多普勒建模、频偏估计与补偿，以及 SenLoRa、Huang-PREC 和 Midamble-Point 等方法的 MATLAB 仿真与对比。

## 目录说明

```text
Lora(eg)/
├─ project/                         # 主项目与基础复现
│  ├─ confidence_symbol_reproduction/
│  └─ orbit_doppler/
└─ comparison_experiments/         # 不同条件下的独立对比实验
   ├─ stage55_three_method/
   ├─ stage55_sf12_paper_conditions/
   ├─ stage55_sf12_paper_conditions_v2/
   ├─ stage55_sf12_sf11_flow_v3/
   └─ stage55_sf12_sf11_flow_v4_noldro/
```

### `project/`

主项目代码。

- `confidence_symbol_reproduction/`：SenLoRa 置信符号检测的基础复现，包括解调、软译码、置信度计算、连续帧及可变多普勒演示。
- `confidence_symbol_reproduction/results/`：上述基础实验生成的图表、CSV 和 MAT 结果。
- `orbit_doppler/`：卫星轨道、多普勒轨迹、连续相位信道、虚拟导频跟踪和 BER/SER 仿真。
- `orbit_doppler/results/`：轨道模型、接收机验证和各类仿真实验结果。
- `orbit_doppler/satellite_fig3_rolling8/`：Stage55 的主要完整实现，包含三种接收方法、分阶段实验脚本、回归测试和正式结果。
- `orbit_doppler/satellite_fig3_rolling8/docs/`：Stage55 的学习说明及配图索引。
- `orbit_doppler/satellite_fig3_rolling8/results/`：Stage55 各阶段生成的检查点、统计表和图形。

### `comparison_experiments/`

与主项目隔离的对比实验，避免不同参数、版本和检查点相互混用。

- `stage55_three_method/`：在 SF11 项目条件下比较 Huang-PREC、Stage55 VP-quality 和 Paper Midamble-Point 三种方法。
- `stage55_sf12_paper_conditions/`：在 SF12 论文条件下进行 Stage55 与 Midamble-Point 的第一版配对对比。
- `stage55_sf12_paper_conditions_v2/`：上述 SF12 论文条件实验的独立第二版，包含门限冻结、补充测试和审计修正。
- `stage55_sf12_sf11_flow_v3/`：把完整 SF11 Stage55 流程移植到 SF12、LDRO、CR3 条件下的 V3 三方法实验。
- `stage55_sf12_sf11_flow_v4_noldro/`：SF12、125 kHz、关闭 LDRO 条件下的 V4 双轨实验及其阶段门审计；当前进展以目录内方案和状态文档为准。

这些实验目录通常采用相同的子目录约定：

- `config/`：冻结的物理层、接收机和随机种子配置。
- `src/`：信号生成、信道、接收机及统计计算源码。
- `scripts/`：标定、冒烟测试、正式仿真、报告生成和审计入口。
- `tests/`：单元测试、公平性测试与回归测试。
- `results/`：MATLAB 生成的 MAT、CSV、JSON、PNG、FIG、PDF 和日志文件。

## 使用说明

本项目主要使用 MATLAB。进入相应实验目录后，先阅读该目录的 `README.md` 或状态文档，再按说明运行脚本。例如，基础回归测试可运行：

```matlab
cd('project/confidence_symbol_reproduction')
runSenLoRaProjectTests
```

Stage55 主项目测试可运行：

```matlab
cd('project/orbit_doppler/satellite_fig3_rolling8')
runStage55ProjectTests
```

不同版本的实验参数和检查点彼此独立，请勿跨目录混用 `results/` 中的中间文件。
