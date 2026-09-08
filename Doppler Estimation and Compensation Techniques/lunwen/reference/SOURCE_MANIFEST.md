# Source manifest

The files below are immutable inputs or cross-checks. They are not simulator
outputs and none of their plotted marker values is read by the MATLAB code.

| Source | Role | Bytes | SHA-256 |
|---|---|---:|---|
| `Doppler_Estimation_and_Compensation_Techniques_in_LoRa_Direct-to-Satellite_Communications.pdf` | Final IEEE paper supplied for the reproduction | 3,180,653 | `0DFED78259E87BEF9F0AC5DC946E9671DBCEDA414A011C73795F1A3C304D2379` |
| `../tmp/references/paper_arxiv_source.tar` | Public arXiv source snapshot for the earlier figure profile | 1,160,742 | `E3EC33B9E3FA3966772D9984C7B68A8CAD870CAFB7FB52D9DDC9B3883C2A624D` |
| `../tmp/references/LoRa-Doppler-Shift-Pre-Compensation-main/Figure 5/DopplerModelFunction.m` | Reference [51] Doppler-model cross-check | 841 | `A3A20CB4780E19054820FC0744C53187B3018A51B7AC12D748ABC4BD1141E00A` |
| `../tmp/references/Pasolini2022_LoRa_CSS.pdf` | Reference [12] receiver and AWGN validation cross-check | 1,813,457 | `36A75F22BEA475284249336E72FB7214633714D9049AF1B8DC52B8577C9D97B4` |

The final IEEE paper and its public arXiv source are different revisions. The
final paper states Rician fading with `K=10 dB` and Midamble-Point spacing
`n_int=3` at SF=12. The public source states AWGN-only and `n_int=1` at SF=12.
They are intentionally represented by separate configurations.
