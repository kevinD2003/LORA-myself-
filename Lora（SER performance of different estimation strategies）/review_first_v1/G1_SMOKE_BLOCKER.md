# EXP3 G1 smoke blocker

Status: **BLOCKED_AT_G1**  
Date: 2026-09-22  
Formal started: **NO**  
G2 review validation started: **NO**

## Completed smoke

Six cells completed: Case1/Case2 at `[-30, -24, -21] dB`, five packets per
cell. Receiver failures were zero, fingerprints were paired, checkpoints and
112-symbol monitors were complete.

| Case | SNR | Current Stage55 SER | Review candidate SER | Paper SER | Dynamic selected | rollback |
|---|---:|---:|---:|---:|---:|---:|
| Case1 | -30 | 0.8768 | 0.8768 | 0.9946 | 0% | 0 |
| Case1 | -24 | 0.0839 | 0.0839 | 0.2554 | 0% | 0 |
| Case1 | -21 | 0.0000 | 0.0000 | 0.0018 | 0% | 0 |
| Case2 | -30 | 0.9536 | 1.0000 | 0.9982 | 0% | 0 |
| Case2 | -24 | 0.2214 | 0.7268 | 0.5196 | 32.9% | 0 |
| Case2 | -21 | 0.0000 | 0.1714 | 0.0339 | 82.9% | 0 |

## Root cause

The strict promotion rule requires all registered evidence: split-preamble
rate consistency, a nonzero rate lower confidence bound, remaining predicted
drift, causal previous-block coded likelihood gain, and at least two consistent
accepted VP innovations.

This protects Case1, but Case2 must initially stay Static while waiting for
payload VP and completed-code-block evidence. The early Static-compensated
symbols are then mixed with later Dynamic-compensated symbols. Those early
errors are sufficient to corrupt code blocks and produce severe SER loss even
when most later symbols select Dynamic.

At -30 dB no reliable VP is accepted, so all required evidence can never be
present and the candidate remains Static. This directly conflicts with the G1
requirement that Case2 default to Dynamic.

## Decision

The candidate fails both G1 Case2 branch activation and Case2 non-degradation.
According to `REVIEW_FIRST_VALIDATION_PLAN.md`, execution stops here. G2 and
Formal are forbidden.

No threshold is relaxed and no same-seed rerun is used to make the candidate
pass. A successor needs a structural decision, such as receiver-buffered
packet-level hypothesis selection/replay after evidence becomes available, or
an independently calibrated preamble-only uncertainty test that is strong
enough to choose Dynamic before payload decoding. Either approach requires a
new candidate identity and a new smoke seed domain.

