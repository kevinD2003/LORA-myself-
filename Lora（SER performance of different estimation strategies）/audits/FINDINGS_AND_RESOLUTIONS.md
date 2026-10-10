# Findings and resolutions

| ID | Severity | Finding | Resolution | Status |
|---|---|---|---|---|
| G0-N1 | Note | Parent endpoint archive uses -21 dB, not -21.12 dB. | Smoke reproduces -21 dB; Formal treats -21.12 dB as a selected anchor only. | Resolved in design |
| G0-N2 | Note | Repository contains unrelated pre-existing deletions. | New sibling project; read-only parent reference; runtime SHA-256 gate. | Resolved in design |
| A1-M1 | Medium | Initial parent manifest omitted the locally patched `v4RollingTrackerPass.m` and did not prove a complete dependency freeze. | Rebuilt the manifest from MATLAB's transitive dependency closure, added all dynamic inputs and smoke references, and made runtime validation reject any unlocked dependency. | Resolved; pending re-audit |
| G1-N1 | Note | Pilot Stage55 is identical to Huang at the first four anchors and only activates payload VP at 0 s. | Preserve the frozen observable selector and report the applicability boundary; do not tune by orbit position. | Accepted scientific outcome |
| G1-N2 | Note | Paper CFO residuals contain large outliers despite moderate aggregate SER. | Confirmed against the receiver's actual `estimatedCfoBins`; retain both residual and SER diagnostics. | Accepted diagnostic outcome |
| G1-M1 | Medium | Initial plotting joined distinct SNR series in Formal DeltaSER and frame-diagnostic figures. | Group plot series by both method/baseline and SNR; hide the zero reference line from the legend. | Resolved; code audit PASS |
| G2-N1 | Note | Stage55 uses the Huang-equivalent static path at the first four anchors; VP activation occurs only at 0 s. | Report the measured applicability boundary and avoid monotonic-gain claims. | Accepted scientific outcome |
| G2-N2 | Note | At 0 s/-24 dB, VP-on improves paired SER but aggregate CFO RMSE changes only marginally. | Base the lower-SNR mechanism statement on paired SER and within-frame diagnostics; do not overstate aggregate CFO improvement. | Accepted conclusion boundary |
| G2-E1 | Engineering | Windows intermittently blocked checkpoint replacement during ablation. | Retained old checkpoint, promoted the fully written temporary MAT, resumed with identical signature, and verified final Formal/ablation arrays exactly. | Resolved with preserved evidence |
