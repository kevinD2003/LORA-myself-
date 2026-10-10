# V8 正式入口与参数冻结记录

状态：**正式入口已提升；参数已冻结；Formal 尚未启动**

- 正式统一入口：`senloraSymmetricV8Decode.m`；
- 实际实现：`senloraSymmetricV8JointBlockDecode.m`；
- 版本：`SenLoRa-V8-joint-block-frozen-v1`；
- `d0 = 0.10 bin`；
- `d1 = 0.80 bin`；
- 原生帧：8 前导 + 112 payload；
- 所有轨道位置调用同一入口和同一参数集；
- 旧 604-error 两遍实现保存在 `senloraSymmetricV8LegacyDecode.m`，不再是正式
  V8 入口。

冻结依据为独立 Review：900 个镜像对-包、1800 帧，Joint-block/V6-native/
Ideal 原始错误为 20/20/16；Case1 和 Case2 配对差异均为 0；没有显著镜像
差异、明显相邻跳变或接收失败。

机器可读清单为 `v8_frozen_receiver_manifest.json`，其中记录冻结源码及 Review
证据 SHA-256。

## Formal 启动前剩余条件

原规范要求 Case2 的 V8−Ideal 差异落在“预注册容差”内，但现有规范和代码中
没有找到该数值。冻结清单因此把 `case2AbsoluteSerTolerance` 保持为 `null`，
Formal runner 不得在该容差明确前启动，避免根据 Formal 数据反向定义门槛。
