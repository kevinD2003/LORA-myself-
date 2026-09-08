# SF=7 Midamble-Point reproduction report

## Locked paper conditions

- Carrier 868 MHz, bandwidth 125 kHz, orbital height 550 km.
- Rician K factor 10 dB and explicit unit-power AWGN.
- Payload 120 bits, coding parameter CR=1.
- SF=7, LDRO off, 128 samples per chirp.
- 33 payload chirps from the standard LoRa payload-symbol expression.
- Midamble-Point interval 12 data chirps, giving three midambles under the
  Eq. (20) ceiling count; the third is terminal.
- SNR grid -15 through -6 dB.

Point ToA is 44.288 ms versus Table 3's 0.044 s. Midamble-Point
ToA is 47.360 ms versus Table 3's 0.047 s.

The third pilot is terminal. Regression testing confirms that it changes ToA
but not payload SER, so the existing full Monte Carlo counts remain valid.

## Full experimental result

Each point contains 5056 packets and 166848 data symbols. At -6 dB:

| Case | Strategy | SER | 95% CI |
|---|---|---:|---:|
| 1 | No Doppler | 0.009919 | [0.009455, 0.010406] |
| 1 | Point | 0.044753 | [0.043772, 0.045756] |
| 1 | Midamble-Point | 0.046066 | [0.045070, 0.047082] |
| 2 | No Doppler | 0.009841 | [0.009379, 0.010326] |
| 2 | Point | 0.015883 | [0.015294, 0.016494] |
| 2 | Midamble-Point | 0.016974 | [0.016365, 0.017605] |

Both cases reproduce the paper's SF=7 relationship that Point and
Midamble-Point are nearly coincident: the short frame and coarse symbol
spacing make Doppler rate comparatively harmless.

The qualitative Point/Midamble-Point overlap is reproduced, but none of the
six SF=7 endpoint checks passes the frozen final-figure ranges. For example,
Case 1 Point is 0.044753 at -6 dB, while the acceptance-only visual interval
is 0.0025-0.0070. This difference is retained: pilot noise is not disabled,
curves are not shifted, and no target marker selects a parameter.

The public arXiv source describes an earlier AWGN-only SF=7 experiment. Its
separate `authorFigureSf7Config` result is not substituted for this final-text
Rician configuration. A corrected complex-AWGN run of that historical profile
is documented in `AUTHOR_SOURCE_PROFILE.md`.

## Evidence

- Validation report: results/sf7_validation.json.
- Raw counts: results/case1_sf7.csv and results/case2_sf7.csv.
- Editable plots: results/case1_sf7.fig and results/case2_sf7.fig.
- Combined plot: results/figure10_11_sf7_midamble_point.png.
- Machine audit: results/sf7_result_audit.json.

The result audit state is
`data_integrity_passed_paper_endpoint_mismatch`: raw-data integrity passes,
but the absolute SER remains outside the frozen visual acceptance range. The
top-level project audit separately records the independent-reproduction and
paper-match states.
