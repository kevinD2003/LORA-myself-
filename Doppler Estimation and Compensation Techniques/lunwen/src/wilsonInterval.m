function interval = wilsonInterval(errorCount, trialCount)
%WILSONINTERVAL Two-sided 95 percent Wilson binomial interval.

arguments
    errorCount (1,1) double {mustBeInteger, mustBeNonnegative}
    trialCount (1,1) double {mustBeInteger, mustBePositive}
end

validateattributes(errorCount, {'numeric'}, ...
    {'scalar', 'integer', '>=', 0, '<=', trialCount});
validateattributes(trialCount, {'numeric'}, ...
    {'scalar', 'integer', 'positive'});
z = 1.95996398454005;
proportion = errorCount/trialCount;
denominator = 1 + z^2/trialCount;
center = (proportion + z^2/(2*trialCount))/denominator;
halfWidth = z*sqrt(proportion*(1-proportion)/trialCount + ...
    z^2/(4*trialCount^2))/denominator;
interval = [max(0, center-halfWidth), min(1, center+halfWidth)];
end
