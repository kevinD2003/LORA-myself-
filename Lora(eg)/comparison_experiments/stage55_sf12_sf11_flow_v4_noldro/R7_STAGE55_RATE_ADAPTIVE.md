# R7 Stage55 receiver-only rate-adaptive revision

Algorithm: `Stage55-A-rate-adaptive-subbin-v4`. All experiment conditions and Paper code remain frozen. The receiver uses the two existing complete downchirps to estimate initial CFO/rate. With receiver-visible `abs(rate)<3 bin/s`, it uses a static sub-bin CFO branch and does not admit payload VPs; otherwise it uses the R6 causal dynamic VP branch. The threshold is frozen before new evaluation and is common to both Cases. New validation root is 850000000. R6 results remain adverse evidence and are not overwritten.
