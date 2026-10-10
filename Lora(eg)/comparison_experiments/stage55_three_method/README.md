# SF11 Midamble-Point / Stage55 fair comparison

[按功能查找源码](docs/code_index.md) · [文档索引](docs/README.md)

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

- results/final/sf11_stage55_three_method_ser_trajectory.png
- results/final/sf11_stage55_three_method_ber_trajectory.png

BER means delivered BER after the common ML-soft Hamming(7,4) decoder.
SER is computed only over the original 112 data symbols.

SF11 receiver V2 的成对图保留在 `results/final_sf11_receiver_v2/`，对应方法说明见 [文档索引](docs/README.md)。
