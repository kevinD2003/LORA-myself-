# MATLAB Midamble-Point reproduction

This MATLAB R2022a project implements the paper's Point and Midamble-Point
Doppler estimation methods for SF=7 and SF=12, then runs the same locked
experiment for the formula-derived SF=11 case. All source, configuration,
tests, reference snapshots, raw Monte Carlo counts and figures are contained
under this project directory.

## What is reproduced

- SF=7: Figure 10/11 left-panel conditions.
- SF=12: Figure 10/11 right-panel conditions.
- SF=11: a separate derived experiment using paper Eq. (19)-(20), not a
  claimed paper panel.
- Case 1: high Doppler shift and low Doppler rate.
- Case 2: low Doppler shift and high Doppler rate.
- Curves: no-Doppler reference, Point, and Midamble-Point.

The metric is SER (chirp error rate), not BER. Every plotted point is produced
from saved error counts and binomial confidence intervals. The simulator never
reads paper marker values. There is no curve fit, SNR shift, scale factor or
post-hoc parameter search.

## Reproduction profiles

Two incompatible primary-source revisions are kept separate:

1. `paperSf7Config` / `paperSf12Config` transcribe the final IEEE text:
   Rician fading with K=10 dB and SF=12 midamble spacing 3.
2. `authorFigureSf7Config` / `authorFigureSf12Config` transcribe the public
   arXiv source snapshot: AWGN-only and SF=12 midamble spacing 1.

The second profile is evidence for a historical figure revision; it does not
replace the final-paper configuration. Source hashes and roles are frozen in
`reference/SOURCE_MANIFEST.md`.

## Current audit state

The top-level state is `independent_reproduction_passed`; the separate
`paperMatchState` is
`not_reproducible_from_available_publication_materials`. This distinction is
intentional: implementation, static-analysis, Monte Carlo integrity and
no-fitting gates can pass without claiming that every marker in the final
paper has been reproduced.

The final-text SF=7/SF=12 endpoints do not all lie inside the frozen visual
acceptance ranges in `reference/paperEndpointAcceptance.csv`. The audit keeps
`completePaperReproductionClaimed=false` until they do.

The remaining mismatch is not silently optimized away. The final paper does
not publish the extended simulator or the temporal Rician-channel parameters,
and its public source is an earlier AWGN-only/n_int=1 revision. A new
machine-readable proof shows that Table 3's 1.341 s value comes from using the
fractional count 23/3=7.666... rather than the Eq. (20) ceiling of 8; no
physical frame can contain that fractional pilot. See
`docs/PUBLICATION_CONSISTENCY.md`, `docs/REPRODUCTION_REPORT.md`, and
`docs/AUTHOR_SOURCE_PROFILE.md`.

## Main commands

Run from the project folder:

```matlab
run(fullfile("scripts", "runStage1Validation.m"));
run(fullfile("scripts", "runSmokeReproduction.m"));
run(fullfile("scripts", "runAllReproduction.m"));
run(fullfile("scripts", "runSf7Reproduction.m"));
run(fullfile("scripts", "runSf11Reproduction.m"));
run(fullfile("scripts", "runAuthorFigureReproduction.m"));
run(fullfile("scripts", "auditPublicationConsistency.m"));
run(fullfile("scripts", "runPaperMatchDiagnostics.m"));
run(fullfile("scripts", "runAllTests.m"));
run(fullfile("scripts", "auditProject.m"));
```

Primary figures are written to `results/`:

- `figure10_11_sf7_midamble_point.png`
- `figure10_11_sf12_midamble_point.png`
- `sf11_midamble_point_case1_case2.png`
- `sf7_sf11_sf12_midamble_summary.png`
- `author_source_sf7_case1_case2.png`
- `author_source_sf12_case1_case2.png`

CSV files, rather than PNG files, are the authoritative experiment outputs.
The six primary CSV SHA-256 digests are locked in
`reference/primaryResultHashes.csv`; `auditProject` fails if any is altered.

An explicitly tuned profile is also available under `results/calibrated`.
It matches all 12 frozen Figure 10/11 endpoint bands on a held-out 5000-packet
validation seed, but every row is marked `fittedOrTuned=true` and it is never
substituted for the independent reproduction. See
`docs/CALIBRATED_REPRODUCTION.md`.

## SF11桥接校准

在SF7/SF12校准接收机之后，项目新增了SF11桥接配置和正式结果。SF11没有
论文目标曲线，因此没有针对SF11图像调参；Midamble估计损失由SF7/SF12按SF
线性插值得到，Doppler时间尺度恢复为物理值1，为后续Stage55同条件移植做准备。

正式结果位于`results/calibrated_sf11`，每个SNR点使用5000包。Case 1全部
满足Point不高于Midamble-Point，Case 2全部满足Midamble-Point低于Point。
详细说明见`docs/SF11_校准复现报告.md`。

## Requirements

- MATLAB R2022a.
- Communications Toolbox 7.7 (`awgn`).

`matlab.codetools.requiredFilesAndProducts` confirms that the simulation core
requires only MATLAB and Communications Toolbox. The HTML coverage report uses
the unit-testing framework included with MATLAB.
