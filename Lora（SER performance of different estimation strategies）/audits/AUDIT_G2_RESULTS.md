# AUDIT_G2_RESULTS

Status: **PASS_WITH_NOTES**  
Date: 2026-09-22  
Scope: Formal main scan, mandatory VP ablation, packet-level aggregation, confidence intervals, figures, and reproducibility evidence.

## Completeness and identity

- Formal: 10/10 cells complete, 1000 packets/cell, 40,000 method-packet rows, 10,000 globally unique packet ledgers, zero receiver failures.
- Ablation: 6/6 cells complete, 1000 packets/cell, 12,000 method-packet rows, 6000 globally unique packet ledgers, zero receiver failures.
- Every completed cell uses one frozen-parent manifest digest and one EXP1 implementation digest.
- The six ablation cells reuse the corresponding Formal packet identities. Stage55 Formal and Stage55 ablation arrays match exactly for seeds, ledger hashes, input fingerprints, symbol/bit errors, per-symbol error masks, residual CFO, VP counts, and failure flags.
- `Stage55-VP-off` accepted exactly zero payload VPs in all 6000 ablation packets.
- All summaries and figures were regenerated from the completed packet-level MAT files. No failed packet was discarded.

## Statistical checks

- Main SER and paired `DeltaSER` intervals use 10,000 packet-block bootstrap draws.
- Different methods share the same packet resampling indices within each cell.
- Zero-error absolute intervals use the registered conservative packet-event upper bound; paired all-zero comparisons do not claim a false zero-width uncertainty interval.
- No Formal comparison required additional packets for CI precision: all scientifically relevant Paper/Stage55 and Huang/Stage55 differences away from exact shared paths have intervals that are clearly separated from zero.

## Main results

At the first four anchors, the frozen observable selector routes Stage55 to the Huang-equivalent static path. Their packet results are therefore exactly paired-identical; this is an applicability boundary, not evidence that VP tracking is ineffective after it is activated.

At `t0 = 0 s`:

| SNR | Huang SER | Paper SER | Stage55 SER | Ideal SER |
|---:|---:|---:|---:|---:|
| -24 dB | 0.997036 | 0.503268 | 0.249982 | 0.061429 |
| -21.12 dB | 0.994491 | 0.042839 | 0.017554 | 0.000179 |

Paper is better than Stage55 at `-274.5`, `-183`, and `-91.5 s`; Stage55 is better at `-366` and `0 s`. The crossover is reported as measured and was not used to change receiver parameters.

Ideal SER remains position-stable within each SNR: approximately `0.0614-0.0628` at -24 dB and `1.43e-4-1.96e-4` at -21.12 dB. This supports fixed noise normalization and correct exact-Doppler compensation.

## VP mechanism result

At `t0 = 0 s`, paired VP-off minus Stage55 differences are:

| SNR | Stage55 SER | VP-off SER | Paired DeltaSER (95% CI) |
|---:|---:|---:|---:|
| -24 dB | 0.249982 | 0.272152 | 0.022170 `[0.015107, 0.029335]` |
| -21.12 dB | 0.017554 | 0.083911 | 0.066357 `[0.058554, 0.074464]` |

At -21.12 dB, CFO RMSE falls from `8.081 Hz` with VP-off to `4.025 Hz` with VP-on. At -24 dB, aggregate CFO RMSE is nearly unchanged (`10.974` versus `10.971 Hz`) while SER still improves, so the lower-SNR mechanism statement must rely on the paired SER and within-frame diagnostics rather than claim a large aggregate CFO-RMSE reduction.

At `-366` and `-91.5 s`, VP-on and VP-off are exactly identical because neither path accepts payload VPs under the frozen mode rule.

## Engineering note

During ablation, Windows intermittently prevented `movefile(...,'f')` from replacing the checkpoint target. Each event occurred after a complete temporary MAT had been written. Recovery preserved the previous checkpoint, promoted the latest temporary checkpoint, and resumed with the same signature. All recovered cells later completed, and the Formal/ablation exact-array comparison passed. Backup checkpoints are retained as evidence.

## Conclusion boundary

Engineering/statistical status is **PASS_WITH_NOTES**. The results support that payload VP updates improve Stage55 at the tested `0 s` high-rate anchor, especially at -21.12 dB. They do not support a claim that Stage55 is best across the whole orbit, that gain grows monotonically with drift, or that the selected -21.12 dB point is an exact reproduction of the paper's Fig.12 SNR convention.

No refinement was launched: the registered five-anchor Formal comparisons and VP ablation have decisive intervals for the stated first-round questions. Any denser search for the observable mode-transition location should be labeled exploratory and use new independent confirmation seeds.
