function rawErrorBins = dreFullPhyNoiselessTrajectory(startTimeSec,symbolCount,config)
%DREFULLPHYNOISELESSTRAJECTORY Noise-free centroid error for zero symbols.

symbols = zeros(symbolCount,1);
tx = dreModulateSymbols(symbols,config);
sampleCount = numel(tx);
timeSec = startTimeSec+(0:sampleCount-1).'/config.sampleRateHz;
orbit = drePaperOrbit(timeSec,config);
doppler = orbit.dopplerHz(:);
switch config.phaseModel
    case 'paper-equation-15-product'
        phase = 2*pi*doppler.*timeSec;
    case 'integrated-instantaneous-doppler'
        phase = zeros(sampleCount,1);
        phase(2:end) = cumsum(pi/config.sampleRateHz* ...
            (doppler(1:end-1)+doppler(2:end)));
    otherwise
        error('DRE:PhaseModel','Unknown phase model.');
end
phase = reshape(phase,config.samplesPerSymbol,symbolCount).';
estimate = dreEstimateCentroids(tx.*exp(1i*phase),config);
rawErrorBins = estimate.rawBins;
end

