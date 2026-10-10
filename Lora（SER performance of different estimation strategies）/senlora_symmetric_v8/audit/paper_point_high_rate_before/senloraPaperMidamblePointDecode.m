function result = senloraPaperMidamblePointDecode(observation,c)
%SENLORAPAPERMIDAMBLEPOINTDECODE Eq.(17)/(18), no rate/trend/delay/gates.
layout = observation.layout;
if ~isequal(layout.downchirpRows,[9;10]) || numel(layout.midambleRows)~=ceil(c.payloadSymbolCount/3)
    error('EXP5Paper:ReceiverFrame','Requires Paper Point synchronization/midambles.');
end
up = v4ModulateSymbol(0,c);
initial = localPoint(observation.rxPhysical(layout.downchirpRows(end),:),conj(up),c);
currentCfo = initial;
phaseStart = angle(exp(1i*2*pi*currentCfo* ...
    layout.physicalStartTimeSec(layout.dataRows(1))/c.symbolDurationSec));
samples = complex(zeros(c.payloadSymbolCount,c.samplesPerSymbol));
estimated = zeros(c.payloadSymbolCount,1);
residuals = zeros(numel(layout.midambleRows),1);
cumulative = zeros(size(residuals));
effective = nan(size(residuals));
pilot = 0;
for row = layout.dataRows(1):layout.physicalSymbolCount
    oldCfo = currentCfo;
    compensated = v4CompensateSymbol(observation.rxPhysical(row,:),phaseStart,oldCfo,0,c);
    if layout.kind(row)=="data"
        data = layout.dataIndex(row);
        samples(data,:) = compensated;
        estimated(data) = oldCfo;
    elseif layout.kind(row)=="midamble"
        pilot = pilot+1;
        residuals(pilot) = localPoint(compensated,up,c);
        currentCfo = oldCfo+residuals(pilot);
        cumulative(pilot) = currentCfo;
        next = layout.midambleAfterDataIndex(pilot)+1;
        if next<=c.payloadSymbolCount, effective(pilot) = next; end
    end
    phaseStart = angle(exp(1i*(phaseStart+2*pi*oldCfo)));
end
% Only hard FFT symbols enter SER. Noise scale for ancillary soft decoding
% is estimated from the eight observed upchirps, not taken from the SNR field.
power = zeros(8,c.samplesPerSymbol);
for k = 1:8
    energy = abs(fft(observation.rxPhysical(k,:).*conj(up))/sqrt(c.samplesPerSymbol)).^2;
    power(k,:) = energy;
end
noisePower = max(median(power,'all')/log(2),eps);
decoded = v4DecodePayload(samples,c,noisePower);
result = struct('methodName','Paper Midamble-Point Eq17 (user PHY)', ...
    'algorithmVersion','Paper-Midamble-Point-Eq17-integer-FFT-v1', ...
    'detectedPhysicalBins',decoded.hardPhysicalBins,'estimatedCfoBins',estimated, ...
    'initialCfoBins',initial,'midambleResidualBins',residuals, ...
    'midambleCumulativeCfoBins',cumulative,'pilotFirstEffectiveDataIndex',effective, ...
    'explicitMidambleAccepted',true(size(residuals)),'usesDopplerRate',false, ...
    'usesPayloadFeedback',false,'usesPayloadTruth',false,'usesOrbitTruth',false, ...
    'usesCaseIdentity',false,'usesSnrInput',false,'usesTargetSer',false, ...
    'piecewiseConstantCfo',true,'midambleUpdateDelayDataSymbols',0);
end

function cfo = localPoint(rx,known,c)
[~,bin] = max(abs(fft(rx.*conj(known))).^2);
cfo = bin-1;
if cfo>=c.samplesPerSymbol/2, cfo = cfo-c.samplesPerSymbol; end
end
