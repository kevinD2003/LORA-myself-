# Ideal Stage55-condition SER experiment

Status: **PASS**

- One common exact SER curve for Case A and Case B.
- SF12, BW/Fs 125 kHz, Fc 868 MHz, no-LDRO, CR3.
- 8 bootstrap + 112 payload + 37 midamble = 157 symbols.
- Channel: continuous deterministic LEO Doppler plus complex AWGN.
- Compensation: exact samplewise inverse Doppler phase.
- Theory: direct quadrature at every plotted point; no fit.
- Frozen performance data loaded: `false`.
- Fresh validation: 200 packets per Case/SNR.

Case A initial/final Doppler: 20226.569967 / 20226.240121 Hz.

Case B initial/final Doppler: -0.000000 / -1432.470582 Hz.

Theory range: 0.875061879724 to 0.000100089634497.

Total validation symbols: 448000.
