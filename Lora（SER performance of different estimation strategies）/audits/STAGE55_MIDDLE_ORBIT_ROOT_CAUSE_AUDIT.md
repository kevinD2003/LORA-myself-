# Stage55 middle-orbit root-cause audit

Status: **ROOT CAUSE CONFIRMED / RATE-AWARE V3 NOT ADMITTED**  
Date: 2026-09-22

## Requested questions

1. Is middle-orbit degradation caused by too few virtual pilots?
2. Is wrong VP feedback shifting the compensation state?
3. Should dynamic VP always participate under large CFO instead of using the
   static path?
4. Can the receiver be guaranteed below Paper while preserving the complete
   Case1/Case2 SER curves?

## Finding 1: the original middle-orbit failure begins at the mode gate

In the frozen Formal scan, Stage55 accepted zero payload VPs at `-274.5`,
`-183`, and `-91.5 s`. The receiver selected the Huang-equivalent static path
because the starting CFO remained inside the large-CFO domain. Stage55 and
Huang were exactly packet-identical at these anchors.

Therefore the original middle-orbit degradation was not initially caused by
false VP feedback: no VP feedback occurred. It was caused by estimate aging
while the receiver stayed static as frame drift grew from approximately 0.61 to
12.68 bins.

## Finding 2: after dynamic activation, VP scarcity and false VP matter mainly at low SNR

Forced-dynamic paired results used the same first 100 Formal packet identities:

| t0 | SNR | Paper SER | Forced VP-on | VP-off | accepted VP/packet | false VP rate |
|---:|---:|---:|---:|---:|---:|---:|
| -274.5 s | -24 dB | 0.19866 | 0.23036 | 0.25054 | 3.23 | 2.17% |
| -274.5 s | -21.12 dB | 0.00223 | 0.01268 | 0.10696 | 14.98 | 0.13% |
| -183 s | -24 dB | 0.36018 | 0.23277 | 0.25973 | 3.69 | 2.98% |
| -183 s | -21.12 dB | 0.08232 | 0.02170 | 0.09214 | 14.96 | 0% |
| -91.5 s | -24 dB | 0.43473 | 0.34491 | 0.36366 | 3.14 | 1.91% |
| -91.5 s | -21.12 dB | 0.15580 | 0.05875 | 0.17750 | 13.12 | 0% |

Paper has 37 known explicit midambles per packet. At -24 dB Stage55 obtains
only about three accepted VPs per packet and 2-3% of those are wrong. This
limited observation density and error feedback contribute to the remaining
gap. At -21.12 dB, false VP is nearly absent and VP-on strongly improves over
VP-off, so VP feedback is beneficial rather than the main error source.

At `-274.5 s`, even forced dynamic remains worse than Paper at both SNRs. A gate
change alone therefore cannot guarantee Stage55 below Paper everywhere.

## Finding 3: large CFO alone must not force the dynamic path

Case1 has large CFO but almost zero physical rate. A 100-packet/SNR audit over
the complete `-30:-21 dB` grid found that always forcing the dynamic path was
worse than frozen static Stage55 at every SNR.

Examples:

| SNR | Frozen Case1 SER | Forced dynamic SER | VP/packet |
|---:|---:|---:|---:|
| -30 dB | 0.87661 | 0.94205 | 0.00 |
| -28 dB | 0.67589 | 0.84054 | 0.00 |
| -26 dB | 0.33679 | 0.55312 | 0.34 |
| -24 dB | 0.06268 | 0.26286 | 3.06 |
| -22 dB | 0.00116 | 0.04830 | 11.56 |
| -21 dB | 0.00027 | 0.02830 | 15.13 |

At -21 dB, forced-dynamic VP-off SER was 0.10652 and VP-on reduced it to
0.02830; CFO RMSE fell from 8.78 to 4.71 Hz. VP was repairing the noisy-rate
path, not causing its primary degradation, but could not recover the static
receiver's 0.00027 SER.

Conclusion: dynamic VP should participate when receiver-observable frame drift
is reliably nonzero, not merely because absolute CFO is large.

## Finding 4: point-estimate rate gating is not sufficient for complete Case1 preservation

Rate-aware v3 used a 2-bin predicted-drift gate. At the two registered orbit
SNRs it preserved `-366`, `-274.5`, and `0 s`, and improved `-183` and
`-91.5 s`. However, a full-SNR Case1 gate audit found 14%, 8%, and 6% false
dynamic selection at -30, -29, and -28 dB.

Direct candidate decoding confirmed Case1 degradation:

| SNR | Frozen SER | v3 SER | change |
|---:|---:|---:|---:|
| -30 dB | 0.87366 | 0.88777 | +0.01411 |
| -29 dB | 0.79312 | 0.80643 | +0.01330 |
| -28 dB | 0.67223 | 0.68795 | +0.01571 |

Rate-aware v3 therefore fails the requested full Case1 non-degradation gate and
must not be promoted as the final algorithm.

Case2 remained dynamic in 100% of gate-audit packets across `-30:-21 dB`, so
the Case2 branch itself is preserved.

## Required next design

A successor needs uncertainty-aware or multi-hypothesis logic, not another
single threshold on `abs(rateHat)`:

1. Preserve a static hypothesis and a dynamic hypothesis in parallel.
2. Activate dynamic feedback only when rate evidence is significant relative
   to its uncertainty or is consistent across independent preamble partitions.
3. Monitor every symbol, but update only with reliable observations.
4. Bound innovation and update gain; retain a rollback/static fallback when
   receiver-observable likelihood worsens.
5. Increase reliable VP availability using decoded/re-encoded block consensus,
   not by simply lowering confidence thresholds.
6. Never select a hypothesis using orbit time, true residual, packet errors, or
   comparison with Paper.

## Admission gates for any successor

- Full Case1 `-30:-21 dB`: paired non-degradation against the frozen curve.
- Full Case2 `-30:-21 dB`: paired non-degradation against the frozen curve.
- Five orbit anchors at both registered SNRs: report paired Stage55-minus-Paper
  intervals; promotion requires the predeclared comparison gate to pass rather
  than tuning until a desired ordering appears.
- Per-symbol residual CFO, predicted rate, innovation, VP count, false VP,
  confidence, and rollback events must be saved.
- Calibration and confirmation seeds must remain disjoint.

Being below Paper at every tested point can be an admission requirement, but it
cannot be guaranteed by implementation alone. Paper has 37 known observations;
if a receiver-only candidate fails the independent paired gate, it must be
reported as not admitted rather than adjusted using the same test outcomes.

