# Figure 17 动态 Doppler BER 粗网格预检报告

- profile：`paper_figure17_reference`
- 模型：`paper_piecewise_linear`
- 时间模式：`fixed_orbit_start_independent_symbols`
- 网格点数：336
- 原始 Monte Carlo 结果：未平滑、未拟合、未作 SNR 平移。
- 零错误点：CSV 保持 BER=0；图中空心下三角表示一错误上界。
- 最终 Figure 17：本轮未生成。

## 完整性检查

- NaN/Inf：否
- 空批：否
- FFT bin 映射全部有效：是
- 最大批复采样数：1999872
- 最大 MATLAB 内存增量：176.96 MiB
- 最慢单点：56.656 s

## 趋势诊断

| 场景 | SF | -30 dB BER | -10 dB BER | 10 dB BER | 严格单调 | 高 SNR floor | 结论 |
|---|---:|---:|---:|---:|---|---:|---|
| high_doppler_rate | 5 | 0.498486 | 0.275342 | 0 | 否 | 0 | expected_improvement |
| high_doppler_rate | 6 | 0.5 | 0.147135 | 0 | 否 | 0 | expected_improvement |
| high_doppler_rate | 7 | 0.497942 | 0.0681152 | 0 | 否 | 0 | expected_improvement |
| high_doppler_rate | 8 | 0.497589 | 0.22171 | 0.250702 | 否 | 0.250854 | floor_or_limited_improvement_diagnostic |
| high_doppler_rate | 9 | 0.491836 | 0.220146 | 0.226176 | 否 | 0.223417 | floor_or_limited_improvement_diagnostic |
| high_doppler_rate | 10 | 0.498413 | 0.197798 | 0.201382 | 否 | 0.201382 | floor_or_limited_improvement_diagnostic |
| high_doppler_rate | 11 | 0.493387 | 0.314083 | 0.316785 | 否 | 0.317902 | floor_or_limited_improvement_diagnostic |
| high_doppler_rate | 12 | 0.494023 | 0.315574 | 0.320867 | 否 | 0.308572 | floor_or_limited_improvement_diagnostic |
| high_doppler_shift | 5 | 0.501563 | 0.467627 | 0.375732 | 否 | 0.375732 | expected_poor_ber |
| high_doppler_shift | 6 | 0.498006 | 0.532878 | 0.557332 | 否 | 0.557292 | expected_poor_ber |
| high_doppler_shift | 7 | 0.506487 | 0.494838 | 0.47719 | 否 | 0.47719 | expected_poor_ber |
| high_doppler_shift | 8 | 0.501678 | 0.561188 | 0.559052 | 否 | 0.559052 | expected_poor_ber |
| high_doppler_shift | 9 | 0.501109 | 0.496359 | 0.497724 | 否 | 0.497724 | expected_poor_ber |
| high_doppler_shift | 10 | 0.496313 | 0.448285 | 0.448336 | 否 | 0.448336 | expected_poor_ber |
| high_doppler_shift | 11 | 0.491896 | 0.406949 | 0.406017 | 否 | 0.406017 | expected_poor_ber |
| high_doppler_shift | 12 | 0.496072 | 0.51571 | 0.517589 | 否 | 0.52903 | expected_poor_ber |

## 结论

粗网格未触发最终扫描前的强制排查标记。
