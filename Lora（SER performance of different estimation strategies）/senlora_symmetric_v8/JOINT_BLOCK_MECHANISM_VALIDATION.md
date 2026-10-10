# V8 joint block CFO/Hamming ML mechanism validation

Status: **MECHANISM PASSED; REVIEW NOT STARTED**

The validation reused the original 9 physical mirror pairs, 20 paired packets
per position, payload/noise seeds, native 8-preamble-plus-payload frame, SNR,
and provisional d0/d1 values. No Review or Formal seed was used.

For each current 7-symbol Hamming block, the second pass evaluates the frozen
residual CFO grid inside the existing innovation limit. It jointly scores the
residual CFO and legal Hamming codewords, retains one result, and uses that
result for the current block. A block updates the causal rolling correction
state for later blocks only after hard/soft agreement, codeword margin,
decision peak ratio, and CFO-search peak ratio pass. No hypothesis survives
the block boundary.

## Overall raw errors

| Receiver | Raw errors | SER |
|---|---:|---:|
| Joint-block V8 | 5 / 40320 | 0.000124008 |
| Original V8 | 604 / 40320 | 0.0149802 |
| Same-frame V6-native | 6 / 40320 | 0.000148810 |
| Offline Ideal | 4 / 40320 | 0.0000992063 |

The maximum joint-block error count in any packet was one symbol. Five
different packets contributed one error each. There were no receiver
failures and all truth/orbit/case/SNR/target/midamble use flags were false.

## Position checks

Five of the 18 measured points had one error in 2240 symbols
(SER 0.000446429); all other points had zero errors. Case1 and Case2 physical
mirror pairs both had zero joint-block errors. Mirror differences were at
most one raw symbol in this 20-packet mechanism sample. The maximum selected
block residual was 0.25 bin, the maximum packet CFO RMSE was 0.0487 bin, and
each packet admitted at least 12 of 16 blocks.

The original 6%--8% spikes are absent. At 20 packets per side, isolated
zero-versus-one-count changes are the resolution of the raw measurement and
are not evidence of a trajectory discontinuity. Independent Review seeds are
still required before freezing the receiver or d0/d1.

## Verification

- Checkpoint and final MAT arrays are identical.
- The result contains 360 packet rows and 18 raw position rows.
- The standalone block decoder matches `v4DecodePayload` hard symbols, hard
  Hamming bits, soft Hamming bits, and reencoded symbols on identical samples.
- Source static checks passed for the block decoder, joint receiver, and
  mechanism runner.
