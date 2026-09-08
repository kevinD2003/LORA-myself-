# Single-Symbol Dynamic Doppler Channel Design

## Scope

Implement a single-symbol LoRa dynamic Doppler channel on top of the
validated Figure 3 orbit model in `D:\codex\lora(CFO)`.

This phase adds:

- `lora_symbol_instantaneous_frequency.m`
- `apply_lora_dynamic_doppler.m`
- `lora_css_demodulate_dynamic_channel.m`
- `test_lora_dynamic_channel.m`

This phase does not implement a BER sweep, interference, FEC, fading,
multipath, CFO, STO, framing, or Doppler compensation.

The existing files in `D:\codex\Lora(theory)` remain unmodified. Tests
and examples temporarily add that directory to the MATLAB path and call
the original `lora_css_modulate` and `lora_css_demodulate` functions.

## Signal Model

For spreading factor `SF`, let:

```text
M = 2^SF
Fs = B
n = 0,...,M-1
```

The channel receives one existing unit-power LoRa symbol waveform
`x_s[n]`. It applies dynamic Doppler phase and complex AWGN:

```text
r[n] = x_s[n] * exp(1j*phi_D[n]) + w[n]
```

The project SNR convention is:

```text
SNR = E{|x[n]|^2} / E{|w[n]|^2}
```

Since the input waveform has unit average sample power:

```text
E{|w[n]|^2} = 10^(-SNR_dB/10)
```

The real and imaginary noise components each have half this variance.
`SNRdB=Inf` disables AWGN for deterministic tests.

## Instantaneous LoRa Frequency

`lora_symbol_instantaneous_frequency(symbol, sf, bandwidthHz)` returns
the wrapped instantaneous complex-baseband frequency:

```text
f_bb,s[n] = B * (mod(n+s, M)/M - 1/2)
```

The output:

- contains exactly `M` samples;
- is expressed in hertz;
- lies in `[-B/2, B/2)`;
- includes the symbol-dependent LoRa chirp wrap;
- does not infer frequency from wrapped sample phases.

The function accepts one scalar integer symbol in `[0, M-1]`.

## Orbit Sampling

For symbol start time `t0`:

```text
t[n] = t0 + n/Fs
```

`apply_lora_dynamic_doppler` calls the existing
`lora_orbit_doppler_trajectory` function at these sample times and uses
its signed radial velocity `v(t[n])`.

The trajectory's carrier-only Doppler field is diagnostic only. The main
channel recomputes Doppler with the instantaneous RF frequency.

## Doppler Modes

### Full RF mode

This is the default and primary channel model:

```text
f_D[n] = -(fc + f_bb,s[n]) * v(t[n]) / c
```

### Carrier-only approximation

This mode is available only for approximation-error validation:

```text
f_D,carrier[n] = -fc * v(t[n]) / c
```

The approximation is not used silently. The selected mode is returned
in diagnostics.

## Doppler Phase Integration

The implementation uses trapezoidal integration because the Doppler
frequency changes over the symbol:

```text
phi_D[0] = 0
phi_D[n] = phi_D[n-1]
           + pi/Fs * (f_D[n-1] + f_D[n]), n >= 1
```

The initial phase is set to zero. This removes only an arbitrary common
phase; it does not compensate Doppler frequency or Doppler rate.

No FFT-bin shift, frequency correction, phase derotation, or resampling
is permitted.

## Function Interfaces

### `lora_symbol_instantaneous_frequency`

```matlab
frequencyHz = lora_symbol_instantaneous_frequency( ...
    symbol, sf, bandwidthHz)
```

### `apply_lora_dynamic_doppler`

```matlab
[rx, diagnostics] = apply_lora_dynamic_doppler( ...
    tx, symbol, sf, startTimeSec, orbitConfig, ...
    BandwidthHz=250e3, ...
    SNRdB=Inf, ...
    Mode="full_rf")
```

The function processes exactly one `M`-sample symbol. It validates input
length, unit-power assumptions, symbol range, bandwidth, SNR, and mode.

Diagnostics contain:

- sample times;
- baseband instantaneous frequency;
- instantaneous RF frequency;
- radial velocity;
- Doppler frequency;
- accumulated Doppler phase;
- unit-magnitude phase rotation;
- noise variance;
- selected mode and integration rule.

### `lora_css_demodulate_dynamic_channel`

```matlab
detectedSymbol = lora_css_demodulate_dynamic_channel(rx, sf)
```

This wrapper calls the original:

```matlab
lora_css_demodulate(rx, sf)
```

It performs no Doppler compensation and does not alter the detector.

## Error Handling

Public functions reject:

- noninteger or out-of-range symbols;
- invalid spreading factors;
- nonpositive or nonfinite bandwidth;
- waveform lengths other than `2^SF`;
- nonfinite start times;
- unsupported Doppler modes;
- NaN SNR values.

`SNRdB=Inf` is valid. Negative infinity is invalid.

## Test-Driven Implementation

The test file is written and run before production functions exist. The
first run must fail because the new functions are undefined.

The final suite covers:

1. instantaneous-frequency dimensions and range;
2. symbol-dependent wrap locations;
3. full-RF Doppler formula;
4. carrier-only Doppler formula;
5. trapezoidal phase integration;
6. unit-magnitude phase rotation;
7. unit average signal power without AWGN;
8. complex AWGN variance and real/imaginary balance;
9. carrier-only approximation error;
10. wrapper equivalence to the original demodulator;
11. complete dechirp-FFT-argmax detection on the Doppler-distorted input;
12. validation failures for invalid input.

The orbit Figure 3 tests remain part of the full regression command.

## Acceptance Criteria

- The new test must be observed failing before production code exists.
- All orbit and channel tests pass in MATLAB R2022a.
- MATLAB Code Analyzer reports zero messages for new files.
- Original modulation and demodulation files remain unchanged.
- The full-RF model is the default.
- Diagnostics identify trapezoidal integration and the selected mode.
- No artificial FFT-bin movement or Doppler correction is present.
