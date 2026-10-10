# Reference PHY check

The paper cites Tapparel et al.'s open-source LoRa PHY (reference [13]).
The pre-publication hard-decoder source inspected is gr-lora_sdr commit
31243b0ac9cc8255f860dc85fc9594734856e03e (2022-08-12):
https://github.com/tapparelj/gr-lora_sdr/blob/31243b0ac9cc8255f860dc85fc9594734856e03e/lib/hamming_dec_impl.cc

Its hard CR1 decoder retains systematic data bits. Its CR4 decoder uses
syndrome correction only for odd overall parity; detected even-error cases
retain received systematic bits. The current frozen PHY instead uses hard
nearest-codeword lookup with the lowest-word tie break. Both policies were
evaluated on the same eight complete -10 dB overpasses, identical IQ and
identical fixed/adaptive LR symbol decisions. Only post-detection Hamming/CRC
processing differed. Counts are saved in hamming_policy_same_iq.csv:
policy 1=current nearest-codeword, policy 2=detect-only CR1/SECDED CR4;
method 1=adaptive, method 2=fixed.

Fixed CR4 PLR changes from 34.8926% to 32.6687%, versus published 0%.
Adaptive CR4 is unchanged (PLR 1.3804%, CRC-success BER 0.003915%).
CR1 adaptive PLR changes from 1.8305% to 1.7259%; fixed changes from
28.6611% to 27.77197%. These differences do not explain the main numerical
gap, so no post-hoc decoder selection was made for the formal experiment.

The reference also protects its first interleaved block at CR4 and reduced
SF, supports LDRO, and includes protocol header/Gray-offset conventions.
The paper's precise configuration of these options is absent. The six-block
32-byte simulation is an explicit packed-PHY assumption, not proof of the
author's complete on-air frame layout. This uncertainty accompanies the
formal results. The reference implementation's hard and soft modes must not
be inferred solely from closeness to a target.
