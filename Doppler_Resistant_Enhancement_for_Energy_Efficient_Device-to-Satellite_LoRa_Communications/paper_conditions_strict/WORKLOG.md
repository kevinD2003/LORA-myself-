# Continuation record (2026-10-08)

The requested outcome is the pure-paper condition audit and a complete
3000-overpass full-PHY ensemble. README.md and results/audit.json were read
first. The numerical differences have been quantified, not force-fitted.

Active calculation sources/results are version 5. Nine focused tests pass;
native sample-level IQ/centroids/LR and the vectorized PHY match the reference.
The native FFTW library stays process-pinned; three independent exit tests
passed after fixing the library teardown race. All calculation files are
frozen while the formal experiment runs. Do not edit them or migrate caches.

Completed diagnostics: table_iv_v5_O1, table_iv_v5_O32, both eight-pass PHY
validation ensembles, numerical_gap_audit (Monte Carlo, CRC and phase/sign).
The current audit was run with RequireFormal=false; formal completion is
still false. Adaptive -20 dB ensemble SER is 9.74% vs published 13.44%.
Paper-unpublished details and CRC/BER ambiguities remain explicit.

Formal output directory:
results/full_phy_v5_O3000_Pall_S0_-5_-10_-15_-20.
Runtime workers invoke invoke_strict_batches.ps1 with disjoint ConditionIndices
and MaximumBatches=500. Conditions [1,6], [2,7], [3,8] are running; [4,9]
and [5,10] were stopped with checkpoints intact to restore RAM from ~1 GB to
~4 GB. They now have queued controllers: [4,9] waits for [1,6], and [5,10]
waits for [2,7]. A finalization controller waits for all ten cell files, then
aggregates, builds the uncertainty report and runs the required formal audit.
Worker [2,7] was restarted with MaximumBatches=100 after three consecutive
heap errors; its checkpoint and noise protocol are unchanged. Do not stop or
delete unrelated processes/files. Each cell has progress.json and checkpoint.mat;
execution_logs contains worker statuses and attempts.
Worker [3,8] also reached three consecutive heap errors on 2026-10-09
at about 00:07 Asia/Shanghai and was restarted with MaximumBatches=100.
The batch size remains 32; the existing exact signatures/checkpoints are reused.
At 00:42 Asia/Shanghai the two waiting pair controllers were verified to
have no MATLAB children and stopped. Their queued work is now split into
four disjoint controllers: [4] waits for [1,6], [9] waits for [3,8], [5]
waits for [2,7], and [10] waits for [4]. This keeps at most three calculation
workers active while allowing independent CR1/CR4 cells to run in parallel.
The CR1 queues use 500 batches/call; CR4 queues use 100. No calculation,
batch-size, seed, configuration or signature changed, and no files were deleted.

Remaining work: finish all ten formal cells, run the default runner to
aggregate, generate formal uncertainty/comparison reports, visually inspect
figures, run audit_strict_paper_reproduction with its default formal gate,
One read-only code_auditor (/root/strict_paper_code_audit) has now audited the
implementation: INCONCLUSIVE, no actionable code findings, because the formal
ensemble is still running and numerical differences remain unresolved.
Do not report PASS or numerical identity from that report. No confirmed FAIL
repair is pending; do not spawn extra auditors without a new code-change task.
The formal aggregation/audit still must finish before declaring the experiment
complete. Targeted GitHub/Zenodo/Crossref/IEEE metadata searches found no
author code or supplement in the searched sources.

Latest observed progress: 4,735,024 / 6,030,000 packets at 2026-10-09 05:24
Asia/Shanghai. CR1 at 0, -5 and -10 dB are complete (717,000 packets each),
and CR4 at 0, -5 and -10 dB are complete (489,000 packets each). Six of ten
formal cells are complete. Worker [1,6] session 42698
completed normally after 78 attempts. Active sessions: [9]=45488 (100
batches/call), [4]=30855 and [5]=73235 (500 batches/call). Worker [2,7]
session 28258 has completed its target cells and [5] has started. Worker [3,8]
session 30835 has completed its target cells; old session 48966 has exited.
Queued [10]=68201. Old queued sessions 62914/90513 have exited;
finalization controller=62604. Progress monitor session=77074 (90 snapshots,
50-second intervals, seven current controller tags, and actual command-line
identity checks for launcher liveness); old monitors 77976/71926/91330/14777
completed normally. CR1 -15 dB has 603,512/717,000 packets; CR1 -20 dB has
267,448/717,000; CR4 -15 dB has 246,064/489,000. CR4 -20 dB is still queued.
File progress is authoritative.
The original parent reproduction and V4 project sources were not modified.

Read-only continuation check on 2026-10-09: PDF pages 3-5 were visually
reviewed again for the phase/time-origin question. README now states that
the frozen product phase uses orbit time centered at closest approach and
has instantaneous frequency f_D+t*f_D'. This documentation does not change
the calculation identity. Neither the printed product nor the existing
integrated-phase sensitivity matches all published targets. No calculation
source was changed during this continuation.
The transmit inverse-Gray / receive Gray direction was also inspected;
an independent exhaustive SF12 integer check found a one-bit Gray-label
distance for all 4096 cyclic adjacent bins. No reversed mapping was found.
README additionally records the existing CRC/data-padding/whitening order;
this is clarification of the frozen packed-PHY assumption, not a code repair
or proof of the author's frame format.

At 10:01 Asia/Shanghai, old tool sessions were no longer available and a
system-process check found no task MATLAB/controllers running. Nine cells
were complete, with 6,005,368/6,030,000 packets; only CR4 -20 dB remained
at 464,368/489,000. Its last checkpoint was 08:27 and last error log empty,
so the reason for interruption is not established. Only condition [10] was
resumed with 100 batches/call, session 30495; finalization was restarted as
session 34578. Previous session IDs are historical, not live connections.
Calculation sources/configuration are unchanged; no cache migration was done.

Final completion: 2026-10-09 10:10 Asia/Shanghai. The resumed condition [10]
finished after eight successful bounded calls. Worker 30495 and finalization
34578 both exited with code 0. All ten formal cells and 6,030,000 received
packets are complete. The default runner aggregated the full ensemble,
build_strict_formal_report generated 2000-draw independent-overpass-bootstrap comparison files,
and the default required audit passed nine tests plus all signature/count/CSV
checks. audit.json now says FORMAL_COMPLETE_WITH_NUMERICAL_GAPS and
numericalAgreementClaimed=false. Formal plots 3/4 were visually inspected.

FINAL_RESULTS.md records the finished results and unresolved publication gaps.
Fixed CR4 at -10 dB: CRC-success coded BER 0.092520%, PLR 34.346421%, and
all-packet coded BER 3.477140%, versus published BER 3.47% and PLR 0%.
The independent read-only code audit remains INCONCLUSIVE, with no actionable
findings; formal completion does not retroactively convert it to PASS or
establish numerical/author-source identity. No further code source changed.
The task's formal-experiment part is complete; numerical-gap resolution is
still not established, and the original project comparison was not changed.
