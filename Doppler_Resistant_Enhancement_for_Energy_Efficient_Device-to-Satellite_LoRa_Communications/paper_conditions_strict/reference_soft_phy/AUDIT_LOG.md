# Independent code audit gate

Initial audit: FAIL, one confirmed high-severity finding. FFT energies must
be multiplied by N after raw Ps/Pn estimation and before Bessel arguments,
clipping decisions and clipped-energy fallback. The implementation and its
Python oracle had both omitted the same pinned reference step.

Source: gr-lora_sdr commit 31243b0ac9cc8255f860dc85fc9594734856e03e,
lib/fft_demod_impl.cc lines 187-209. The main agent confirmed the complete
source block before repairing the code, not just the prior excerpt.

Repair is confined to referenceSoftLlr.m, the literal oracle/fixtures and
a closed-form two-branch regression in testReferenceSoftPhy.m. Manifest and
documentation record the scaling. Window/ML/LR/CRC/phase choices are unchanged.
The regression uses known arguments sqrt(35), sqrt(7), and a spectrum whose
713 clipping boundary is crossed only when multiplying energy by N.

Earlier soft numerical results and the earlier plot are superseded. Fresh
source-bound runs must be generated; no cache-signature migration is allowed.
Focused independent re-audit: PASS; no actionable findings. The reviewer
confirmed raw Ps/Pn before N scaling, correct Bessel/clipping/fallback order,
literal oracle/fixtures and the independent closed-form regression. Tests
were not rerun independently. At the time of that report the fresh full runs
were still running; the primary process subsequently verified both complete
current-source results with audit_reference_soft_phy (14 tests, 40 rows).

Corrected current results: paired_soft_825c3db77dfc (rectangular) and
paired_soft_9e64048d168e (Hann), 11,600 same-corpus packets each. Their full
position/pass hard counters, paired outcomes, source/input/target signatures
and numerical-scope flags pass. All pre-normalization results remain invalid
historical evidence and their signatures were not migrated.
