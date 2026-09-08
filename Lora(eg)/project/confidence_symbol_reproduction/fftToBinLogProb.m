function logProb = fftToBinLogProb(chirpFft, noisePower, mode)
%FFTTOBINLOGPROB Convert FFT-bin energy to a stable log probability vector.
%
% mode="paper" implements exp(|Z|^2 - N0), as written in the paper.
% mode="noise-scaled" uses (|Z|^2 - N0) / N0 for a practical ablation.

arguments
    chirpFft (1,:) double
    noisePower (1,1) double {mustBePositive}
    mode (1,1) string = "paper"
end

energy = abs(chirpFft) .^ 2;

switch mode
    case "paper"
        logits = energy - noisePower;
    case "noise-scaled"
        logits = (energy - noisePower) ./ max(noisePower, eps);
    otherwise
        error("SenLoRa:UnknownProbabilityMode", ...
            "Unknown probability mode: %s.", mode);
end

maxLogit = max(logits);
logProb = logits - (maxLogit + log(sum(exp(logits - maxLogit))));

end

