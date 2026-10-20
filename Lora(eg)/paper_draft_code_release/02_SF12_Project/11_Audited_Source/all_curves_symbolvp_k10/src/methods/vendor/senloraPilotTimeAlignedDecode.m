function result = senloraPilotTimeAlignedDecode(observation,c)
%SENLORAPILOTTIMEALIGNEDDECODE Bracket-pilot CFO at each data center.
% User-approved buffered variant; NOT the original Paper Eq.(17) method.
% Only observed known chirps and relative frame-format times are used.
layout = observation.layout;
if ~isequal(layout.downchirpRows,[9;10]) || ...
        ~isequal(layout.midambleAfterDataIndex,(1:c.payloadSymbolCount).') || ...
        layout.midambleSpacingDataSymbols~=1 || ...
        numel(layout.midambleRows)~=c.payloadSymbolCount
    error('EXP5Aligned:ReceiverFrame','Requires native n_int=1 known-chirp frame.');
end
up = v4ModulateSymbol(0,c);
pilotRows = [layout.downchirpRows(end);layout.midambleRows];
pilotCfo = zeros(numel(pilotRows),1);
for k = 1:numel(pilotRows)
    known = up;
    if k==1, known = conj(up); end
    pilotCfo(k) = localPoint(observation.rxPhysical(pilotRows(k),:),known,c);
end
pilotTimes = layout.physicalCenterTimeSec(pilotRows);
dataTimes = layout.physicalCenterTimeSec(layout.dataRows);
weight = (dataTimes-pilotTimes(1:end-1))./diff(pilotTimes);
if any(~isfinite(weight) | weight<=0 | weight>=1)
    error('EXP5Aligned:Times','Each data center must lie between its known chirps.');
end
% Frequencies are periodic modulo Fs. Interpolate the shortest signed arc,
% not a spurious path through DC if consecutive observations cross Nyquist.
m = c.samplesPerSymbol;
delta = mod(diff(pilotCfo)+m/2,m)-m/2;
alignedCfo = pilotCfo(1:end-1)+weight.*delta;
samples = complex(zeros(c.payloadSymbolCount,m));
phaseStart = angle(exp(1i*2*pi*pilotCfo(1)* ...
    layout.dataStartTimeSec(1)/c.symbolDurationSec));
previousEnd = layout.dataStartTimeSec(1);
previousCfo = pilotCfo(1);
for data = 1:c.payloadSymbolCount
    % Integrate through intervening pilot time so phase stays continuous.
    gap = layout.dataStartTimeSec(data)-previousEnd;
    phaseStart = angle(exp(1i*(phaseStart+ ...
        2*pi*previousCfo*gap/c.symbolDurationSec)));
    samples(data,:) = v4CompensateSymbol( ...
        observation.rxPhysical(layout.dataRows(data),:),phaseStart,alignedCfo(data),0,c);
    phaseStart = angle(exp(1i*(phaseStart+2*pi*alignedCfo(data))));
    previousEnd = layout.dataStartTimeSec(data)+c.symbolDurationSec;
    previousCfo = alignedCfo(data);
end
power = zeros(8,m);
for k = 1:8
    power(k,:) = abs(fft(observation.rxPhysical(k,:).*conj(up))/sqrt(m)).^2;
end
noisePower = max(median(power,'all')/log(2),eps);
decoded = v4DecodePayload(samples,c,noisePower);
result = struct('methodName','Pilot time-aligned variant (not Paper Eq17)', ...
    'algorithmVersion','Pilot-Time-Aligned-Bracket-CFO-FFT16-v1', ...
    'detectedPhysicalBins',decoded.hardPhysicalBins,'estimatedCfoBins',alignedCfo, ...
    'pilotObservationRows',pilotRows,'pilotCfoBins',pilotCfo, ...
    'leftPilotRows',pilotRows(1:end-1),'rightPilotRows',pilotRows(2:end), ...
    'pilotInterpolationWeight',weight,'usesPilotTimeInterpolation',true, ...
    'usesFuturePilot',true,'bufferedDataSymbols',1, ...
    'usesDopplerRate',true,'usesWithinSymbolRate',false, ...
    'isOriginalPaperThirdMethod',false,'usesPayloadFeedback',false, ...
    'usesPayloadTruth',false,'usesOrbitTruth',false,'usesCaseIdentity',false, ...
    'usesSnrInput',false,'usesTargetSer',false, ...
    'pointFftPaddingFactor',16,'fixedMidambleSpacingDataSymbols',1);
end

function cfo = localPoint(rx,known,c)
padding = 16;
n = padding*c.samplesPerSymbol;
[~,bin] = max(abs(fft(rx.*conj(known),n)).^2);
signed = bin-1;
if signed>=n/2, signed = signed-n; end
cfo = signed/padding;
end
