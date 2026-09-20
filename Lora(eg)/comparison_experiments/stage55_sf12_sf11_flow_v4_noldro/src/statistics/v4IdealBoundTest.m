function result=v4IdealBoundTest(symbolErrors,symbolCount,idealSer,alpha)
%V4IDEALBOUNDTEST One-sided Wilson test against an exact SER lower bound.
arguments
    symbolErrors (1,1) double {mustBeInteger,mustBeNonnegative}
    symbolCount (1,1) double {mustBeInteger,mustBePositive}
    idealSer (1,1) double {mustBeGreaterThan(idealSer,0),mustBeLessThan(idealSer,1)}
    alpha (1,1) double {mustBeGreaterThan(alpha,0),mustBeLessThan(alpha,.5)}=.05
end
if symbolErrors>symbolCount
    error('V4:IdealBoundCount','Errors cannot exceed symbol count.');
end
z=1.64485362695147;
if abs(alpha-.05)>eps
    error('V4:IdealBoundAlpha','V1 freezes one-sided alpha=0.05.');
end
estimate=symbolErrors/symbolCount;
denominator=1+z^2/symbolCount;
center=(estimate+z^2/(2*symbolCount))/denominator;
half=z/denominator*sqrt(estimate*(1-estimate)/symbolCount+ ...
    z^2/(4*symbolCount^2));
upper=min(1,center+half);
if upper<idealSer
    status='FAIL_BELOW_IDEAL';pass=false;
elseif estimate<idealSer
    status='PASS_MONTE_CARLO_FLUCTUATION';pass=true;
else
    status='PASS_ABOVE_IDEAL';pass=true;
end
result=struct('status',status,'pass',pass,'symbolErrors',symbolErrors, ...
    'symbolCount',symbolCount,'estimate',estimate,'idealSer',idealSer, ...
    'oneSidedUpper95',upper,'alpha',alpha, ...
    'test','one-sided Wilson upper bound; H0 SER_method >= SER_ideal');
end

