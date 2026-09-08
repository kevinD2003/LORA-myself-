# 发现记录：Figure 17 正式扫描

- Pilot 已完成 336/336 点，趋势符合预检：high-rate 的 SF5-SF7 改善，
  SF8+ 有 floor；high-shift 保持较差 BER。
- 正式网格为 2*8*41=656 点；pilot 网格是 336 点。
- 现有 BER 点函数使用完整时域动态波形、原 dechirp–FFT 检测与批处理；可直接复用。
- 现有随机种子推导包含 Doppler 模型索引，故 paper/exact 默认不会共享随机流；
  正式 exact 抽查需要一个显式的成对种子覆盖接口。
- 现有内部 BER 对零错误返回 0，且 pilot 结果验证函数要求 BER 有限；正式 runner
  必须在独立输出层转换为 NaN，不能改变通用 BER 点函数的既有行为。
- exact 配对规则已确认：两模型对每一批使用相同符号/AWGN；先达到自身阈值的一方
  继续累计，直至两方都满足停止条件或共同达到 5e7 bit 上限。

