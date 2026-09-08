# Dynamic Doppler Channel Acceptance Tests Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the requested deterministic dynamic-Doppler channel tests, an explicit no-Doppler mode, and a fresh MATLAB results transcript without running BER.

**Architecture:** Keep the original LoRa modulator and detector unchanged. Extend the existing channel mode switch minimally, add all geometry and acceptance helpers locally to the existing test file, and generate the requested transcript from the MATLAB test runner.

**Tech Stack:** MATLAB R2022a, `matlab.unittest`, MATLAB Code Analyzer, PowerShell SHA-256 verification.

## Global Constraints

- Work in `D:\codex\lora(CFO)`.
- Do not modify `D:\codex\Lora(theory)\lora_css_modulate.m` or `lora_css_demodulate.m`.
- Do not run a BER sweep.
- Preserve full-RF mode as the default.
- Preserve trapezoidal Doppler-phase integration.
- Do not add Doppler compensation or artificial FFT-bin shifting.
- Every numeric comparison uses the tolerance in the approved design.

---

### Task 1: Add the failing no-Doppler contract tests

**Files:**
- Modify: `D:\codex\lora(CFO)\test_lora_dynamic_channel.m`
- Test: `D:\codex\lora(CFO)\test_lora_dynamic_channel.m`

**Interfaces:**
- Consumes: `apply_lora_dynamic_doppler(tx, symbol, sf, t0, config, Name=Value)`
- Produces: acceptance coverage for `Mode="no_doppler"`

- [ ] **Step 1: Add a test for exact no-Doppler pass-through**

Add a function test that calls:

```matlab
[rx, diagnostics] = apply_lora_dynamic_doppler( ...
    tx, symbol, sf, startTimeSec, config, ...
    BandwidthHz=bandwidthHz, SNRdB=Inf, Mode="no_doppler");
```

Assert `rx == tx`, zero Doppler frequency, zero phase, and unit phase
rotation using `AbsTol=1e-12`.

- [ ] **Step 2: Add detector-equivalence assertions**

Run both:

```matlab
actual = lora_css_demodulate_dynamic_channel(rx, sf);
expected = lora_css_demodulate(tx, sf);
```

Assert exact integer equality.

- [ ] **Step 3: Run the focused tests and verify RED**

Run the `test_lora_dynamic_channel.m` suite in MATLAB R2022a.

Expected: the new test fails with `lora:InvalidDopplerMode` because the
production mode is not implemented.

### Task 2: Implement the no-Doppler mode

**Files:**
- Modify: `D:\codex\lora(CFO)\apply_lora_dynamic_doppler.m`
- Test: `D:\codex\lora(CFO)\test_lora_dynamic_channel.m`

**Interfaces:**
- Consumes: `options.Mode` string
- Produces: `Mode="no_doppler"` with zero `f_D` and zero phase

- [ ] **Step 1: Extend mode validation**

Use:

```matlab
allowedModes = [ ...
    "full_rf", ...
    "carrier_only_approximation", ...
    "no_doppler"];
```

- [ ] **Step 2: Add the minimal Doppler-frequency branch**

Keep full-RF and carrier-only formulas unchanged, and implement:

```matlab
if options.Mode == "no_doppler"
    instantaneousRfHz = zeros(m, 1);
    dopplerFrequencyHz = zeros(m, 1);
else
    dopplerFrequencyHz = -instantaneousRfHz.* ...
        orbit.radialVelocityMps/orbitConfig.speedOfLightMps;
end
```

The existing trapezoidal integration then produces exactly zero phase.

- [ ] **Step 3: Run the focused suite and verify GREEN**

Expected: all dynamic-channel tests pass.

### Task 3: Add deterministic physical and signal-processing tests

**Files:**
- Modify: `D:\codex\lora(CFO)\test_lora_dynamic_channel.m`

**Interfaces:**
- Consumes: existing full-RF, carrier-only, orbit, modulation, and detector functions
- Produces: tests for zero physics, bin movement, phase recovery, approximation scale, Figure 17 geometry, and seeded AWGN

- [ ] **Step 1: Add zero-carrier and zero-velocity tests**

For zero carrier, use carrier-only mode and `fc=0`. For zero velocity,
set:

```matlab
omegaSatellite = sqrt(g*R^2/(R+H)^3);
config.earthRotationRadPerSec = ...
    omegaSatellite/cos(config.inclinationRad);
```

Assert waveform, frequency, and phase with `AbsTol=1e-12`.

- [ ] **Step 2: Add the static integer-bin test**

Use a literal positive bin movement such as `offsetBins=7`:

```matlab
shifted = tx.*exp(1i*2*pi*offsetBins*(0:m-1).'/m);
```

Assert detected symbol equals
`uint32(mod(double(symbol)+offsetBins,m))` exactly.

- [ ] **Step 3: Add trapezoidal phase-recovery test**

Compute:

```matlab
unwrappedPhase = unwrap(angle(exp(1i*diagnostics.dopplerPhaseRad)));
recoveredHz = diff(unwrappedPhase)*bandwidthHz/(2*pi);
expectedHz = 0.5*(diagnostics.dopplerFrequencyHz(1:end-1) + ...
    diagnostics.dopplerFrequencyHz(2:end));
```

Assert with `AbsTol=1e-5 Hz`.

- [ ] **Step 4: Add the `B/fc` approximation-scale test**

For samples with nonzero carrier-only Doppler:

```matlab
relativeDifference = abs(fullHz-carrierHz)./abs(carrierHz);
```

Assert its maximum equals `bandwidthHz/(2*fc)` with
`AbsTol=5e-12`.

- [ ] **Step 5: Add Figure 17 test-local geometry helpers**

Create local helpers that:

- build device A and B configurations using the approved angles;
- calculate `Delta_t_AB` from paper equation (16);
- calculate both single visibility windows;
- intersect their first intervals.

Assert the device-A outer endpoint, shared endpoints, and device-A
Doppler values using the approved time, hertz, and hertz-per-second
tolerances. Keep single-device and shared values in separate variables.

- [ ] **Step 6: Add seeded AWGN reproducibility test**

Save the current RNG state with `onCleanup`, reset the same Twister seed
before each channel call, and assert exact equality of returned waveforms
and noise variance.

- [ ] **Step 7: Run the focused suite**

Expected: all dynamic-channel tests pass without BER execution.

### Task 4: Full verification and results transcript

**Files:**
- Create: `D:\codex\lora(CFO)\test_dynamic_doppler_results.txt`
- Verify: all orbit and dynamic-channel MATLAB files

**Interfaces:**
- Consumes: both MATLAB unit-test suites
- Produces: fresh, human-readable MATLAB verification record

- [ ] **Step 1: Run both test suites under a MATLAB diary**

The MATLAB batch command must:

- start `diary("test_dynamic_doppler_results.txt")`;
- print `version`;
- run `test_lora_dynamic_doppler.m` and
  `test_lora_dynamic_channel.m`;
- print individual results and total counts;
- print Figure 17 formula-derived values;
- run `checkcode` for the modified implementation and test files;
- stop the diary;
- return a nonzero process status if any test fails or is incomplete.

- [ ] **Step 2: Inspect the complete transcript**

Confirm the file contains zero failures, zero incomplete tests, all
requested geometry diagnostics, and no BER output.

- [ ] **Step 3: Recompute original-file hashes**

Expected SHA-256:

```text
lora_css_modulate.m
A054534381C522EFCA0106DB05F08F19F62D4AF38C4CDAE53B791223CA5DDFA2

lora_css_demodulate.m
E631495EE0D082453A61062D820D5B024470500BD37312A69E6B498EC30C8609
```

- [ ] **Step 4: Review the final diff manually**

Confirm only the approved channel mode, tests, documentation, planning
records, and result transcript changed. This directory is not a Git
repository, so no commit step is available.
