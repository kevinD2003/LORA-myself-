# Findings: Single-Symbol Dynamic Doppler Channel

- Existing modulator signature: `lora_css_modulate(symbols, sf)`.
- Existing detector signature: `lora_css_demodulate(rx, sf)`.
- Existing detector performs dechirp, unnormalized `M`-point FFT, and
  `argmax(abs(spectrum).^2)`.
- Existing orbit function returns signed radial velocity for arbitrary
  sample times.
- The target folder is not a Git repository, so commits are unavailable.
- The approved dependency strategy temporarily adds
  `D:\codex\Lora(theory)` to the MATLAB path and restores the path after
  tests.
- The analytic baseband frequency is
  `B*(mod(n+symbol,M)/M - 0.5)`.
- Baseline SHA-256:
  - `lora_css_modulate.m`: `A054534381C522EFCA0106DB05F08F19F62D4AF38C4CDAE53B791223CA5DDFA2`
  - `lora_css_demodulate.m`: `E631495EE0D082453A61062D820D5B024470500BD37312A69E6B498EC30C8609`
- Post-implementation SHA-256 values are identical to both baselines.
- The completed dynamic channel uses trapezoidal integration with
  `phi_D[0] = 0` and applies the resulting sample-by-sample phase
  rotation before adding complex AWGN.
- The detector wrapper delegates directly to the original
  `lora_css_demodulate`, preserving its uncompensated
  dechirp-FFT-argmax decision rule.
