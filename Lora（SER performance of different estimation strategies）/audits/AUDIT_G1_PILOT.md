# AUDIT_G1_PILOT

Status: **PASS_WITH_NOTES**  
Date: 2026-09-21  
Evidence: `results/pilot/**`, 5 orbit anchors at -24 dB, 200 packets/cell.

## Validity checks

- Five signed result cells are complete; each contains 200 packets.
- 1000 packet identities and ledger hashes are globally unique.
- Each packet has exactly one shared-input fingerprint across Huang, Paper, Stage55 and Ideal.
- All cells use one implementation digest and one frozen-parent manifest digest.
- Receiver failures: 0. No packet was silently dropped.
- Ideal SER is position-stable (0.0578 to 0.0630), supporting correct truth compensation and fixed-noise normalization.
- Start Doppler, start/peak rate, signed frame drift and frame range vary smoothly with the five frozen orbit anchors.
- Packet-level CSV, symbol-position CSV, paired DeltaSER intervals and figures were regenerated from cell MAT files.
- The Formal two-SNR plotting path separates SNR series for DeltaSER and within-frame diagnostics; it does not join unlike SNR points.

## Pilot scientific notes

- Stage55 and Huang are exactly paired-identical at the first four anchors because the frozen observable selector chooses the Huang-equivalent static path. No payload VP is accepted there.
- At 0 s, Stage55 accepts 700 VPs across 200 packets, with 54 offline-diagnosed false acceptances, and improves SER relative to both Huang and Paper.
- Paper is better than Stage55 at -274.5, -183 and -91.5 s, while Stage55 is better at -366 and 0 s. This crossover is retained; no receiver parameter is changed.
- Paper residual-CFO diagnostics contain very large outliers at several anchors. Direct packet inspection confirms these are the actual applied Point/trend estimates, not a unit conversion error; the affected cells also show elevated SER.

## Gate decision

**PASS_WITH_NOTES.** No implementation or statistical validity blocker remains. The non-monotone method ordering and Stage55 mode transition are scientific outcomes to report, not tuning triggers. Formal may proceed with the frozen configuration and independent Formal seeds.
