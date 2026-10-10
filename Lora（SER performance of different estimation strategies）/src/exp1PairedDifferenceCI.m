function [estimate,ci] = exp1PairedDifferenceCI(baseline,stage55,draws,seed)
%EXP1PAIREDDIFFERENCECI CI for baseline packet SER minus Stage55 packet SER.

baseline = baseline(:);
stage55 = stage55(:);
valid = isfinite(baseline) & isfinite(stage55);
baseline = baseline(valid);
stage55 = stage55(valid);
if isempty(baseline)
    estimate = NaN;
    ci = [NaN NaN];
    return
end
difference = baseline-stage55;
estimate = mean(difference);
if all(baseline == 0) && all(stage55 == 0)
    upper = 1-0.05^(1/numel(difference));
    ci = [-upper upper];
    return
end
stream = RandStream('mt19937ar','Seed',seed);
n = numel(difference);
replicates = zeros(draws,1);
for draw = 1:draws
    index = randi(stream,n,n,1);
    replicates(draw) = mean(difference(index));
end
ci = prctile(replicates,[2.5 97.5]);
end
