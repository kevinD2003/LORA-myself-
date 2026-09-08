function interval = sf12WilsonInterval(errors,total)
%SF12WILSONINTERVAL Two-sided 95 percent Wilson score interval.

if total <= 0
    interval = [NaN NaN];
    return
end
z = 1.95996398454005;
p = errors/total;
denominator = 1+z^2/total;
center = (p+z^2/(2*total))/denominator;
radius = z*sqrt(p*(1-p)/total+z^2/(4*total^2))/denominator;
interval = [max(0,center-radius),min(1,center+radius)];
end
