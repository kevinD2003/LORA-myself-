function result = satelliteFig3PaperPrecDecode( ...
        rxSymbols,config,knownPreambleBins,options)
%SATELLITEFIG3PAPERPRECDECODE Thesis PREC with one CFO estimate per frame.
%   This receiver follows Huang Peng's equations (4-1)--(4-7) and the
%   callable logic embedded in the senior-code PRC/FD_Shift scripts:
%   complex-average the known upchirps, search eta in [0,1), select the
%   largest dechirped FFT peak, and use that single CFO estimate for every
%   payload symbol. It deliberately has no orbit prior, Doppler-rate fit,
%   virtual pilots, payload feedback, or channel-truth input.

arguments
    rxSymbols (:,:) double
    config (1,1) struct
    knownPreambleBins (:,1) double
    options.EtaStepBins (1,1) double {mustBePositive} = 0.1
end

m = config.samplesPerSymbol;
preambleCount = numel(knownPreambleBins);
nSymbols = size(rxSymbols,1);
if size(rxSymbols,2) ~= m || preambleCount < 1 || ...
        preambleCount >= nSymbols
    error('SatelliteFig3:PaperPrecShape', ...
        'Paper PREC requires complete preamble and payload symbols.');
end
if any(knownPreambleBins ~= 0)
    error('SatelliteFig3:PaperPrecPreamble', ...
        'The thesis PREC reference requires zero-valued upchirps.');
end
if options.EtaStepBins > 1
    error('SatelliteFig3:PaperPrecEtaStep', ...
        'The normalized eta step must not exceed one FFT bin.');
end

% Equation (4-1): direct complex averaging, exactly as in the source.
% Do not phase-align these symbols: that would be an adapted receiver.
preambleRows = 1:preambleCount;
preambleAverage = mean(rxSymbols(preambleRows,:),1);
referenceUpchirp = satelliteFig3ModulateSymbol(0,config.sf);
downchirp = conj(referenceUpchirp);
n = 0:m-1;
etaCandidates = (0:options.EtaStepBins:(1-options.EtaStepBins/2)).';
rotationBank = exp(1i*2*pi*etaCandidates*n/m);
spectra = fft(rotationBank.*(preambleAverage.*downchirp),[],2)/sqrt(m);
[peakPerEta,peakBinPerEta] = max(abs(spectra),[],2);
[peakMetric,bestEtaIndex] = max(peakPerEta);
etaHat = etaCandidates(bestEtaIndex);
rawIntegerBin = peakBinPerEta(bestEtaIndex)-1;
signedIntegerBin = rawIntegerBin;
if signedIntegerBin >= m/2
    signedIntegerBin = signedIntegerBin-m;
end

% Equations (4-5)--(4-7). The one-based FFT correction is already applied.
epsilonHatBins = signedIntegerBin-etaHat;
compensation = exp(-1i*2*pi*epsilonHatBins*n/m);
compensatedSymbols = rxSymbols;
detectedWaveformBins = nan(nSymbols,1);
detectedWaveformBins(preambleRows) = knownPreambleBins;
for symbol = preambleCount+1:nSymbols
    compensatedSymbols(symbol,:) = rxSymbols(symbol,:).*compensation;
    decision = satelliteFig3HardDecision( ...
        compensatedSymbols(symbol,:),config);
    detectedWaveformBins(symbol) = decision.waveformBin;
end
payloadRows = preambleCount+1:nSymbols;
decodedDataBits = satelliteFig3HardPayloadBits( ...
    detectedWaveformBins(payloadRows),config);

individualNorm = sqrt(sum(abs(rxSymbols(preambleRows,:)).^2,2));
preambleCoherentGain = norm(preambleAverage)/max(mean(individualNorm),eps);
result = struct( ...
    'detectedWaveformBins',detectedWaveformBins, ...
    'decodedDataBits',decodedDataBits, ...
    'compensatedSymbols',compensatedSymbols, ...
    'epsilonHatBins',epsilonHatBins, ...
    'etaHatBins',etaHat, ...
    'integerCfoBin',signedIntegerBin, ...
    'rawIntegerFftBin',rawIntegerBin, ...
    'etaCandidates',etaCandidates, ...
    'peakPerEta',peakPerEta, ...
    'peakBinPerEta',peakBinPerEta-1, ...
    'peakMetric',peakMetric, ...
    'preambleAverage',preambleAverage, ...
    'preambleCoherentGain',preambleCoherentGain, ...
    'preambleCount',preambleCount, ...
    'usesPayloadFeedback',false, ...
    'usesDopplerRate',false, ...
    'algorithmProvenance', ...
    'Huang thesis (4-1)--(4-7); senior PREC/PRC eta search');
end
