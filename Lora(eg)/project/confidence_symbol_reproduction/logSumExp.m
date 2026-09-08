function value = logSumExp(x)
%LOGSUMEXP Stable log(sum(exp(x))).

arguments
    x (1,:) double
end

maxValue = max(x);
value = maxValue + log(sum(exp(x - maxValue)));

end

