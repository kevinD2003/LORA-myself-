# B Case-anchor AWGN V2 report

Status: **FAIL**

- Algorithm: `Stage55-B-case-anchor-joint-preamble-v5`
- Fixed sample: 200 paired packets per Case/SNR.
- SNR: -30:-21 dB; AWGN; CR3; 112 symbols; 768 information bits.
- Case 1 rule: Stage <= Huang and Stage < Paper; when Paper has zero errors, Stage must also be zero.
- Case 2 rule: Stage < Huang and Stage < Paper at every SNR for SER, hard BER and ML BER.
- Case 1 pass: 0. Case 2 pass: 1. Regime gate pass: 0.
- Zero plot convention: 0.5/N for log display only; CSV/JSON preserve raw zero.
- Selection uses payload/orbit truth: false.

Artifacts:

- `B_CASE_ANCHOR_AWGN_V2_SER.png`
- `B_CASE_ANCHOR_AWGN_V2_BER.png`
- `B_CASE_ANCHOR_AWGN_V2_SUMMARY.csv`
- `B_CASE_ANCHOR_AWGN_V2_ORDERING.csv`
