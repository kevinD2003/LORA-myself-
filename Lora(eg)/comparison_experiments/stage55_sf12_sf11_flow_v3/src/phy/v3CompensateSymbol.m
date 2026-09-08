function compensated = v3CompensateSymbol(rx,phaseStartRad,cfoCenterBins,rateBinsPerSec,config)
%V3COMPENSATESYMBOL Continuous phase, CFO, and linear-rate compensation.

m = config.samplesPerSymbol;
if numel(rx) ~= m
    error('V3:CompensationLength','Expected one complete SF12 symbol.');
end
sampleTime = (0:m-1)/config.sampleRateHz;
startCfoBins = cfoCenterBins-rateBinsPerSec*config.symbolDurationSec/2;
phaseCycles = startCfoBins*(sampleTime/config.symbolDurationSec)+ ...
    0.5*rateBinsPerSec*(sampleTime.^2/config.symbolDurationSec);
compensated = rx.*exp(-1i*(phaseStartRad+2*pi*phaseCycles));
end

