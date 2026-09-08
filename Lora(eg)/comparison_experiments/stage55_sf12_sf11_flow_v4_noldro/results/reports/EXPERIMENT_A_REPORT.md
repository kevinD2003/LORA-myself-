# Experiment A formal report - R5

Plan: `V4-noLDRO-plan-R5-track-a-point-anchored-lock`.

Algorithm signature: `e9f0b53e2bb9d1a9497338201d96713827945a0c81927424236b3b8b4dbedb4b`.

Fixed sample size: 20000 paired packets per Case/SNR, 400000 total. SNR=-30:-21 dB. CI uses 10000 paired-packet bootstrap draws.

Track A reports SER and CFO/VP/runtime diagnostics only; no CR1 BER, PER, or information-bit goodput is produced.

Precision-inconclusive points: 0. CI crossing zero, adverse performance, and realtime deadline misses are retained rather than treated as code failures.

Data: `EXPERIMENT_A_SUMMARY.csv`, `EXPERIMENT_A_PAIRED_CI.csv`, `EXPERIMENT_A_PER_SYMBOL_CFO.csv`, `EXPERIMENT_A_SER.png`.
