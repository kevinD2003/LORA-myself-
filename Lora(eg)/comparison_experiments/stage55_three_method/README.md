# SF11 Midamble-Point / Stage55 fair comparison

This isolated MATLAB R2022a experiment transplants the paper's
Midamble-Point receiver into the frozen Stage55 project conditions and
compares:

1. Huang-PREC-CP.
2. SenLoRa Stage55 VP-quality.
3. Paper Midamble-Point.

The common physical frame keeps the project's 704 information bits,
112 coded payload symbols, SF=11, BW=250 kHz, CR=3, orbit, SNR grid,
pass count, payload seeds, noise seeds and continuous Doppler phase.

Paper Eq. (19) scaling gives n_int=48 for the project bandwidth:

    3 * (250 kHz / 125 kHz)^2 * 2^(2*(12-11)) = 48.

Two pure-upchirp midambles are inserted after data symbols 48 and 96.
All three receivers process the same resulting 122-symbol waveform.
Huang and SenLoRa ignore these rows as tracking observations; only the
paper receiver uses them.

Primary outputs are only:

- results/sf11_stage55_three_method_ser_trajectory.png
- results/sf11_stage55_three_method_ber_trajectory.png

BER means delivered BER after the common ML-soft Hamming(7,4) decoder.
SER is computed only over the original 112 data symbols.
