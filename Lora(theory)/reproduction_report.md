# LoRa CSS AWGN BER reproduction report

Generated with MATLAB 9.12.0.1884302 (R2022a) on 2026-07-28 16:47:49 *.

## Target and outcome

This project reproduces the standard LoRa CSS portion of Figure 4 in Ben Temim, Ferre, and Tajan, Sensors 22(5), 1830 (2022), DOI: 10.3390/s22051830. All 7 unit tests passed and 325 Monte Carlo points were produced in 20.65 seconds.

## Implemented model

The simulation uses uncoded LoRa CSS with SF7-SF12, B=125 kHz, Fs=B, M=2^SF samples per symbol, natural binary mapping, unit sample power, perfect synchronization, and complex AWGN only. SNR is Esample/N0sample, so the complex-noise variance is 10^(-SNR_dB/10). Detection is dechirping followed by an M-point FFT magnitude maximum.

No DCSS, Doppler, CFO, STO, fading, multipath, interference, FEC, interleaving, whitening, CRC, frame header, or LoRaWAN packet structure is present.

## Monte Carlo method

The waveform chain is implemented and directly tested. The full sweep samples its exact FFT-domain sufficient statistics to avoid very large waveform arrays. The correct FFT bin is a noncentral complex Gaussian random variable and the maximum of the M-1 noise-only bins is sampled from its exact order-statistic distribution. Wrong-bin indices are sampled uniformly and bit errors are counted from the natural-binary labels. No reference curve, fitted BER formula, or manual SNR shift is used.

For presentation only, the plotted lines use the exact theoretical BER of the same noncoherent dechirp-FFT AWGN detector. Monte Carlo markers remain unmodified, and both simulated and theoretical BER values are stored in the CSV. No empirical fit or SNR shift is applied.

Monte Carlo sampling is adaptive. Each SF/SNR point uses batches of 100000 random symbols and stops after 200 observed bit errors or 300000000 simulated bits. The SNR sweep for each SF stops after a BER at or below 1.0e-06 is supported by at least 50 errors. A zero-error point has BER=NaN in the CSV and is represented only by the one-count upper bound 1/total_bits.

## BER=10^-4 crossing estimates

| SF | Estimated SNR (dB) |
|---:|---:|
| 7 | -7.113 |
| 8 | -9.949 |
| 9 | -12.669 |
| 10 | -15.594 |
| 11 | -18.373 |
| 12 | -21.193 |

The median leftward shift per SF step at BER=10^-4 is 2.820 dB; the expected processing-gain trend is approximately 3.01 dB per step.

## Consistency with Figure 4

The reproduced curves should have the same qualitative ordering and near-3 dB spacing as the paper: higher SF moves the BER waterfall toward lower sample SNR, and no error floor appears. The comparison is intentionally limited to the CSS curves; the paper's DCSS curves are excluded.

## Sources of possible numerical difference

The paper does not publish its random seed, number of trials, stopping rule, exact bit-label convention, or Figure 4 source data. The paper also describes an oversampled receiver front end elsewhere, while the ideal synchronized CSS detector operates at Fs=B. This reproduction therefore cannot claim point-for-point identity, but it preserves the published signal model and SNR trend without empirical curve alignment.

## Files

- `ber_css_awgn_sf7_sf12.csv`: counts, BER/SER, seeds, upper bounds, and stopping reasons.
- `simulation_metadata.json`: complete assumptions and runtime configuration.
- `ber_css_awgn_sf7_sf12.png` and `.pdf`: 300 dpi raster and vector result figures.
- `test_results.txt`: MATLAB unit-test summary.
