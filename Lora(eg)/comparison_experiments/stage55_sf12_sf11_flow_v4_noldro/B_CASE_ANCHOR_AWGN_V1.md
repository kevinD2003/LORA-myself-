# Experiment B coding under Experiment A Case anchors — AWGN v1

Identity: `B-case-anchor-AWGN-v1`.

This is a new, isolated cross-experiment diagnostic. It is neither the original Experiment A nor the complete-pass Experiment B result.

- PHY/coding: SF12, BW/Fs 125 kHz, no-LDRO, CR3, 768 information bits, 112 data symbols.
- Timeline: controlled-time 8 bootstrap + 112 D + 37 Paper midambles = 157T.
- Case 1 start: -366 s in the independent Track A orbit; approximately 662.8 CFO bins and approximately zero CFO rate.
- Case 2 start: 0 s; approximately zero CFO bins and -9.15 bins/s CFO rate.
- Channel: AWGN only.
- SNR: -30:-21 dB.
- Fixed sample: 200 independent paired packets per Case/SNR.
- Statistical unit: paired packet; 10000 paired-packet bootstrap draws per point.
- Each packet is independent. No cross-packet receiver history is carried.

Huang, Paper and the physical conditions are not altered. Large absolute CFO alone is not treated as failure: the common fractional bootstrap must remove it. Case 1 is the mechanism check that Huang remains effective when CFO is large but nearly static.
