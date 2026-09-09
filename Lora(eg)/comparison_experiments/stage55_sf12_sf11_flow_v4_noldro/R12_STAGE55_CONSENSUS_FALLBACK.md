# R12 Stage55 consensus-support fallback

Algorithm `Stage55-A-consensus-support-fallback-v9` preserves all conditions and prior evidence. High-shift uses R8 static. Low-shift uses the R11 consensus rate only when at least four of eight known upchirps support its 0.6-bin consensus; otherwise it falls back to the R10 median-pairwise rate. Four is the fixed majority-support requirement, not fitted to SNR or Case. Development root: 950000000.
