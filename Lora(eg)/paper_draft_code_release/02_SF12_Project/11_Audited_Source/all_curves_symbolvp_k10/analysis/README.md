# Full-curve reporting

`all_curves_aggregate.py` validates the new packet files and creates plotting tables. It runs no receiver and generates no observations. `plotAllCurves.m` creates one figure for each SF × channel × family: 12 pre-FEC SER figures and, by default, another 12 decoded BER figures. Every figure is exported as PNG and vector PDF.

The physical grid has 100 points:

| SF | Channels | Case 1 and Case 2 SNR sweep | Half-orbit start times |
|---|---|---|---|
| 7 | AWGN, Rician | −15:−6 dB, each case | −366, −274.5, −183, −91.5, 0 s |
| 12 | AWGN, Rician | −30:−21 dB, each case | −366, −274.5, −183, −91.5, 0 s |

Case 1 starts at −366 s; Case 2 starts at 0 s. Half-orbit Es/N0 is 14 dB for AWGN and 15 dB for Rician. The grid has 80 SNR points and 20 half-orbit points. It uses the registered K=10 dB/PDP 5 channel, CR3, 112 data chirps, and no LDRO. The native frame has 120 rows; the Paper frame has 129 rows at SF7 and 157 at SF12.

## Run

From this experiment directory, use a Python runtime with NumPy. The desktop bundle supplies one at `C:/Users/chene/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe`.

```powershell
& 'C:/Users/chene/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' analysis/all_curves_aggregate.py validation100
```

The default plan is `POINTS.json`, with a top-level `points` array. Each point has `id`, `index`, `sf`, `channel`, `family`, `orbitStartSec`, `snrDb`, and `esN0Db`. `family` may be `case1`, `case2`, or `half`; the runner's `case` plus `caseIndex` form is also accepted. The aggregator rejects a missing, repeated, or changed physical point. Use `--plan` for a different saved plan file.

After aggregation, in MATLAB:

```matlab
plotAllCurves("validation100");
% SER figures alone:
plotAllCurves("validation100",Metric="preFecHardSer");
```

The formal cohort uses the same commands with `formal1000`. The two cohorts write to separate directories and are never pooled. Partial cohort reporting creates a PENDING aggregate manifest. Final plotting requires complete validation of all 100 points. `AllowPartial=true` explicitly permits preview figures carrying a PENDING label.

Calculation checks use metadata and count arrays only; they do not create experiment results:

```powershell
& 'C:/Users/chene/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' -m unittest discover -s analysis -p test_all_curves_aggregate.py
```

## Input and output

Every `results/{cohort}/{pointId}` directory must contain `SUMMARY.json`, `RAW_PACKETS.csv`, `CHECKPOINT.mat`, and `MANIFEST.json`. The fixed budgets are 100 packets for `validation100` and 1000 for `formal1000`. Each point uses consecutive packet IDs beginning at 1. Seed bases are `2700000000 + index*100000` and `2800000000 + index*100000`, respectively, with packet stride 8 and payload/noise/channel offsets 0/1/2. The Paper-only extra-noise offset is 3.

The CSV method prefixes are `prec`, `vp`, `paper`, `idealNative`, and `idealPaper`. Each has `Errors` and `Failure`. The three actual methods additionally have `BitErrors` and `DecodeFailure`. A receiver failure contributes all 112 chirp errors; a decoder failure contributes all information bits in error. Summary totals must reproduce the raw counts. Live source hashes in `codeProvenance` must still match, and every point must have the same source and PDP hashes. The aggregator validates the fixed nominal noise variance and frame geometry.

Outputs are under `results/{cohort}/analysis`:

- `ALL_CURVES_METRICS.csv`: 500 SER rows and 300 decoded BER rows for a complete cohort, including raw evidence hashes, packet counts, failures, and intervals.
- `ALL_CURVES_PAIRED_DIFFERENCES.csv`: signed VP−PREC, VP−Paper, and PREC−Paper differences, for SER and BER. Intervals resample matched packet differences; they do not imply a required method ordering.
- `AGGREGATE_MANIFEST.json`: coverage, missing/incomplete/invalid points, source evidence hashes, and output CSV hashes.
- `ENDPOINT_24_COMPARISON.csv`: the 12 published physical endpoints × Paper/IdealPaper. Nominal and one-sided pointwise 95% comparisons are separate. Existing files supply reference thresholds only; their old packet counts are not pooled.
- `VALIDATION_GATE.json` (validation cohort only): written only after exact 100-point, 100-packet coverage, valid live source hashes, and zero receiver/decoder failures. SER targets and method ordering are not gate requirements.
- `figures/`: full-range figures. A separate dotted IdealPaper curve retains the Paper frame's timing, alongside IdealNative's native-frame timing. No shared ideal or flat-Rician theory is substituted.

## Metrics and uncertainty

The main SER is the observed number of pre-FEC hard FFT chirp errors divided by `packets × 112`, including for the VP receiver, which can use coding internally. Decoded information-bit BER is a separate result with 448 bits/packet at SF7 and 768 bits/packet at SF12. The main SER must never be replaced by decoded or reencoded decisions.

Nonzero-error intervals use packet-level histogram bootstrap resampling, exactly equivalent to resampling the packet counts. The validation cohort uses 4000 replicates; the formal cohort uses 10000. The paired-difference intervals resample packet differences, preserving pairing. Intervals are pointwise 95% percentile intervals and do not constitute simultaneous coverage across curves.

Zero observed errors remain exactly zero in the CSV. On a logarithmic figure, an open downward triangle marks `1 − 0.05^(1/packets)`, an exact one-sided 95% upper bound on packet error probability and therefore a conservative upper bound on symbol or bit error rate. This bound permits arbitrary dependence within a packet. It does not treat 112 chirps as independent trials and does not draw a positive measured SER. Curves break at zero measurements.
