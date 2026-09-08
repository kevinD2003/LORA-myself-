function estimate = sf12EstimateResidualCfo(compensated,waveformBin,cfg)
%SF12ESTIMATERESIDUALCFO Fine grid residual after a receiver decision.

n = cfg.radio.samplesPerSymbol;
sample = 0:n-1;
baseband = compensated(:).'.*exp(-1j*2*pi*waveformBin*sample/n);
halfWidth = cfg.receiver.residualSearchHalfWidthBins;
step = cfg.receiver.residualSearchStepBins;
candidateBins = (-halfWidth:step:halfWidth).';
projection = abs(exp(-1j*2*pi*candidateBins*sample/n)*baseband.').^2;
[sorted,index] = sort(projection,'descend');
estimate.offsetBins = candidateBins(index(1));
estimate.offsetHz = estimate.offsetBins*cfg.radio.fftBinHz;
estimate.peakRatio = sorted(1)/max(sorted(2),eps);
estimate.atBoundary = index(1) == 1 || index(1) == numel(candidateBins);
estimate.phaseRad = angle(sum(baseband.*exp(-1j*2*pi* ...
    estimate.offsetBins*sample/n)));
end
