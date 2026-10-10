function [estimate,ci] = exp1BootstrapCI(values,draws,seed)
%EXP1BOOTSTRAPCI Packet-level percentile interval for a scalar mean.

values = values(:);
values = values(isfinite(values));
if isempty(values)
    estimate = NaN;
    ci = [NaN NaN];
    return
end
estimate = mean(values);
if all(values == 0)
    ci = [0 1-0.05^(1/numel(values))];
    return
end
stream = RandStream('mt19937ar','Seed',seed);
replicates = zeros(draws,1);
n = numel(values);
for draw = 1:draws
    index = randi(stream,n,n,1);
    replicates(draw) = mean(values(index));
end
ci = prctile(replicates,[2.5 97.5]);
end

