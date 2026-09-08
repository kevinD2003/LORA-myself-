function llr = binLogProbToLlr(logProb, grayBits)
%BINLOGPROBTOLLR Compute bit LLRs from FFT-bin log probabilities.

arguments
    logProb (1,:) double
    grayBits (:,:) logical
end

numBins = numel(logProb);
if size(grayBits, 1) ~= numBins
    error("SenLoRa:GraySizeMismatch", ...
        "grayBits must have one row per FFT bin.");
end

sf = size(grayBits, 2);
llr = zeros(1, sf);

for bitIdx = 1:sf
    oneMask = grayBits(:, bitIdx).';
    zeroMask = ~oneMask;
    llr(bitIdx) = logSumExp(logProb(oneMask)) - logSumExp(logProb(zeroMask));
end

end

