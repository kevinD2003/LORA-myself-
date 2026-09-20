# B-case-anchor-AWGN-v6-audit

Status: **PASS**

- Stage algorithm: `Stage55-B-known-case-profile-v8`
- Paper algorithm: `Paper-Midamble-Point-integer-full-FFT-v2`
- Unchanged conditions: SF12, BW/Fs 125 kHz, no-LDRO, CR3, 112 data symbols, 768 information bits, AWGN, Case -366/0 s, 200 paired packets/cell.
- Requested SNR extension: -30:-15 dB.
- Total: 32 cells, 6400 paired packets, 10000 bootstrap draws/point.
- all32CellsRecomputed: PASS
- singleSourceHash: PASS
- reportRawCountsRecomputed: PASS
- case1AdmissionPass: PASS
- case2AdmissionPass: PASS
- paperCurvePass: PASS
- case2BerTargetPass: PASS
- regimeIdentityPass: PASS
- originalBaselinesUnchanged: PASS
- paperIntegerEstimatorIsolationPass: PASS
- knownCaseProfileAuthorizationPass: PASS
- previousV3EvidencePreserved: PASS
- Zero floor: Strict inequality is replaced by equality only when the compared Case-1 Paper error count is zero.
