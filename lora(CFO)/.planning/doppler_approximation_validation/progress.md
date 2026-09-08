# 进度记录：Doppler 近似验证

## 2026-07-30

- 检查了现有轨道、动态信道和测试实现。
- 从论文 PDF 视觉核对了式（18）至式（20）。
- 用 MATLAB 只读探算确定四种组合的误差量级和验收容差。
- 用户确认中点符号选择及整体设计。
- 根据用户要求，将设计规范改为中文。
- 用户确认中文版设计规范。
- 已建立并自审中文实施计划；尚未修改生产代码或新增测试代码。
- 下一阶段为 TDD RED：先新增测试并观察缺失函数失败。
- 新增 8 项 approximation 测试并观察 RED：0 通过、8 失败且未完成，
  原因为 `lora_figure17_geometry` 未定义。
- 实现 Figure 17 几何函数后达到检查点：1 通过，其余失败由
  `lora_doppler_piecewise_linear` 缺失导致。
- 实现最小分段线性核心函数，首次完整 GREEN 为 8/8 通过。
- 已验证 exact 完整 RF 公式、四种组合误差、梯形相位、FFT 峰值、
  50 符号 `v_d` 连续性及 `c_d`/回绕修正连续性。
- 新增运行器产物测试并先观察 RED，随后实现运行器达到 9/9 GREEN。
- MATLAB 实际生成 4 组 Figure 5-like PNG/PDF、8 组逐符号 PNG、
  两组 CSV 与两组 JSON；单符号 4 行，逐符号 200 行。
- 新鲜完整回归结果为 33/33 通过，0 失败、0 未完成。
- MATLAB Code Analyzer 检查 4 个新增文件，问题数为 0。
- 20 个预期输出全部存在且非空，metadata 明确记录
  `berSweepRun=false`。
- 核对原 AWGN 调制与解调文件 SHA-256，均与开发前基线一致。
- 用 Poppler 回渲染 4 份 Figure 5-like PDF，并目视检查全部 8 份
  逐符号诊断 PNG，未见裁切、重叠、图例错配或不可读坐标。
- 目视对照论文第 6 页 Figure 3 与第 8 页 Figure 5：
  曲线方向、LoRa 回绕位置、实线/圆点覆盖关系与论文一致。
- 已生成中文测试报告
  `test_doppler_approximation_results.txt`。
