function estimate = satelliteFig3HuangPrecCpBootstrapEstimate( ...
        rxPilots,knownWaveformBins,config,options)
%SATELLITEFIG3HUANGPRECCPBOOTSTRAPESTIMATE Continuous-phase Huang PREC.
%   Huang's PREC rotates each known upchirp by eta, dechirps it, searches
%   the largest FFT peak, and defines epsilonHat = integerBin - eta.  The
%   original code complex-averages the eight received upchirps first.  A
%   physical continuous CFO gives every upchirp a different global phase,
%   so this adapted front end accumulates the eight FFT powers instead.
%   No trajectory, rate, payload decision, or channel truth is used.

arguments
    rxPilots (:,:) double
    knownWaveformBins (:,1) double
    config (1,1) struct
    options.EtaStepBins (1,1) double {mustBePositive} = 0.1
end

pilotCount = numel(knownWaveformBins);
m = config.samplesPerSymbol;
if size(rxPilots,1) ~= pilotCount || size(rxPilots,2) ~= m || ...
        pilotCount < 1
    error('SatelliteFig3:HuangPrecCpShape', ...
        'Known preamble rows must contain complete LoRa symbols.');
end
if any(knownWaveformBins ~= 0)
    error('SatelliteFig3:HuangPrecCpPreamble', ...
        'Huang PREC requires zero-valued upchirps.');
end
if options.EtaStepBins > 1
    error('SatelliteFig3:HuangPrecCpEtaStep', ...
        'The normalized eta step must not exceed one FFT bin.');
end

n = 0:m-1;
downchirp = conj(satelliteFig3ModulateSymbol(0,config.sf));
etaCandidates = (0:options.EtaStepBins: ...
    (1-options.EtaStepBins/2)).';
combinedPower = zeros(numel(etaCandidates),m);
for etaIndex = 1:numel(etaCandidates)
    rotation = exp(1i*2*pi*etaCandidates(etaIndex)*n/m);
    for pilot = 1:pilotCount
        spectrum = fft(rxPilots(pilot,:).*rotation.*downchirp)/sqrt(m);
        combinedPower(etaIndex,:) = combinedPower(etaIndex,:) + ...
            abs(spectrum).^2;
    end
end

[peakPerEta,peakBinPerEta] = max(combinedPower,[],2);
[peakMetric,bestEtaIndex] = max(peakPerEta);
etaHat = etaCandidates(bestEtaIndex);
rawIntegerBin = peakBinPerEta(bestEtaIndex)-1;
signedIntegerBin = rawIntegerBin;
if signedIntegerBin >= m/2
    signedIntegerBin = signedIntegerBin-m;
end
epsilonHatBins = signedIntegerBin-etaHat;

% SenLoRa's original design uses the known preamble phase evolution to
% initialise Doppler rate.  This fit is receiver-only and does not alter
% Huang's epsilon estimate.  The static Huang baseline deliberately
% ignores the returned rate, while SenLoRa may use it before virtual-pilot
% updates become available.
joint = satelliteFig3BootstrapJointPhaseEstimate( ...
    rxPilots,knownWaveformBins,config,epsilonHatBins);

% Recover each preamble's own start phase after the shared Huang CFO
% estimate.  These phases preserve the physical inter-symbol continuity;
% they are not averaged or reset.
cfoBins = repmat(epsilonHatBins,pilotCount,1);
phaseRad = zeros(pilotCount,1);
peakRatio = zeros(pilotCount,1);
individualPeak = zeros(pilotCount,1);
for pilot = 1:pilotCount
    tone = rxPilots(pilot,:).*downchirp.* ...
        exp(-1i*2*pi*epsilonHatBins*n/m);
    coherent = mean(tone);
    phaseRad(pilot) = angle(coherent);
    compensatedSpectrum = abs(fft(tone)/sqrt(m));
    [individualPeak(pilot),peakIndex] = max(compensatedSpectrum);
    background = true(1,m);
    background(max(1,peakIndex-1):min(m,peakIndex+1)) = false;
    backgroundLevel = median(compensatedSpectrum(background));
    peakRatio(pilot) = individualPeak(pilot)/max(backgroundLevel,eps);
end

estimate = struct( ...
    'coarseCfoBins',signedIntegerBin, ...
    'cfoBins',cfoBins, ...
    'phaseRad',phaseRad, ...
    'peakRatio',peakRatio, ...
    'localCfoBins',cfoBins, ...
    'localPhaseRad',phaseRad, ...
    'jointRateBinsPerSec',joint.rateBinsPerSec, ...
    'joint',joint, ...
    'etaHatBins',etaHat, ...
    'integerCfoBin',signedIntegerBin, ...
    'rawIntegerFftBin',rawIntegerBin, ...
    'epsilonHatBins',epsilonHatBins, ...
    'etaCandidates',etaCandidates, ...
    'peakPerEta',peakPerEta, ...
    'peakBinPerEta',peakBinPerEta-1, ...
    'peakMetric',peakMetric, ...
    'individualPeakMetric',individualPeak, ...
    'combinedPower',combinedPower, ...
    'aggregatePower',combinedPower(bestEtaIndex,:), ...
    'continuousPhaseAdaptation', ...
        'sum per-upchirp FFT power before the Huang global peak search', ...
    'algorithmProvenance', ...
        'Huang PREC/PRC eta search with continuous-phase power combining');
end
