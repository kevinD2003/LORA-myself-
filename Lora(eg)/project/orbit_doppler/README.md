# SenLoRa orbit Doppler workspace

[按功能查找源码](docs/code_index.md) · [文档索引](docs/README.md)

This folder is intentionally isolated from the original Lora(eg) MATLAB files.

## Entry points

- run_senlora_orbit_model_demo — single-device orbit shift/rate figure.
- run_senlora_continuous_orbit_demo — continuous SF11 frame and phase-boundary check.
- run_senlora_virtual_pilot_demo — high-SNR tracker mechanics with controlled masks.
- run_senlora_confidence_orbit_demo — SenLoRa FFT/LLR/soft-Hamming/EMA confidence iteration.
- run_senlora_ber_smoke — short raw-Monte-Carlo BER checkpoint.
- runSenLoRaOrbitBer — resumable formal BER scan.

The formal scan defaults to SF11, -30:1:10 dB, 300 bit errors per point or 1e7 bits. It writes CSV/MAT/PNG/JSON and per-point first-frame diagnostic traces under results/formal_ber.

All receiver functions accept received waveforms plus the four known bootstrap bins only. Payload truth appears only in evaluation-side BER and truth-filtered upper-bound code.

