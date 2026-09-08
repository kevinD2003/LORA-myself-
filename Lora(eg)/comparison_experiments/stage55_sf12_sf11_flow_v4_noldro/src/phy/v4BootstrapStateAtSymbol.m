function [phaseStartRad,cfoCenterBins] = v4BootstrapStateAtSymbol(bootstrap,symbolStartIndex,config)
%V4BOOTSTRAPSTATEATSYMBOL Extrapolate the receiver-only quadratic fit.

x = double(symbolStartIndex);
if isfield(bootstrap,'phaseModelCycles')
    model = bootstrap.phaseModelCycles;
    phaseCycles = model(1)+model(2)*x+0.5*model(3)*x.^2;
    cfoCenterBins = model(2)+model(3)*(x+0.5);
    modelRateBinsPerSec = model(3)/config.symbolDurationSec;
else
    beta = bootstrap.joint.betaCycles;
    phaseCycles = beta(1)+(bootstrap.coarseCfoBins+beta(2))*x+ ...
        0.5*beta(3)*x.^2;
    cfoCenterBins = bootstrap.coarseCfoBins+beta(2)+beta(3)*(x+0.5);
    modelRateBinsPerSec = beta(3)/config.symbolDurationSec;
end
phaseStartRad = angle(exp(1i*2*pi*phaseCycles));
if nargin > 2 && abs(modelRateBinsPerSec- ...
        bootstrap.rateBinsPerSec) > 100*eps(max(1,abs(bootstrap.rateBinsPerSec)))
    error('V4:BootstrapState','Bootstrap rate fields are inconsistent.');
end
end
