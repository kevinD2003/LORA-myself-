# Single-Symbol Dynamic Doppler Channel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a single-symbol LoRa dynamic Doppler channel that integrates the full instantaneous RF Doppler trajectory, adds complex AWGN, and feeds the unchanged noncoherent detector.

**Architecture:** Compute the wrapped LoRa baseband frequency analytically from symbol and sample index. Sample the validated orbit model at `t0+n/B`, form either full-RF or carrier-only Doppler, integrate it with the trapezoidal rule, rotate the existing waveform, add complex AWGN, and call the original detector without compensation.

**Tech Stack:** MATLAB R2022a, `matlab.unittest`, existing orbit model in `D:\codex\lora(CFO)`, original CSS functions in `D:\codex\Lora(theory)`.

## Global Constraints

- Do not modify `lora_css_modulate.m` or `lora_css_demodulate.m`.
- The full-RF formula `-(fc+f_bb)*v/c` is the default.
- `carrier_only_approximation` is validation-only.
- Use trapezoidal Doppler-frequency integration with `phi_D(1)=0`.
- Assume `Fs=B`, unit sample power, complex AWGN, and ideal symbol boundaries.
- Do not compensate Doppler or shift FFT bins.
- Do not add BER sweeps, interference, FEC, fading, multipath, CFO, STO, or framing.

---

### Task 1: Write and verify the failing channel tests

**Files:**
- Create: `D:\codex\lora(CFO)\test_lora_dynamic_channel.m`

**Interfaces:**
- Consumes: original `lora_css_modulate(symbol,sf)` and orbit configuration.
- Produces: executable requirements for the three new public functions.

- [ ] **Step 1: Record hashes of the original modulator and demodulator**

Run:

```powershell
Get-FileHash 'D:\codex\Lora(theory)\lora_css_modulate.m' -Algorithm SHA256
Get-FileHash 'D:\codex\Lora(theory)\lora_css_demodulate.m' -Algorithm SHA256
```

- [ ] **Step 2: Create the function-based test suite**

The suite must include:

```matlab
function tests = test_lora_dynamic_channel
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
testCase.TestData.originalPath = path();
addpath("D:\codex\Lora(theory)");
end

function teardownOnce(testCase)
path(testCase.TestData.originalPath);
end
```

Required tests call the wished-for APIs:

```matlab
frequencyHz = lora_symbol_instantaneous_frequency(symbol, sf, bandwidthHz);

[rx, diagnostics] = apply_lora_dynamic_doppler( ...
    tx, symbol, sf, startTimeSec, config, ...
    BandwidthHz=bandwidthHz, SNRdB=Inf, Mode="full_rf");

detected = lora_css_demodulate_dynamic_channel(rx, sf);
```

Assertions cover frequency range and wrap, full-RF formula, carrier-only
formula, trapezoidal phase, unit rotation magnitude, noiseless power,
complex-noise variance, approximation error, original-detector
equivalence, direct FFT argmax equivalence, and invalid inputs.

- [ ] **Step 3: Run the tests and verify RED**

Run:

```matlab
suite = matlab.unittest.TestSuite.fromFile( ...
    "D:\codex\lora(CFO)\test_lora_dynamic_channel.m");
results = run(suite);
```

Expected: failures with undefined-function errors for the three new
functions. A syntax error or path error does not count as RED.

---

### Task 2: Implement wrapped instantaneous frequency

**Files:**
- Create: `D:\codex\lora(CFO)\lora_symbol_instantaneous_frequency.m`
- Test: `D:\codex\lora(CFO)\test_lora_dynamic_channel.m`

**Interfaces:**
- Consumes: scalar `symbol`, scalar `sf`, scalar `bandwidthHz`.
- Produces: `M`-by-1 double vector in hertz.

- [ ] **Step 1: Implement input validation and the analytic formula**

```matlab
m = 2^sf;
sampleIndex = (0:m-1).';
frequencyHz = bandwidthHz*(mod(sampleIndex + double(symbol), m)/m - 0.5);
```

Validate `sf` as integer `1:20`, symbol as integer `[0,M-1]`, and
bandwidth as positive finite scalar.

- [ ] **Step 2: Run frequency-specific tests**

Expected: dimensions, limits, and wrap-location tests pass. Channel and
wrapper tests still fail because their functions do not exist.

---

### Task 3: Implement the dynamic Doppler channel

**Files:**
- Create: `D:\codex\lora(CFO)\apply_lora_dynamic_doppler.m`
- Test: `D:\codex\lora(CFO)\test_lora_dynamic_channel.m`

**Interfaces:**
- Consumes: one `M`-sample waveform, symbol, SF, start time, orbit config, and name-value options.
- Produces: received waveform and diagnostic structure.

- [ ] **Step 1: Validate the one-symbol input**

Require an `M`-element complex or real numeric vector, finite start time,
positive finite bandwidth, `SNRdB` finite or positive infinity, and mode
in `["full_rf","carrier_only_approximation"]`.

- [ ] **Step 2: Sample the orbit and compute Doppler**

```matlab
sampleRateHz = options.BandwidthHz;
sampleTimeSec = startTimeSec + (0:m-1).'/sampleRateHz;
orbit = lora_orbit_doppler_trajectory(sampleTimeSec, orbitConfig);
basebandFrequencyHz = lora_symbol_instantaneous_frequency( ...
    symbol, sf, options.BandwidthHz);

if options.Mode == "full_rf"
    instantaneousRfHz = orbitConfig.carrierFrequencyHz + ...
        basebandFrequencyHz;
else
    instantaneousRfHz = repmat( ...
        orbitConfig.carrierFrequencyHz, m, 1);
end

dopplerFrequencyHz = -instantaneousRfHz.* ...
    orbit.radialVelocityMps/orbitConfig.speedOfLightMps;
```

- [ ] **Step 3: Integrate phase with the trapezoidal rule**

```matlab
phaseIncrementRad = pi/sampleRateHz* ...
    (dopplerFrequencyHz(1:end-1) + dopplerFrequencyHz(2:end));
dopplerPhaseRad = [0; cumsum(phaseIncrementRad)];
phaseRotation = exp(1i*dopplerPhaseRad);
```

- [ ] **Step 4: Add complex AWGN**

```matlab
if isinf(options.SNRdB)
    noiseVariance = 0;
    noise = complex(zeros(m, 1));
else
    noiseVariance = 10^(-options.SNRdB/10);
    noise = sqrt(noiseVariance/2)* ...
        (randn(m, 1) + 1i*randn(m, 1));
end
rx = tx(:).*phaseRotation + noise;
```

Return all values named in the approved design, including
`integrationRule="trapezoidal"` and the selected mode.

- [ ] **Step 5: Run channel tests**

Expected: all frequency and channel tests pass. Wrapper tests still fail
because the wrapper does not exist.

---

### Task 4: Add the no-compensation detector wrapper

**Files:**
- Create: `D:\codex\lora(CFO)\lora_css_demodulate_dynamic_channel.m`
- Test: `D:\codex\lora(CFO)\test_lora_dynamic_channel.m`

**Interfaces:**
- Consumes: Doppler-distorted `rx` and scalar `sf`.
- Produces: the original detector's symbol result.

- [ ] **Step 1: Implement the wrapper**

```matlab
function detectedSymbol = lora_css_demodulate_dynamic_channel(rx, sf)
%LORA_CSS_DEMODULATE_DYNAMIC_CHANNEL Detect without Doppler compensation.
detectedSymbol = lora_css_demodulate(rx, sf);
end
```

- [ ] **Step 2: Run the complete new suite**

Expected: all channel tests pass, including exact equality with the
original detector and manual `argmax(abs(fft(...)).^2)`.

---

### Task 5: Full regression and source-integrity verification

**Files:**
- Verify: all MATLAB files in `D:\codex\lora(CFO)`
- Verify: original CSS files in `D:\codex\Lora(theory)`

- [ ] **Step 1: Run orbit and channel suites together**

Use `matlab.unittest.TestSuite.fromFile` for:

```text
test_lora_dynamic_doppler.m
test_lora_dynamic_channel.m
```

Expected: zero failed and zero incomplete tests.

- [ ] **Step 2: Run MATLAB Code Analyzer**

Run `checkcode(file,"-id")` for all three new production files and the
new test file. Expected: zero messages.

- [ ] **Step 3: Recompute original-file SHA-256 hashes**

Expected: both hashes exactly equal the values captured in Task 1.

- [ ] **Step 4: Review the implementation against the approved spec**

Confirm the default mode is full RF, the integration rule is
trapezoidal, phase is retained through detection, and no FFT-bin shift
or compensation code exists.
