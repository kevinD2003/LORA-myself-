function result = senloraTruthFilteredDecode( ...
        rxSymbols, trueBins, config, knownPilotBins)
%SENLORATRUTHFILTEREDDECODE Evaluation-only correct-symbol upper bound.
%
% The receiver-like first pass obtains hard decisions.  Truth is used only
% outside the tracker to retain decisions that are correct; this result is
% never used by the SenLoRa receiver.

numSymbols = size(rxSymbols,1);
allMask = true(numSymbols,1);
firstPass = trackSenLoRaVirtualPilots( ...
    rxSymbols,config,knownPilotBins,allMask, ...
    ForceAccept=true,PeakRatioThreshold=0);
truthMask = firstPass.detectedBins == trueBins;
truthMask(1:numel(knownPilotBins)) = true;
result = trackSenLoRaVirtualPilots( ...
    rxSymbols,config,knownPilotBins,truthMask, ...
    ForceAccept=true,PeakRatioThreshold=0);
result.truthPilotMask = truthMask;
result.firstPass = firstPass;
end

