function [shownBer,lower95,upper95] = satelliteFig3BerInterval95(errorCount,bitCount)
%SATELLITEFIG3BERINTERVAL95 Binomial BER display value and 95% bounds.
%   Nonzero points use the two-sided Wilson score interval.  A zero-error
%   point is displayed at the exact one-sided 95% upper bound
%   1-0.05^(1/N), rather than at zero on a logarithmic axis.

arguments
    errorCount double {mustBeNonnegative}
    bitCount double {mustBePositive}
end

assert(isequal(size(errorCount),size(bitCount)) || isscalar(bitCount), ...
    'errorCount and bitCount must have compatible sizes.');
assert(all(errorCount <= bitCount,'all'), ...
    'An error count cannot exceed the corresponding bit count.');

z = 1.95996398454005;
p = errorCount./bitCount;
denominator = 1+z^2./bitCount;
center = (p+z^2./(2*bitCount))./denominator;
radius = z.*sqrt(p.*(1-p)./bitCount+z^2./(4*bitCount.^2))./ ...
    denominator;
lower95 = max(0,center-radius);
upper95 = min(1,center+radius);

zeroMask = errorCount == 0;
lower95(zeroMask) = 0;
upper95(zeroMask) = 1-0.05.^(1./bitCount(zeroMask));
shownBer = p;
shownBer(zeroMask) = upper95(zeroMask);
end
