# 2026-10-09 continuation

User request: continue modifying the pure-paper reproduction.
All implementation changes are isolated to this new reference_phy_v6 folder.
The v5 6,030,000-packet experiment is preserved and remains independently valid.

Confirmed reference differences corrected: whitening polynomial/byte ordering
and coverage, LoRa CRC definition, nibble/Hamming bit order, first-block coding,
LDRO/reduced-rate parity, interleaving, Gray offset, header/checksum, codeword
padding and physical sync/SFD timing. Core ordinary LR is not augmented.

Validation attempted: first test run passed eight tests, with one provenance
file missing; after adding the manifest all nine pass. 192-packet sampled
smoke run and two 2,320-packet complete eight-pass trajectories completed.
The complete trajectories still show substantial published BER/PLR gaps.
No cache signature migration or post-hoc target fitting was performed.

An automatic independent read-only code audit is a completion gate for this
new code. Its final status and any confirmed defects must be recorded before
claiming implementation completion. Numerical source-author identity is not claimed.

First independent audit: FAIL, one confirmed medium-severity finding.
audit_reference_phy_v6 accepted an empty result list and could report a
validation status without checking any result counts/signatures. Fixed by
requiring a nonempty result list before testing/writing the audit artifact.
Added testAuditRequiresAResultDirectory; all ten tests pass. To respect exact
signatures, reran both complete eight-pass ensembles into new hash-suffixed
directories rather than updating old cache signatures. Metrics reproduced
exactly. Focused read-only re-audit is required before claiming completion.

Focused re-audit: FAIL, with only a low-severity documentation finding: the
README validation section still said nine tests after the tenth was added.
Corrected the count and coverage description. The focused reviewer verified
empty-path rejection, both current result signatures, all counters/pass
totals, CSV tolerances, unchanged scalar metrics and the frozen v5 signature.
This documentation-only repair changes no calculation or result signature.
Final focused read-only re-audit: PASS; no actionable findings. The reviewer
confirmed the ten-test count, empty-path regression description and explicit
separation of eight-pass validation from formal/numerical reproduction.
Tests were not rerun by this final documentation reviewer. Together with the
preceding result/signature checks, this closes the two confirmed findings;
it does not establish published numerical agreement or author-frame identity.

User acceptance update: absolute difference <=5 percentage points, each
published SER/BER/PLR entry separately. No calculation source changed.
Completed the frozen product-phase eight-pass full SNR grid: 11,600 packets,
ten tests passed, 20 result rows and exact signature/count/MAT-CSV checks.
Latest internal audit verifies the unchanged v5 baseline. Of 40 BER/PLR
entries 26 meet the tolerance and 14 do not, including two Adaptive PLR
entries. This is validation, not a new formal 3000-pass run. The main phase
and BER denominator were not selected/altered to approach target values.
Details and outstanding numerical gaps are recorded in ../ACCEPTANCE_5PP.md.
