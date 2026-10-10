function calibration = dreCalibrateCentroidErrors(snrDb,config,sampleCount,seed)
%DRECALIBRATECENTROIDERRORS Empirical noisy-minus-noiseless centroid errors.

arguments
    snrDb (1,1) double
    config (1,1) struct
    sampleCount (1,1) double {mustBeInteger,mustBePositive}
    seed (1,1) double {mustBeInteger,mustBeNonnegative}
end
stream = RandStream('mt19937ar','Seed',seed);
orbit = drePaperOrbit(0,config);
starts = (2*rand(stream,sampleCount,1)-1)* ...
    (orbit.horizonTimeSec-config.symbolDurationSec);
symbols = randi(stream,[0 config.samplesPerSymbol-1],sampleCount,1);
errors = zeros(sampleCount,1);
chunkSize = config.calibrationChunkSize;
for first = 1:chunkSize:sampleCount
    rows = first:min(sampleCount,first+chunkSize-1);
    count = numel(rows);
    tx = dreModulateSymbols(symbols(rows),config);
    time = starts(rows)+(0:config.samplesPerSymbol-1)/config.sampleRateHz;
    orbitRows = drePaperOrbit(time,config);
    phase = 2*pi*orbitRows.dopplerHz.*time;
    noiseless = tx.*exp(1i*phase);
    noiseVariance = 10^(-snrDb/10);
    noise = sqrt(noiseVariance/2)*(randn(stream,count,config.samplesPerSymbol)+ ...
        1i*randn(stream,count,config.samplesPerSymbol));
    cleanEstimate = dreEstimateCentroids(noiseless,config);
    noisyEstimate = dreEstimateCentroids(noiseless+noise,config);
    delta = noisyEstimate.rawBins-cleanEstimate.rawBins;
    errors(rows) = mod(delta+config.samplesPerSymbol/2, ...
        config.samplesPerSymbol)-config.samplesPerSymbol/2;
end
calibration = struct('snrDb',snrDb,'errorsBins',errors,'sampleCount',sampleCount, ...
    'rmsBins',sqrt(mean(errors.^2)),'seed',seed);
end

