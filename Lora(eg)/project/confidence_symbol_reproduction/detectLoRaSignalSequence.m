function [result, frontend] = detectLoRaSignalSequence( ...
    rxSignal, cfg, numPayloadSymbols, referenceBins)
%DETECTLORASIGNALSEQUENCE Detect symbols and flags from a LoRa IQ waveform.
%
% The input is a synchronized complex baseband frame containing preamble
% and payload. referenceBins is optional and is used only for truth flags.

arguments
    rxSignal (:,1) double
    cfg struct
    numPayloadSymbols (1,1) double {mustBeInteger, mustBeNonnegative}
    referenceBins (:,1) double = zeros(0, 1)
end

[payloadFft, preambleFft, frontend] = ...
    dechirpLoRaSignalSequence(rxSignal, cfg, numPayloadSymbols);
result = detectContinuousSymbolSequence( ...
    payloadFft, preambleFft, cfg, referenceBins);

end
