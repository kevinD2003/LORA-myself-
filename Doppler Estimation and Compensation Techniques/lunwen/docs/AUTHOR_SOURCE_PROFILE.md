# Public author-source figure profile

The downloaded arXiv source is preserved under
tmp/references/paper_arxiv_source. It predates the final journal text.

Relevant source facts:

- main.tex line 500 describes an AWGN and Doppler channel, without Rician.
- main.tex line 530 sets Midamble-Point n_int=12 for SF7 and n_int=1 for SF12.
- The source EPS files were generated with MATLAB R2024a in May 2025.
- The source SF12 EPS SNR axis ends at -22 dB, while the final journal figure
  contains a revised range and text.

Therefore this profile is a separately named historical figure-source
experiment. It does not replace the final-paper configuration and is not
selected by fitting. Its output files use the suffix author_source.

## Completed Monte Carlo result

All four source-profile sweeps completed with the same stopping rule as the
main experiment: at least 5,000 packets and 1,500 symbol errors, or the
50,000-packet cap. At the highest plotted SNR, the three delivered strategies
give:

| SF | Case | SNR dB | No Doppler | Point | Midamble-Point |
|---:|---:|---:|---:|---:|---:|
| 7 | 1 | -6 | 0.00000485 | 0.004244 | 0.004673 |
| 7 | 2 | -6 | 0.00000727 | 0.00000485 | 0.00002242 |
| 12 | 1 | -21 | 0.00010696 | 0.001490 | 0.001510 |
| 12 | 2 | -21 | 0.00011739 | 0.790520 | 0.014731 |

The very low AWGN-only endpoints hit the 50,000-packet cap, so their raw error
counts and Wilson intervals in the CSV files are authoritative.

These results explain parts of the revision history but do not reproduce the
final Rician curves: for example, the source-profile SF=12 Case 2
Midamble-Point endpoint is 0.014731, while the final figure is visually around
0.05. The source profile is therefore marked `finalPaperProfile=false` in
`results/author_source_audit.json`.

## Complex-AWGN correction

The no-Doppler template was initially stored as a real all-ones vector. MATLAB
then generated real rather than circular complex noise for only that path.
`applyUnitPowerAwgn` now converts every input to complex storage before calling
`awgn`, and the four AWGN-only baseline curves above were recomputed. Point and
Midamble-Point signals were already complex because Doppler supplies a complex
phase. Reference [12]'s I/Q receiver and ideal-filter operating points support
the corrected complex-baseband convention; the old real-noise values are not
retained to make a plot look closer.
