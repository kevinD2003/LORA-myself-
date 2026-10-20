function classification = v4Stage55PreambleRegimeClassifier(rxPilots,c,options)
%V4STAGE55PREAMBLEREGIMECLASSIFIER Equal-domain coherent CFO/rate search.
arguments
    rxPilots (:,:) double
    c (1,1) struct
    options.MaximumRateBinsPerSec (1,1) double {mustBePositive} = 20
    options.RateStepBinsPerSec (1,1) double {mustBePositive} = 1
end
pilotCount = c.bootstrapPilotCount;m = c.samplesPerSymbol;
if size(rxPilots,1) ~= pilotCount || size(rxPilots,2) ~= m
    error('V4:PreambleRegimeShape','Eight complete preambles are required.');
end
down = conj(v4ModulateSymbol(0,c));
dechirped = reshape((rxPilots.*repmat(down,pilotCount,1)).',[],1);
n = numel(dechirped);timeSymbols = (0:n-1).'/m;
fftIndex = (0:n-1).';signedIndex = fftIndex;
signedIndex(signedIndex >= n/2) = signedIndex(signedIndex >= n/2)-n;
cfoAxis = signedIndex*m/n;
centralMask = abs(cfoAxis) <= m/32;
largeMask = cfoAxis >= m/8 & cfoAxis <= 3*m/16;
rates = (-options.MaximumRateBinsPerSec: ...
    options.RateStepBinsPerSec:options.MaximumRateBinsPerSec).';
centralScore = -Inf;largeScore = -Inf;
centralCfo = NaN;largeCfo = NaN;centralRate = NaN;largeRate = NaN;
for rate = rates.'
    ratePerSymbol = rate*c.symbolDurationSec;
    corrected = dechirped.*exp(-1i*pi*ratePerSymbol*timeSymbols.^2);
    energy = abs(fft(corrected)).^2;
    [score,index] = max(energy(centralMask));
    candidates = find(centralMask);
    if score > centralScore
        centralScore = score;centralCfo = cfoAxis(candidates(index));
        centralRate = rate;
    end
    [score,index] = max(energy(largeMask));
    candidates = find(largeMask);
    if score > largeScore
        largeScore = score;largeCfo = cfoAxis(candidates(index));
        largeRate = rate;
    end
end
threshold = c.samplesPerSymbol/8;
largeRegion = largeScore > centralScore;
if largeRegion
    bestCfo = largeCfo;bestRate = largeRate;bestScore = largeScore;
    otherScore = centralScore;
else
    bestCfo = centralCfo;bestRate = centralRate;bestScore = centralScore;
    otherScore = largeScore;
end
classification = struct('cfoAtFirstPreambleStartBins',bestCfo, ...
    'rateBinsPerSec',bestRate,'score',bestScore, ...
    'scoreRatio',bestScore/max(otherScore,eps), ...
    'centralDomainScore',centralScore,'largeDomainScore',largeScore, ...
    'centralDomainCfoBins',centralCfo,'largeDomainCfoBins',largeCfo, ...
    'staticCfoMagnitudeThresholdBins',threshold, ...
    'largeCfoRegion',largeRegion, ...
    'rateCandidatesBinsPerSec',rates, ...
    'centralCfoDomainBins',[-m/32 m/32], ...
    'largeCfoDomainBins',[m/8 3*m/16], ...
    'usesPayloadTruth',false,'usesOrbitTruth',false, ...
    'source','equal-domain eight-preamble coherent CFO-rate likelihood');
end
