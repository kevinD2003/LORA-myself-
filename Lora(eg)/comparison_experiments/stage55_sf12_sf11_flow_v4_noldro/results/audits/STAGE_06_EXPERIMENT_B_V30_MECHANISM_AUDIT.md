# Stage 06 Experiment B v30 mechanism audit

Overall status: `PASS` for controlled and native independent validation entry.

The v28 controlled validation and safety remain PASS evidence for v28. Its native validation is retained as FAIL: quality, SER and ML gates passed, but hard BER was slightly worse, with almost all excess errors concentrated in three blind-gap startup frames.

v30 adds a receiver-state startup guard. When cross-frame history has at most one observation and the known-preamble processing gain exceeds `ln(4096×35)`, the receiver uses the common fractional bootstrap and strict candidate-2 wide bank. Established-history switching remains `1.5×ln(4096×35)`. Very-low-gain -30 dB frames remain on the cross-anchored dual branch. No SNR or truth enters the receiver.

- Native 120T/157T schedule tests: PASS.
- Natural back-to-back start times and zero gap: PASS.
- Native generator phase continuity and no-Doppler PHY round trip: PASS.
- v30 threshold/source test: PASS.
- Native failed-pass replays 10/18/20 reduced to `2/0/0`, `2/0/0`, and `7/0/0` Stage55 symbol/hard/ML errors.
- v30 controlled -30/-25 mechanism samples retained all-three-metric improvement.
- Paper/Huang unchanged; formal seeds unused.

Admission: `PASS` to separate 20-pass controlled and 20-pass native validation domains. No v28 sample may be merged. Smoke remains prohibited pending both v30 validations.
