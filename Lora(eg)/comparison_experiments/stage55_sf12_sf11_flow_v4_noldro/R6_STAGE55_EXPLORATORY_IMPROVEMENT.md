# R6 Stage55 exploratory improvement

Algorithm: `Stage55-A-two-downchirp-subbin-rate-v3`.

This is a separately named exploratory receiver. It does not overwrite R5 formal results or modify `Paper-Midamble-Point-native-SF12-noLDRO`. It may use the two complete synchronization downchirps already present in the common Track A frame, with no added airtime. Each downchirp receives an independent receiver-only sub-bin CFO estimate; their actual center-time separation supplies the initial rate. Payload VP updates remain causal, use hard labels, and have no truth, orbit, Hamming, Midamble, or future input.

Parameters are frozen before comparison: sub-bin step 0.05, decision peak 3, normalized entropy 0.5, residual peak 1.01, innovation 0.35 bin, history decay 0.85, Huber 0.15 bin, maximum rate 20 bin/s, rolling history 8, and fail-closed after three rejected D. R6 first uses independent seed domain 810000000 for mechanism/validation. Results are exploratory; Stage55 superiority is not a test gate and adverse results must be retained.
