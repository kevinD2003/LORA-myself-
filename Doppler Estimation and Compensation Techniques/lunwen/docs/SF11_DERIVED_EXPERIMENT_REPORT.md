# Derived SF=11 Midamble-Point experiment

## Derivation, not curve fitting

The source paper reports Midamble-Point spacing only for SF=7 and SF=12.
The referenced ChatGPT plan derives SF=11 from paper Eq. (19)-(20). For fixed
bandwidth, Doppler rate, tolerance and equal LDRO state:

    n_int is proportional to 2^(-2*SF).

SF=11 and SF=12 both use LDRO. Anchoring to the paper's SF=12 value
n_int=3 gives a factor 2^(2*(12-11))=4 and therefore n_int=12.
The selected integer is exact; no SER result or plotted marker participates.

Using the [50]/[51] center Doppler rate of 279.089833 Hz/s, this anchor implies
a tolerance factor k=0.899011. This exceeds the paper remark's stated typical
0 to 0.5 range and is retained as an explicit inconsistency rather than
silently altering n_int.

## Locked SF=11 configuration

- SF=11, bandwidth 125 kHz, carrier 868 MHz.
- LDRO on, effective data alphabet 512, valid-bin spacing four.
- 2048 samples per chirp and 61.03515625 Hz native FFT resolution.
- Standard 120-bit/CR=1 payload: 28 chirps.
- Midamble spacing 12: three midambles under the Eq. (20) ceiling count.
- Point ToA 0.626688 s; Midamble-Point ToA 0.675840 s.
- SNR grid -27 through -18 dB, whose upper point corresponds to
  Es/N0=15.1133 dB.
- Same 550 km orbit, K=10 dB Rician channel and explicit-power AWGN as the
  audited SF=7 and SF=12 experiments.

The third pilot is terminal and therefore does not alter payload SER; this
invariance is covered by regression testing.

## Full result

Every point uses 5056 packets and 141568 data symbols. At -18 dB:

| Case | Strategy | SER | 95% CI |
|---|---|---:|---:|
| 1 | No Doppler | 0.024207 | [0.023420, 0.025021] |
| 1 | Point | 0.140448 | [0.138648, 0.142268] |
| 1 | Midamble-Point | 0.145054 | [0.143229, 0.146898] |
| 2 | No Doppler | 0.025507 | [0.024699, 0.026341] |
| 2 | Point | 0.248326 | [0.246082, 0.250583] |
| 2 | Midamble-Point | 0.089731 | [0.088253, 0.091231] |

Case 1 retains Point approximately equal to Midamble-Point. In Case 2,
the formula-derived n_int=12 reduces SER by approximately 63.9 percent
relative to Point at -18 dB.

## Evidence

- Derivation and gates: results/sf11_validation.json.
- Raw counts: results/case1_sf11.csv and results/case2_sf11.csv.
- Editable plots: results/case1_sf11.fig and results/case2_sf11.fig.
- Combined plot: results/sf11_midamble_point_case1_case2.png.
- Machine audit: results/sf11_result_audit.json.
