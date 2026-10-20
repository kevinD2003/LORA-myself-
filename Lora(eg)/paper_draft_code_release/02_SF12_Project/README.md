# SF12 论文代码工程

固定身份：SF=12、BW=Fs=125 kHz、868 MHz、CR3、无 LDRO、8 个前导、112 个数据 chirp。Paper Midamble 间隔为 3。

主来源工程：

`D:/codex/Lora(eg)/comparison_experiments/paper_endpoint_conditions/all_curves_symbolvp_k10`

本目录将代码分成 VP 虚拟导频、对比算法和公共源代码。冻结数据不复制；具体来源见 `10_Manifests/source_map.csv`。

`11_Audited_Source/` 是运行和复核使用的权威源码快照；`12_Result_Figures/` 只含已完成的 SF12 AWGN 1000 包图及 Rician 理论/信道 1000 包图。新 Rician 接收机对比仍在运行，不发布部分结果。

