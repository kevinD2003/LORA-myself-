# Stage 07 Experiment B v30 validation audit

Overall status: `PASS`.

Both comparison modes completed exactly 20 independent AWGN passes at -21 dB. Each mode used a separate keyed phase, unique pass signatures and unique ledgers. No v28 or failed exploratory sample was merged.

| Mode | Stage55 SER | Paper SER | Stage55 hard BER | Paper hard BER | Stage55 ML BER | Paper ML BER |
|---|---:|---:|---:|---:|---:|---:|
| controlled-time | 0.002439 | 0.017846 | 0.0000643 | 0.0002318 | 0.0000730 | 0.0003628 |
| native-overhead | 0.000955 | 0.017509 | 0.0000289 | 0.0002572 | 0.0000295 | 0.0004184 |

Controlled VP false acceptance low/high was 0.0956%/0.3775% with coverage 14.71%/13.09%. Native was 0.00836%/0.0842% with coverage 15.03%/14.33%. All quality gates passed.

Native natural-time denominators are intentionally different. Across 20 passes, Stage55/Huang sent 2540 frames and had 2160 fully visible frames; Paper sent 1940 and had 1640 fully visible frames. Mean Stage55/Paper goodput was 164.823/115.929 bit/s. System ML PER including geometry erasures was 0.15591/0.22268. Raw samples are not claimed paired across native method timelines.

- Controlled validation hash: `f648034b6e41580116c1aae7230c8b6ae0e4c39304e81868c402aad6efbe3762`.
- Native validation hash: `dec3840283073e2f0fcfd998f9e222fcf12598c8731b98297e04ceae5699f047`.
- Fixed conditions, Paper/Huang hashes, and read-only source boundary remain unchanged.

Admission: `PASS` to four independent smoke groups and the resource gate. Formal remains prohibited until smoke, checkpoint/signature and resource audits pass.
