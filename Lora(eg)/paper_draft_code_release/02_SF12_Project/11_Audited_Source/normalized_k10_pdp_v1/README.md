# Normalized K=10 dB PDP experiment

This independent experiment searches a single physical Rician power-delay
profile shared by SF7 and SF12. It does not modify or pool the frozen AWGN,
flat-Rician, calibrated-margin, or four-delay results.

Fixed constraints:

- Rician K = 10 dB exactly: LOS power is `10/11`, total diffuse power is
  `1/11`.
- Ensemble total channel power is exactly one. There is no link margin,
  per-packet normalization, noise rescaling, or SNR-axis shift.
- A fraction `alpha` of diffuse power is unresolved at zero excess delay.
  The remaining diffuse power is distributed over delays 1, 2, 3, and 4
  samples (8, 16, 24, and 32 microseconds at 125 kHz).
- Delayed relative powers follow `exp(-beta*(delay-1))` and are normalized.
- The same `alpha`, `beta`, delays, and power profile apply to both SFs and
  every orbit/SNR point.
- Primary metric is pre-FEC FFT hard-chirp SER. No BER curve is part of this
  experiment.

The first stage is a cyclic LoRa screening calculation in
`theory/search_normalized_pdp.py`. Candidates must be no worse than the
paper's digitized ideal reference at all four Rician endpoint families and
are ranked by closeness to the requested 0.7--0.9 reference ratio. Cyclic
screening is not final evidence; selected candidates require native causal
waveform validation with packet boundaries and the fixed V4 frame.

