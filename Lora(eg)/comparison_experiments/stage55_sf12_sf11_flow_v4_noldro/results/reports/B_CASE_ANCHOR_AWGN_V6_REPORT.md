# B-case-anchor-AWGN-v6-known-case-profile report

Status: **PASS**

- Algorithm: `Stage55-B-known-case-profile-v8`
- Paper algorithm: `Paper-Midamble-Point-integer-full-FFT-v2`
- Fixed sample: 200 paired packets per Case/SNR.
- SNR: -30:-15 dB; AWGN; CR3; 112 symbols; 768 information bits.
- Case 1 rule: Stage <= Huang and Stage < Paper; when Paper has zero errors, Stage must also be zero.
- Case 2 rule: Stage < Huang and Stage < Paper at every SNR for SER, hard BER and ML BER.
- Case 1 pass: 1. Case 2 pass: 1. Regime gate pass: 1.
- Zero plot convention: 0.5/N for log display only; CSV/JSON preserve raw zero.
- Selection uses payload/orbit truth: false.

Artifacts:

- `B_CASE_ANCHOR_AWGN_V6_SER.png`
- `B_CASE_ANCHOR_AWGN_V6_BER.png`
- `B_CASE_ANCHOR_AWGN_V6_SUMMARY.csv`
- `B_CASE_ANCHOR_AWGN_V6_ORDERING.csv`
