function detectedBins = senloraDecodeRaw(rxSymbols, config)
%SENLORADECODERAW Uncompensated noncoherent dechirp-FFT detector.
numSymbols = size(rxSymbols,1);
detectedBins = zeros(numSymbols,1);
for idx = 1:numSymbols
    detectedBins(idx) = senloraHardDemodulate(rxSymbols(idx,:),config.sf);
end
end

