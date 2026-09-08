function result = v3SymbolLikelihood(symbolSamples,config,noisePower)
%V3SYMBOLLIKELIHOOD Aggregate 4096 FFT bins into 1024 LDRO regions.

arguments
    symbolSamples (1,:) double
    config (1,1) struct
    noisePower (1,1) double = NaN
end

m = config.samplesPerSymbol;
if numel(symbolSamples) ~= m
    error('V3:InvalidDemodLength','Expected one complete SF12 symbol.');
end
persistent cachedM cachedSpacing upchirp regionIndices
if isempty(cachedM) || cachedM ~= m || cachedSpacing ~= config.dataBinSpacing
    n = (0:m-1).';
    upchirp = exp(1i*2*pi*(n.^2/(2*m)-n/2));
    centers = (0:config.dataAlphabetSize-1).'*config.dataBinSpacing;
    offsets = -1:(config.dataBinSpacing-2);
    regionIndices = mod(centers+offsets,m)+1;
    cachedM = m;
    cachedSpacing = config.dataBinSpacing;
end
spectrum = fft(symbolSamples(:).*conj(upchirp))/sqrt(m);
energy = abs(spectrum).^2;
regionEnergy = sum(energy(regionIndices),2);
if ~isfinite(noisePower)
    noisePower = max(median(regionEnergy),eps);
else
    noisePower = max(noisePower,eps);
end
logits = regionEnergy/noisePower;
logits = logits-max(logits);
logProbability = logits-log(sum(exp(logits)));
[peakMetric,logicalIndex] = max(regionEnergy);
ordered = sort(regionEnergy,'descend');
[~,rawIndex] = max(energy);
logicalBin = logicalIndex-1;
result = struct('logicalBin',logicalBin, ...
    'physicalBin',logicalBin*config.dataBinSpacing, ...
    'grayLabel',double(v3GrayEncode(uint32(logicalBin))), ...
    'rawFftBin',rawIndex-1,'peakMetric',peakMetric, ...
    'peakRatio',peakMetric/max(ordered(2),eps), ...
    'regionEnergy',regionEnergy,'logProbability',logProbability, ...
    'spectrum',spectrum,'noisePower',noisePower);
end
