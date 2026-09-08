function detectedBins = senloraStaticPrecDecode( ...
        rxSymbols, config, knownPilotBins)
%SENLORASTATICPRECDECODE Four-pilot constant-CFO PREC baseline.

numSymbols = size(rxSymbols,1);
bootstrapCount = numel(knownPilotBins);
sampleIndex = 0:(2^config.sf-1);
bootstrap = senloraEstimateBootstrapPilots( ...
    rxSymbols(1:bootstrapCount,:),knownPilotBins,config.sf,Step=0.1);
estimates = bootstrap.cfoBins;
phaseAtPilot = bootstrap.phaseStartRad;
staticCfo = mean(estimates);
phaseState = phaseAtPilot(end)+2*pi*staticCfo;
detectedBins = zeros(numSymbols,1);
detectedBins(1:bootstrapCount) = knownPilotBins;
for idx = bootstrapCount+1:numSymbols
    correction = exp(-1i*(phaseState+2*pi*staticCfo* ...
        sampleIndex/(2^config.sf)));
    compensated = rxSymbols(idx,:).*correction;
    detectedBins(idx) = senloraHardDemodulate(compensated,config.sf);
    phaseState = phaseState+2*pi*staticCfo;
end
end
