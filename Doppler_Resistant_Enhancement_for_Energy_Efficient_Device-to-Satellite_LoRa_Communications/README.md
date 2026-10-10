# Doppler Resistant Enhancement reproduction

This directory independently reproduces the receiver proposed in:

> G. Dietl, S. Oehme, and P. Bergmann, "Doppler Resistant Enhancement for
> Energy Efficient Device-to-Satellite LoRa Communications," WSA 2025.

The work is deliberately split into two ordered stages.

1. The paper stage validates fixed linear regression (Fixed LR) and
   decision-directed adaptive linear regression (Adaptive LR) under the
   paper's own orbit and PHY conditions. It reproduces Table IV and implements
   the complete coded PHY used by Figs. 3-4 and Tables V-VI.
2. `project_comparison/` then evaluates the two receivers on the existing V4
   shared SF12/no-LDRO frames. It does not modify the canonical V4 project.

## Quick start

```matlab
cd('D:\codex\Doppler_Resistant_Enhancement_for_Energy_Efficient_Device-to-Satellite_LoRa_Communications')
run_all_tests
dreSetupPaths(false)
run_paper_table_iv
run_paper_table_iv_centroid10
run_paper_full_phy
dreSetupPaths(true)
run_project_formal_v23_comparison
run_project_paper_flow_v2_comparison
run_project_centroid10_alignment
run_refined_lr_v1_comparison
run_refined_lr_independent_holdout
run_refined_lr_paired_ber_report
run_case1_case2_code_aided_ser
run_reproduction_audit
```

The formal scripts are restart-safe at the result-file level: an existing
result is only reused when its configuration signature matches.

## Reproduction scope and explicit assumptions

The paper specifies SF=12, packet length M=51, a 400 km circular orbit,
2.1 GHz carrier, B=62.6 kHz in the prose, four-times zero padding, and a
centroid size of 10. Its standard LoRa bandwidth grid and all preceding tables
use 62.5 kHz, so the executable default is 62.5 kHz while 62.6 kHz is retained
as reported metadata.

The following details are not numerically specified in the paper and are
therefore frozen here as auditable assumptions:

- eight known upchirps (`preambleSymbolCount=8`);
- a periodic Hann window;
- the first reproduction interpreted "centroid size 10" as ten FFT neighbors
  on each side (21 points); the corrected Table-IV and project branches use
  ten points total, with offsets -4:5 around the peak;
- circular FFT-bin unwrapping to the prediction nearest the current LR model;
- equation (15) is reproduced literally as `2*pi*f_D(t)*t` for the numerical
  anchor; the physically integrated instantaneous-frequency model remains an
  explicit sensitivity option in `dreGeneratePaperPacket`.
- the full-PHY experiment uses a 32-byte payload, CRC-16/CCITT, 16 zero pad
  bits, six SF12 coding blocks, and one trailing zero-padding LoRa symbol;
- the phrase "coded BER" is implemented as pre-Hamming coded-bit BER over all
  transmitted packets; a separate CRC-filtered sensitivity metric is retained.
  PLR is the post-Hamming CRC-failure rate. This split is necessary because the
  paper's statement that CRC-failed packets are excluded is not numerically
  consistent with its simultaneously nonzero coded BER and very small PLR.

The product phase in (15) differs from integrating instantaneous Doppler and
can materially change the fixed-LR error floor. The literal equation is the
reproduction default; this distinction is retained in the result signature.
No transmitted payload symbol is used by either receiver. Payload truth is
only used after decoding to score errors.

Equation (21) is evaluated on the cyclic LoRa FFT alphabet. The implementation
uses circular nearest-bin quantization because the FFT reports bins modulo
`2^SF`; boundary behavior is regression-tested explicitly. This is an
implementation extension needed to make the paper's real-valued centroid
estimate operational when Doppler crosses the FFT boundary.

## Outputs

- `results/paper_reproduction/table_iv_reproduction.csv`
- `results/paper_reproduction/table_iv_comparison.png`
- `results/paper_reproduction/table_iv_run.mat`
- `results/paper_centroid10_verified/table_iv_centroid10.csv`
- `results/paper_centroid10_verified/table_iv_centroid10.png`
- `results/paper_full_phy/full_phy_tables.csv`
- `results/paper_full_phy/figure_3_cr1_ber_trajectory.png`
- `results/paper_full_phy/figure_4_cr4_ber_trajectory.png`
- `results/paper_full_phy/full_phy_run.mat`
- `results/project_comparison/project_comparison.csv`
- `results/project_comparison/project_comparison.png`
- `results/project_comparison/project_comparison.mat`
- `results/project_formal_v23_verified/project_formal_v23_summary.csv`
- `results/project_formal_v23_verified/project_formal_v23_ser_ber.png`
- `results/project_formal_v23_verified/project_formal_v23.mat`
- `results/project_paper_flow_v2/project_paper_flow_v2_summary.csv`
- `results/project_paper_flow_v2/project_paper_flow_v2_ser_ber.png`
- `results/project_paper_flow_v2/project_paper_flow_v2.mat`
- `results/project_centroid10_alignment_v4/centroid10_alignment.csv`
- `results/project_centroid10_alignment_v4/centroid10_alignment.png`
- `results/project_centroid10_alignment_v4/centroid10_alignment.mat`
- `results/refined_lr_v1/refined_lr_v1_summary.csv`
- `results/refined_lr_independent_holdout/refined_lr_independent_holdout.csv`
- `results/refined_lr_paired_ber/holdout_with_paired_ber.csv`
- `results/case1_case2_code_aided_ser_v3/case1_case2_code_aided_ser_v3.csv`
- `results/case1_case2_code_aided_ser_v3/Case1_code_aided_SER_v3.png`
- `results/case1_case2_code_aided_ser_v3/Case2_code_aided_SER_v3.png`

The formal project comparison uses the current V4 Unified V23 receiver
versions: Huang V9, Stage55 V16, and Midamble V6. It processes 1000 paired
packets at each SNR from -30 through -21 dB for each of the two cases. The
older `results/project_comparison/` artifacts are a 30-packet smoke experiment
using Huang V2 and are retained only as historical diagnostics. The formal
script reuses V23's frozen per-packet reference errors, regenerates the same
IQ frames from the original seed protocol, and verifies a live first-packet
match in every cell. It saves 25-packet checkpoints and reports 95% intervals
from packet-level bootstrap resampling. The verified cache identity hashes all
V4 `src` and `config` MATLAB/JSON dependencies plus the contents of all 20
frozen V23 per-packet error records.

The project adaptation in `run_project_paper_flow_v2_comparison` follows the
paper's symbol-by-symbol order on the complete 157-symbol V4 physical frame.
It forms a centroid for every received symbol, fits the last eight measured
symbol errors, decides the current data symbol, then updates the regression.
The 37 already-transmitted V4 midambles are receiver-known zero symbols, so
their measured errors enter the same causal history directly. Fixed LR remains
frozen at the preamble fit. The new two methods are reported separately from
the original no-midamble LR methods: using the V4 midambles does not preserve
the paper's original no-extra-pilot-overhead property. Exact author-source
identity remains unverifiable because the paper does not define every
centroid/preamble detail.

For the paper-native receiver at project SNR -21 dB, use
`dreProjectPaperExact10Decode`. It uses exactly ten contiguous FFT samples
around the peak, the eight known preamble symbols and the paper's causal
fixed or adaptive last-eight regression. It does not use the V4 midambles.
The ten-point window uses offsets -4:5; the paper does not state which side
gets the extra sample of an even window. The historical 21-point estimator
used ten neighbors on each side, which is a materially different meaning of
"size 10". `results/project_centroid10_alignment_v4/` separates this change
from the experimental known-midamble adaptation on the same 1000 frames per
case. The latter remains an ablation, not the paper-native main result.
The earlier 3000-overpass full-PHY artifacts retain the 21-point estimator;
they are historical results and have not yet been regenerated with ten points.

Receiver-only refinement experiments are separate from the paper-native
baseline. `dreDecodeRefinedAdaptiveLR` changes either the ordinary-LS history
length from 8 to 16, or the eight-point line fit to Theil-Sen median slope.
The ten-point centroid, hard decision, causal feedback, no-midamble policy,
and shared V4 frame remain unchanged. `run_refined_lr_v1_comparison` separates
packets 1:150 for development from 151:1000 for validation; the independent
holdout uses new packet IDs 1001:2000. See `REFINED_LR_REPORT.md` for both
methods' observed gains and limits. The paired-BER report derives shared-
resample BER gain intervals directly from the saved per-packet errors.

The final no-midamble extension is reported separately as Dietl robust replay
V3; it is not the paper's original receiver. A ten-point Theil-Sen decision
pass is hard-Hamming decoded and re-encoded, then the resulting labels
robustly refit the CFO trajectory before the original IQ is replayed with
waveform compensation. Replay is enabled only when the median peak ratio of
the eight received preambles is at least 5.5. At lower observable quality, or
in the observable static regime, the receiver uses the already verified
no-midamble project safety branch. The branch choice is made before payload
decoding and uses neither configured SNR, orbit truth, payload truth, nor the
37 midambles.

The quality threshold was screened on packet IDs 1:100. Packet IDs 101:1000
form a 900-packet-per-cell holdout on the same formal grid. The receiver has
no more symbol errors than Midamble V6 in all 20 complete cells and all 20
holdout cells. Case 1 uses the observable static branch and therefore
coincides with Stage55 V16. In Case 2 the replay branch is used by 45, 431,
and 913 packets at -23, -22, and -21 dB, respectively. At -21 dB its SER is
0.0140 versus 0.0435 for Midamble V6 and 0.0163 for Stage55 V16.

`VALIDATION.md` records the executed tests, configuration hashes, and known
limits of the comparison.

## Full-reproduction interpretation

All numerical sections of the six-page paper now have executable paths and
formal artifacts. This means the implementation scope is complete. Numerical
agreement is not uniform: fixed-LR coded BER closely follows Tables V-VI, but
standard post-Hamming CRC produces much larger PLR than the paper while the
paper simultaneously reports nonzero coded BER on CRC-success packets. Both
the standard CRC result and the published target are retained; no result is
rescaled or replaced to force agreement.
