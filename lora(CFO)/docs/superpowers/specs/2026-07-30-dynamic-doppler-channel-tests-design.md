# Dynamic Doppler Channel Acceptance-Test Design

## Scope

Extend the existing single-symbol dynamic Doppler channel tests without
running a BER sweep. The original LoRa modulator, original demodulator,
Figure 3 outputs, and AWGN baseline remain unchanged.

The implementation changes only:

- `apply_lora_dynamic_doppler.m`, to add an explicit `no_doppler` mode;
- `test_lora_dynamic_channel.m`, to add the requested deterministic
  acceptance tests.

The MATLAB run transcript is written to
`test_dynamic_doppler_results.txt`.

## Doppler Modes

The supported modes become:

- `full_rf`: `f_D[n] = -(fc + f_bb[n])*v[n]/c`;
- `carrier_only_approximation`: `f_D[n] = -fc*v[n]/c`;
- `no_doppler`: `f_D[n] = 0`.

In `no_doppler` mode, Doppler phase and phase rotation are respectively
zero and one. Complex AWGN remains controlled by `SNRdB`. Therefore,
`SNRdB=Inf` makes the received waveform exactly equal to the transmitted
waveform.

## Test Architecture

The new cases are added to `test_lora_dynamic_channel.m`. Test-only
helpers calculate Figure 17 geometry from paper parameters and formulas;
no Figure 17 production or BER function is introduced in this phase.

The original functions in `D:\codex\Lora(theory)` are added temporarily
to the MATLAB path by the existing test fixture.

## Acceptance Cases and Tolerances

### Zero Doppler invariants

Two independent zero-Doppler mechanisms are checked:

1. Set `fc=0` and select `carrier_only_approximation`.
2. Set the orbit configuration so that
   `omega_S = omega_E*cos(i)`, hence `omega_F=0`, and select `full_rf`.

For both cases:

- received waveform versus transmitted waveform:
  `AbsTol = 1e-12`;
- Doppler frequency and phase versus zero:
  `AbsTol = 1e-12`.

The explicit `no_doppler` mode is checked with `SNRdB=Inf` using the same
waveform tolerance.

### Detector equivalence

The output of `lora_css_demodulate_dynamic_channel` in `no_doppler`
conditions must equal the output of the original
`lora_css_demodulate`. Detected symbols are integers and must be exactly
equal.

### Static integer-bin frequency offset

A deterministic frequency offset of `k*Fs/M` is applied directly to a
modulated symbol as

```text
x_shifted[n] = x[n] * exp(j*2*pi*k*n/M).
```

The complete original dechirp-FFT detector is run. The detected peak-bin
movement must equal `k` modulo `M`, with exact integer equality. This is
a detector-boundary test and does not add a static-offset mode to the
orbit channel.

### Phase integration recovery

Because the channel uses trapezoidal integration, the numerical
derivative is naturally defined on sample intervals:

```text
f_recovered[n] =
    diff(unwrap(angle(exp(j*phi_D))))*Fs/(2*pi)

f_expected[n] = (f_D[n] + f_D[n+1])/2.
```

The comparison uses `AbsTol = 1e-5 Hz`. This alignment tests the actual
integration rule instead of incorrectly comparing interval derivatives
with endpoint samples.

### Carrier-only approximation scale

At every nonzero-velocity sample:

```text
abs(f_D,full - f_D,carrier) / abs(f_D,carrier)
    = abs(f_bb)/fc.
```

The maximum is compared with `B/(2fc)` using
`AbsTol = 5e-12`. This explicitly verifies the expected `B/fc` small
parameter.

### Figure 17 geometry

The test uses:

```text
fc = 868e6 Hz
B = 250e3 Hz
H = 550e3 m
i = 15 degrees
d = 10e3 m
theta_c_A = 89 degrees
theta_c_B = 89.2 degrees
theta_min_A = theta_min_B = 10 degrees
theta_max_A = theta_max_B = 88 degrees
t_cv_A = 0
```

The center-time separation `Delta_t_AB` is computed from paper equation
(16), and each device window is computed from equations (13)-(14). The
first shared visibility interval is their intersection.

The test keeps single-device-A and shared-window quantities distinct:

- device-A outer endpoint:
  `t = -254.870648 s`, `AbsTol = 0.05 s`;
- paper-reported rounded high-shift time:
  `-254.9 s`, `AbsTol = 0.1 s`;
- first shared-window left endpoint:
  formula-derived value near `-253.364625 s`;
- device-A Doppler magnitude near the high-shift endpoint:
  `18.6 kHz`, `AbsTol = 100 Hz`;
- corresponding Doppler-rate magnitude:
  `5.4 Hz/s`, `AbsTol = 0.2 Hz/s`;
- first shared-window right endpoint:
  `-2.34490 s`, `AbsTol = 0.01 s`;
- corresponding Doppler magnitude:
  `571 Hz`, `AbsTol = 2 Hz`;
- corresponding Doppler-rate magnitude:
  `243 Hz/s`, `AbsTol = 1 Hz/s`.

The shared endpoints are derived from window intersection, never
hard-coded as channel inputs.

### Random reproducibility

The RNG state is saved and restored within the test. Two finite-SNR
channel calls made after resetting the same Twister seed must return
exactly equal waveforms and noise-related diagnostics.

## Result File

MATLAB runs the orbit and dynamic-channel test suites together. The
plain-text transcript includes:

- MATLAB version;
- test names and pass/fail status;
- total, passed, failed, and incomplete counts;
- the Figure 17 formula-derived diagnostic values;
- Code Analyzer results for the modified implementation and test files.

No BER loop or BER output is generated.

## Acceptance Criteria

- Every requested invariant has an explicit numerical tolerance.
- The new `no_doppler` test is observed failing before the production
  mode is added.
- All Figure 3 and dynamic-channel tests pass in MATLAB R2022a.
- MATLAB Code Analyzer reports no issues for modified files.
- `test_dynamic_doppler_results.txt` contains the fresh MATLAB results.
- Original AWGN modulator and demodulator hashes remain unchanged.
