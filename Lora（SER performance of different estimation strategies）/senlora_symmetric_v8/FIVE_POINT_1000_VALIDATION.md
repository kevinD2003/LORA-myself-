# V8 五点各 1000 包验证

状态：**数据完整；非零门槛通过；逐点 SenLoRa≥Ideal 门槛失败**

本次使用独立种子根 `1032500000`，不占用 Formal 种子。五个负轨点各运行
1000 包，共 5000 帧；每帧使用相同 payload/noise 依次运行冻结后的正式
SenLoRa V8 与离线 Ideal。

| 时间 | SenLoRa 错误 | Ideal 错误 | SenLoRa SER | Ideal SER | SenLoRa≥Ideal |
|---:|---:|---:|---:|---:|:---:|
| -366 s | 23 | 23 | 2.05357e-4 | 2.05357e-4 | 是 |
| -274.5 s | 12 | 15 | 1.07143e-4 | 1.33929e-4 | 否 |
| -183 s | 11 | 11 | 9.82143e-5 | 9.82143e-5 | 是 |
| -91.5 s | 12 | 11 | 1.07143e-4 | 9.82143e-5 | 是 |
| 0 s | 13 | 15 | 1.16071e-4 | 1.33929e-4 | 否 |

独立精确 AWGN 理论 SER 为 `1.00089634497e-4`，与轨道时刻无关。五点
SenLoRa 和 Ideal 均有非零错误；无接收失败，所有禁用信息使用标志均为
false。

SenLoRa/Ideal 总错误为 71/75，总 SER 为 1.26786e-4/1.33929e-4。
`-274.5 s` 和 `0 s` 的 SenLoRa raw SER 低于 Ideal，因此预注册的逐点排序
门槛失败。两个点的配对 bootstrap 95% 区间均包含 0，这种 raw 反转没有统计
显著性，但不得通过挑种子、裁剪或加伪错误消除。

结果目录：`results/senlora_symmetric_v8/five_point_1000/`

- `FIVE_POINT_1000_RAW_PACKETS.csv`：5000 帧逐包数据；
- `FIVE_POINT_1000_SUMMARY.csv`：五点汇总；
- `FIVE_POINT_1000_PAIRED_DIFFERENCES.csv`：逐点配对差异；
- `FIVE_POINT_1000_RESULT.mat` 与 `FIVE_POINT_1000_CHECKPOINT.mat`；
- `FIVE_POINT_1000_CHECKS.mat`；
- `FIVE_POINT_1000_SER.png`。

这不是全轨 Formal；`formalRootSeed` 仍未使用。
