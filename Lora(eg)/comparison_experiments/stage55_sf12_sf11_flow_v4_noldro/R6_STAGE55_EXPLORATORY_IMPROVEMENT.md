# R6 Stage55 exploratory improvement

Algorithm: `Stage55-A-two-downchirp-subbin-rate-v3`.

This is a separately named exploratory receiver. It does not overwrite R5 formal results or modify `Paper-Midamble-Point-native-SF12-noLDRO`. It may use the two complete synchronization downchirps already present in the common Track A frame, with no added airtime. Each downchirp receives an independent receiver-only sub-bin CFO estimate; their actual center-time separation supplies the initial rate. Payload VP updates remain causal, use hard labels, and have no truth, orbit, Hamming, Midamble, or future input.

Research objective: in Track A, seek lower SER than Paper-native while retaining the 23-label/no-BER identity; in Track B, seek lower SER, hard BER, and ML BER than Paper-adapted. This objective motivates receiver design but is not allowed to alter Paper, samples, denominators, gates, or reporting. Each algorithm version is frozen before independent evaluation; an unfavorable result remains evidence and triggers a separately signed structural revision rather than data fitting.

Parameters are frozen before comparison: sub-bin step 0.05, decision peak 3, normalized entropy 0.5, residual peak 1.01, innovation 0.35 bin, history decay 0.85, Huber 0.15 bin, maximum rate 20 bin/s, rolling history 8, and fail-closed after three rejected D. R6 first uses independent seed domain 810000000 for mechanism/validation. Results are exploratory; Stage55 superiority is not a test gate and adverse results must be retained.

## Frozen experiment conditions

R6 may change only Stage55 receiver-internal estimation, tracking, admission, and causal state logic. It must not change SF12, BW/Fs=125 kHz, LDRO=false, 4096 direct labels, carrier, orbit, Case times, SNR grid, Rician/AWGN definitions, payloads, noise/channel realizations, preamble or Midamble counts, physical symbol times, Paper receiver code, comparison modes, coding rate, information bits, sample budgets, statistical units, denominators, CI rules, or report boundaries. Using both complete downchirps is receiver processing of samples already present in the frozen Track A frame; it adds no transmitted symbol, airtime, or privileged observation. Track B remains CR3/16 blocks/768 bits/112 data symbols with AWGN main and separately reported Rician supplement.
