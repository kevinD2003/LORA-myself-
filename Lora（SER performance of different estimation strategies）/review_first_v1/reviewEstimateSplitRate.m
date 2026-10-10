function estimate = reviewEstimateSplitRate(rxPilots,c,maxRate)
%REVIEWESTIMATESPLITRATE Independent four-preamble rate-consistency evidence.

if size(rxPilots,1) ~= c.bootstrapPilotCount
    error('EXP3:SplitRateShape','Expected eight preambles.');
end
first = localRate(rxPilots(1:4,:),c,maxRate);
last = localRate(rxPilots(5:8,:),c,maxRate);
sigma = max(0.05,abs(first-last)/sqrt(2));
sameSign = sign(first)==sign(last) && sign(first)~=0;
estimate = struct('firstHalfRateBinsPerSec',first, ...
    'lastHalfRateBinsPerSec',last,'sigmaRateBinsPerSec',sigma, ...
    'sameSign',sameSign,'differenceBinsPerSec',abs(first-last));
end

function rate = localRate(pilots,c,maxRate)
m = c.samplesPerSymbol;
down = conj(v4ModulateSymbol(0,c));
dechirped = reshape((pilots.*repmat(down,size(pilots,1),1)).',[],1);
timeSymbols = (0:numel(dechirped)-1).'/m;
coarse = (-maxRate:1:maxRate).';
metric = localMetric(dechirped,timeSymbols,coarse,c);
[~,best] = max(metric);
fine = (coarse(best)-1:0.1:coarse(best)+1).';
fine = fine(abs(fine)<=maxRate);
metric = localMetric(dechirped,timeSymbols,fine,c);
[~,best] = max(metric);
rate = fine(best);
end

function metric = localMetric(dechirped,timeSymbols,rates,c)
metric = zeros(numel(rates),1);
for index = 1:numel(rates)
    ratePerSymbol = rates(index)*c.symbolDurationSec;
    corrected = dechirped.*exp(-1i*pi*ratePerSymbol*timeSymbols.^2);
    spectrum = abs(fft(corrected)).^2;
    metric(index) = max(spectrum);
end
end

