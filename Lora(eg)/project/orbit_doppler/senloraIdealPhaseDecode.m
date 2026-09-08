function detectedBins = senloraIdealPhaseDecode(rxSymbols, truth, config)
%SENLORAIDEALPHASEDECODE Ideal reference using the true sample phase.
numSymbols = size(rxSymbols,1);
detectedBins = zeros(numSymbols,1);
for idx = 1:numSymbols
    compensated = rxSymbols(idx,:).*exp(-1i*truth.phaseRad(idx,:));
    detectedBins(idx) = senloraHardDemodulate(compensated,config.sf);
end
end

