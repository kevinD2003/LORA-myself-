# Findings: Dynamic Doppler Channel Acceptance Tests

- Current modes are `full_rf` and `carrier_only_approximation`.
- The original detector maps a positive integer-bin phase ramp to the
  transmitted symbol plus that bin offset modulo `M`.
- Trapezoidal phase integration produces interval-centered frequency,
  so the exact numerical-derivative reference is the average of adjacent
  Doppler-frequency samples.
- Figure 17 formula-derived values with device A at `t_cv=0`:
  - device-A first outer endpoint: `-254.870648405068 s`;
  - device-A first inner endpoint: `-2.344896842552 s`;
  - device center separation: `1.507287527200 s`;
  - shared first interval:
    `[-253.364624963310, -2.344896842552] s`.
- Device-A Doppler evaluated at shared endpoints:
  - left: `18597.819083 Hz`, rate `-5.531386 Hz/s`;
  - right: `571.081217 Hz`, rate `-243.336852 Hz/s`.
- The target directory is not a Git repository.
- Final regression: 24 passed, 0 failed, 0 incomplete.
- Code Analyzer: 0 messages across eight orbit/channel files.
- Results transcript:
  `D:\codex\lora(CFO)\test_dynamic_doppler_results.txt`,
  SHA-256
  `C567B20C2A75EB322EA8C4E6BBE6C691FCE06CF10A61B85FD6BA7D785720EB2C`.
- Original modulator and demodulator SHA-256 values still match their
  pre-implementation baselines.
