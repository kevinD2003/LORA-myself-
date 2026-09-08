# Stage 53 abandoned checkpoint

Status: **excluded from every formal statistic**.

This directory contains one recomputed `-21 dB` pass that accidentally used
the same default payload/noise seed policy as the earlier Stage 52 one-pass
wiring inspection (`PayloadSeedBase=2026120800`,
`NoiseSeedBase=2026120900`). No receiver threshold, SNR, or algorithm was
changed after inspecting that wiring sample, but reusing it would weaken the
audit separation between diagnostic and formal data.

The checkpoint and outputs are retained unchanged as provenance. Formal
Stage 53 restarts from pass 1 in a new directory with the independently
registered seed bases in `run_stage53_formal_repeated_passes.m`. Nothing in
this archived directory may be merged into the formal result.
