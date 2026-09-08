function result = senloraBlindHardUpdateDecode( ...
        rxSymbols, config, knownPilotBins)
%SENLORABLINDHARDUPDATEDECODE Update every hard decision without SenLoRa.
numSymbols = size(rxSymbols,1);
acceptedMask = true(numSymbols,1);
result = trackSenLoRaVirtualPilots( ...
    rxSymbols,config,knownPilotBins,acceptedMask, ...
    ForceAccept=true,PeakRatioThreshold=0);
end

