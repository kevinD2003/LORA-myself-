# 论文初稿代码发布目录

本目录是论文初稿对应的代码与审计图发布包，包含可运行源码快照、按方法分类的代码副本、独立曲线入口和已完成的结果图；不包含冻结原始数据、检查点或历史输出目录。

## 两个独立工程

- `01_SF7_Project/`：SF=7 的 VP 虚拟导频和对比实验。
- `02_SF12_Project/`：SF=12 的 VP 虚拟导频和对比实验。

两个工程使用相同目录层级，便于论文中逐项说明算法、实验条件和曲线来源。

## 分类原则

1. VP 虚拟导频代码放在 `03_VP_Virtual_Pilot/`。
2. PREC、Paper Midamble、Ideal 和理论基线放在 `04_Comparison_Methods/`。
3. 每一条绘图曲线在 `05_Curve_Entry_Files/` 有一个独立文件，禁止在单个入口中混合多条线的算法逻辑。
4. 信道、帧结构、编码、统计等共享实现放在 `02_Common_Source/`。
5. 本地结果统一写入 `99_Local_Outputs_Not_Uploaded/`，该目录内容不上传。
6. `11_Audited_Source/` 保存不含结果的可运行源码快照；分类目录中的算法文件是便于论文阅读的字节一致副本。
7. `12_Result_Figures/` 只发布已经完成审计的 PNG 图；不发布原始包、MAT、CSV、检查点或运行中的部分图。

完整目录树见 [DIRECTORY_TREE.md](DIRECTORY_TREE.md)，上传边界见 [UPLOAD_RULES.md](UPLOAD_RULES.md)。

