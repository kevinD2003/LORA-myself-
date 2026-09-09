# R11 Stage55 low-SNR consensus-rate revision

Algorithm `Stage55-A-consensus-rate-hybrid-v8` preserves all conditions and R10 evidence. High-shift packets retain the R8 static branch. Low-shift packets replace the median-only eight-upchirp rate fit with an exhaustive 28-pair receiver-visible consensus fit, weighted by peak quality, followed by bounded robust regression. No truth, Case identifier, Paper sample, Midamble, or future data is used. Development grid root: 920000000.
