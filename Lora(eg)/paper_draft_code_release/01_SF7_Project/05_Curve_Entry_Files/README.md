# SF7 曲线独立文件

本目录中的每个 `curve*.m` 只对应一条论文曲线。无参数调用返回论文元数据；传入配对波形与配置后，VP、PREC、Paper 和 Ideal 入口直接调用相应算法。AWGN 理论入口直接计算精确积分；Rician 理论入口调用生成本批完成图的归一化 K10 生成器。

顺序：VP、PREC、Paper、Ideal Native、Ideal Paper、AWGN 理论、Rician 理论参考。

