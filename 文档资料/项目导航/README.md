# 项目导航

[全工作区目录导航](../../目录导航.md) 按研究内容列出每个项目及主要结果。

## 建议阅读顺序

1. 在 [lora(CFO)](<../../lora(CFO)/文件导航.md>) 了解 CSS/AWGN、轨道与逐采样动态多普勒。
2. 在 [师兄代码](../../师兄代码/README.md) 查找 PREC 原始参考实现。
3. 在 [Lora(eg)](<../../Lora(eg)/文件导航.md>) 阅读置信符号、软信息、Stage55 和三方法对照。
4. 在 [Midamble-Point 复现](<../../Doppler Estimation and Compensation Techniques/lunwen/README.md>) 核对论文配置和不同来源版本。
5. 在 [SER 对比工程](<../../Lora（SER performance of different estimation strategies）/README.md>) 及 [Doppler Resistant Enhancement](<../../Doppler_Resistant_Enhancement_for_Energy_Efficient_Device-to-Satellite_LoRa_Communications/README.md>) 查找独立新实验。
6. 在 [Lora(theory)](<../../Lora(theory)/README.md>) 查询理论曲线与旧实验副本。

## 路径关系

- SER 对比工程读取 `Lora(eg)/comparison_experiments/stage55_sf12_sf11_flow_v4_noldro` 的冻结依赖。
- Stage55 参考测试引用 `师兄代码/matlab/CFO相关/频移算法/PREC.m`。
- 部分 Paper 审计和图形脚本引用 `参考论文/` 中的原 PDF 路径。
- `picture/` 的 MATLAB 图形脚本使用固定输出目录。
- 严格 LR 论文条件分支有后台作业，源码和缓存签名直接影响断点续跑。

这些关联是保留工程、参考源码和论文实际位置的依据。查找使用文档分类入口，跨项目运行仍采用原目录。
