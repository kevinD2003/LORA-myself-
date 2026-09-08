function [rxSymbols, txSymbols, truth] = generateContinuousSatelliteFrame(symbolBins, config, options)
%GENERATECONTINUOUSSATELLITEFRAME Exact full-RF dynamic-Doppler CSS frame.
%   Doppler phase is integrated once across the complete frame.  There is
%   no per-symbol phase reset, and truth is evaluation-only.

arguments
    symbolBins (:,1) double {mustBeInteger, mustBeNonnegative}
    config (1,1) struct
    options.StartTimeSec (1,1) double
    options.SampleSnrDb (1,1) double = Inf
    options.NoiseSeed (1,1) double = 20260805
    options.InitialPhaseRad (1,1) double = 0
    options.NextSymbolBin (1,1) double = NaN
end

m = config.samplesPerSymbol;
if any(symbolBins >= m)
    error('SatelliteFig3:InvalidSymbol', 'Every symbol must be below 2^SF.');
end
if ~isfinite(options.InitialPhaseRad)
    error('SatelliteFig3:InitialPhase', ...
        'InitialPhaseRad must be finite.');
end
if isfinite(options.NextSymbolBin) && ( ...
        options.NextSymbolBin ~= round(options.NextSymbolBin) || ...
        options.NextSymbolBin < 0 || options.NextSymbolBin >= m)
    error('SatelliteFig3:NextSymbol', ...
        'NextSymbolBin must be NaN or an integer below 2^SF.');
end
nSymbols = numel(symbolBins);
txSymbols = complex(zeros(nSymbols,m));
basebandHz = zeros(nSymbols,m);
for k = 1:nSymbols
    txSymbols(k,:) = satelliteFig3ModulateSymbol(symbolBins(k), config.sf);
    basebandHz(k,:) = satelliteFig3SymbolFrequency( ...
        symbolBins(k), config.sf, config.bandwidthHz).';
end

totalSamples = nSymbols*m;
sampleTime = options.StartTimeSec + (0:totalSamples-1)'/config.sampleRateHz;
orbit = satelliteFig3Trajectory(sampleTime, config);
basebandSerial = reshape(basebandHz.', [], 1);
dopplerSerial = -(config.carrierFrequencyHz + basebandSerial).* ...
    orbit.radialVelocityMps/config.speedOfLightMps;
phaseSerial = options.InitialPhaseRad+[0; cumsum( ...
    pi/config.sampleRateHz*( ...
    dopplerSerial(1:end-1)+dopplerSerial(2:end)))];
phaseSymbols = reshape(phaseSerial,m,nSymbols).';
dopplerSymbols = reshape(dopplerSerial,m,nSymbols).';
dopplerRateSymbols = reshape(orbit.dopplerRateHzPerSec,m,nSymbols).';
rxNoiseless = txSymbols .* exp(1i*phaseSymbols);

if isinf(options.SampleSnrDb)
    noiseVariance = 0;
    noise = complex(zeros(size(rxNoiseless)));
else
    noiseVariance = 10^(-options.SampleSnrDb/10);
    stream = RandStream('mt19937ar','Seed',options.NoiseSeed);
    noise = sqrt(noiseVariance/2)*(randn(stream,size(rxNoiseless)) + ...
        1i*randn(stream,size(rxNoiseless)));
end
rxSymbols = rxNoiseless + noise;
center = floor(m/2)+1;
sampleTimeSymbols = reshape(sampleTime,m,nSymbols).';
nextFrameStartTimeSec = options.StartTimeSec+ ...
    totalSamples/config.sampleRateHz;
nextFrameStartPhaseRad = NaN;
nextFrameStartDopplerHz = NaN;
if isfinite(options.NextSymbolBin)
    nextOrbit = satelliteFig3Trajectory(nextFrameStartTimeSec,config);
    nextBasebandHz = satelliteFig3SymbolFrequency( ...
        options.NextSymbolBin,config.sf,config.bandwidthHz);
    nextFrameStartDopplerHz = -(config.carrierFrequencyHz+ ...
        nextBasebandHz(1))*nextOrbit.radialVelocityMps/ ...
        config.speedOfLightMps;
    nextFrameStartPhaseRad = phaseSerial(end)+ ...
        pi/config.sampleRateHz*(dopplerSerial(end)+ ...
        nextFrameStartDopplerHz);
end
truth = struct( ...
    'symbolBins', symbolBins, 'sampleTimeSec', sampleTimeSymbols, ...
    'dopplerHz', dopplerSymbols, 'phaseRad', phaseSymbols, ...
    'radialVelocityMps', reshape(orbit.radialVelocityMps,m,nSymbols).', ...
    'trueDopplerHz', dopplerSymbols(:,center), ...
    'trueDopplerRateHzPerSec', dopplerRateSymbols(:,center), ...
    'noiseVariance', noiseVariance, 'sampleSnrDb', options.SampleSnrDb, ...
    'startTimeSec', options.StartTimeSec, ...
    'initialPhaseRad',options.InitialPhaseRad, ...
    'lastSamplePhaseRad',phaseSerial(end), ...
    'nextFrameStartTimeSec',nextFrameStartTimeSec, ...
    'nextFrameStartPhaseRad',nextFrameStartPhaseRad, ...
    'nextFrameStartDopplerHz',nextFrameStartDopplerHz);
end
