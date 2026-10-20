# 公共约定

这里只保存 SF7 与 SF12 必须一致的接口约定，不在两个工程之间共享可变运行状态。

- 曲线入口统一返回同一字段集合：方法标识、SF、信道、横坐标、SER、BER、错误计数和样本数。
- SER 固定为译码前 FFT 硬判决数据 chirp 错误率。
- BER 单独统计，不替换 SER。
- VP、PREC 和 Ideal Native 使用原生帧；Paper 和 Ideal Paper 使用显式 Midamble 帧。
- 随机种子、信道波形和方法输入必须可审计。
- SF7 与 SF12 的独立工程不得读取对方结果目录。
