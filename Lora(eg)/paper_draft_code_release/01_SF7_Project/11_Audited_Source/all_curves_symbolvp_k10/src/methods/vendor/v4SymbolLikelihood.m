function result = v4SymbolLikelihood(symbolSamples,config,noisePower)
%V4SYMBOLLIKELIHOOD Direct 4096-bin no-LDRO hard and soft metric.

arguments
    symbolSamples (1,:) double
    config (1,1) struct
    noisePower (1,1) double = NaN
end

m = config.samplesPerSymbol;
if numel(symbolSamples) ~= m
    error('V4:InvalidDemodLength','Expected one complete SF12 symbol.');
end
persistent cachedM upchirp
if isempty(cachedM) || cachedM ~= m
    n = (0:m-1).';
    upchirp = exp(1i*2*pi*(n.^2/(2*m)-n/2));
    cachedM = m;
end
spectrum = fft(symbolSamples(:).*conj(upchirp))/sqrt(m);
energy = abs(spectrum).^2;
if ~isfinite(noisePower)
    noisePower = max(mean(energy),eps);
else
    noisePower = max(noisePower,eps);
end
logits = energy/noisePower;
logits = logits-max(logits);
logProbability = logits-log(sum(exp(logits)));
[peakMetric,logicalIndex] = max(energy);
ordered = sort(energy,'descend');
[~,rawIndex] = max(energy);
logicalBin = logicalIndex-1;
result = struct('logicalBin',logicalBin, ...
    'physicalBin',logicalBin, ...
    'grayLabel',double(v4GrayEncode(uint32(logicalBin))), ...
    'rawFftBin',rawIndex-1,'peakMetric',peakMetric, ...
    'peakRatio',peakMetric/max(ordered(2),eps), ...
    'binEnergy',energy,'logProbability',logProbability, ...
    'spectrum',spectrum,'noisePower',noisePower);
end
