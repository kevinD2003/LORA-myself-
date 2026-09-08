# Stage55/SF11 前四项审计问题修复说明

## 1. Doppler rate参与式（19）缩放

原实现只按带宽和SF缩放，得到固定间隔48。新配置同时计算：

- 论文锚定、不修正速率：48；
- 按完整轨迹最大Doppler rate修正：65；
- 按完全可见帧最大Doppler rate修正：81。

三个值写入`spacingSensitivity`，不得根据性能结果临时挑选。V3主机制检查采用
完全可见区速率修正值81。

## 2. 跟踪Midamble与ToA Midamble分离

对于112个数据符号和间隔48：有效跟踪Midamble为2个，而严格式（20）的
`ceil(112/48)`为3个。新增字段分别记录：

- `trackingMidambleCount`：对后续数据补偿有作用的Midamble；
- `toaMidambleCount`：式（20）总数；
- `terminalMidambleCount`：只影响ToA的末端Midamble；
- `transmittedMidambleCount`：当前物理帧实际发送数。

V3严格布局会发送末端Midamble，但接收机不会把它作为跟踪观测。

## 3. 跨帧状态×导频来源2×2消融

新增四个共享物理帧的分支：

1. Midamble-isolated；
2. VP-isolated；
3. Midamble-crossframe；
4. VP-crossframe。

已知Midamble质量分支和Stage55虚拟导频分支共享bootstrap、rolling-8、创新增益、
相位对保护、速率可观性、译码器、payload和噪声。四帧接线结果只用于验证因子
正交，不能作为正式性能结论。

## 4. 移除新物理路径中的人为Midamble加噪

论文独立项目的默认`physical`路径使用真实输入SNR，不再为Midamble额外生成低SNR
噪声。历史图像校准配置明确标记为`legacy_snr_offset`，仅用于复现冻结校准曲线。

Stage55新已知Midamble分支直接使用接收机可见的CFO不确定度链，并采用Stage55冻结
质量融合增益，不向公共接收波形额外加噪。

## 结果隔离

旧Stage55、旧论文移植和已有正式图保持冻结。V3及2×2实验只能写入新结果目录。
