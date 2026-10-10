# Local Paper project applicability audit

> 目录整理（2026-10-08）：[所属项目入口](../../README.md)。本文的 MATLAB 命令和反引号内的代码、数据及文档路径以该项目根目录为基准；历史数值和验收结论保留其原记录时间。

Status: **PARTIAL_ONLY - DO NOT COPY DIRECTLY**

The running R3 formal grid was stopped and all checkpoints were preserved before
this audit. Stage55, Huang, Ideal, physical conditions and completed results were
not modified.

## Matching items

- SF = 12, bandwidth = sample rate = 125 kHz, carrier = 868 MHz.
- Orbit altitude 550 km and Case1/Case2 start times -366 s / 0 s.
- Midamble interval `n_int = 3`.
- Causal cumulative Point update from known Midamble observations.
- No payload truth or orbit truth is used by the Paper receiver.

## Non-matching items

| Item | Local paper-condition project | Current project |
|---|---:|---:|
| LDRO | enabled | disabled |
| Effective bits/symbol | 10 | 12 |
| Legal data-bin spacing | 4 FFT bins | 1 FFT bin |
| Coding rate setting | CR1 | CR3 |
| Payload | 120 bits / 23 symbols | 768 bits / 112 symbols |
| Tracking Midambles | 7 | 37 |
| Channel | packet-flat Rician K=10 dB | AWGN |

The Point estimator and update rule are portable, but the full receiver and its
numeric curve are not directly portable. In particular, the same approximately
one-bin inter-Midamble drift is tolerated by LDRO's four-bin legal-symbol spacing
but causes direct symbol shifts under the current one-bin no-LDRO alphabet.

## Existing local evidence

The paper-condition project reports Case2 Paper SER from 0.9826 at -30 dB to
0.1099 at -21 dB. This is a useful adapted reference and remains above the
current Stage55 validation SER at the shared high-SNR points.

The current repository also contains a no-LDRO trend-aided Paper implementation
(`v4PaperMidamblePointTrendDecodeV3`) whose 200-packet curve reaches 0.0388 at
-21 dB and 0.0822 at -22 dB. It matches the Figure 11 shape, but it is better
than the frozen Stage55 validation values 0.0799 and 0.1200 at those points.
Promoting it unchanged would therefore violate the required Case2 ordering.

## Decision

1. Do not copy the LDRO/CR1/23-symbol project as the current Paper receiver.
2. Do not promote the existing trend-aided V3 unchanged.
3. A unified observable adapter is structurally possible: retain the legacy
   Point path for receiver-observable low-rate frames (Case1 behavior unchanged)
   and use a causal rate-aware Point adapter for high-rate frames.
4. It is not scientifically valid to tune or deliberately degrade that adapter
   using SER so that it falls between Stage55 and a target curve. Candidate
   selection must use receiver-only CFO/rate quality metrics; the subsequent
   1000-packet SER/Hard-BER grid is an independent gate.
5. Under the frozen Stage55, matching the raw Figure 11 blue curve at -22/-21 dB
   and simultaneously requiring Stage55 to be strictly better is infeasible with
   the measured validation values. The reproducible local paper-condition curve,
   rather than the visually estimated raw blue curve, is the feasible reference.

## Frozen source evidence

- Paper-condition config SHA-256:
  `cf240837cad765ec894d7f820acfcba5d5d8ff95da92f44b0d65a6b4ae9dacf8`
- Paper-condition native decoder SHA-256:
  `c81be8544f1bf5eb451bc58222247dea3ab74529a822946a34c30cba22b8563a`
- Current unified Paper V4 SHA-256:
  `f98194a38265a1c085e69695d9b4d4a3d8d9a4c270d0d6433b8727d51e950ee2`
- Existing trend adapter SHA-256:
  `2ba6e5991642eba5c102497316232562fd3b87838f65d11325ef341de5deb654`
