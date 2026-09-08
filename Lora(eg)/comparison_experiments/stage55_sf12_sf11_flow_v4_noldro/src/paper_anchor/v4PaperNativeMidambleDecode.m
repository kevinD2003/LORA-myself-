function result = v4PaperNativeMidambleDecode(packet,config,pointOnly)
%V4PAPERNATIVEMIDAMBLEDECODE Causal piecewise-constant integer-bin receiver.
if nargin < 3, pointOnly = false; end
s = packet.schedule; m = config.samplesPerSymbol;
point = localSamples(packet.rx,s,s.pointDownRow);
initial = v4PaperNativePointEstimate(point,config);
current = initial.offsetBins; ncoPhase = 0;
detected = nan(23,1); estimated = nan(23,1); midambleResidual = nan(8,1);
midambleApplied = false(8,1); terminalEstimate = NaN;
for row = s.quarterDownRow:numel(s.kind)
    samples = localSamples(packet.rx,s,row).';
    n = 0:numel(samples)-1;
    compensated = samples.*exp(-1i*(ncoPhase+2*pi*current*n/m));
    cfoForAdvance = current;
    if s.kind(row) == "data"
        data = s.dataIndex(row);
        decision = v4SymbolLikelihood(compensated,config,packet.noiseVariance);
        detected(data) = decision.physicalBin;
        estimated(data) = current;
    elseif s.kind(row) == "midamble"
        mid = s.midambleIndex(row);
        residual = localIntegerUpchirpResidual(compensated,config);
        midambleResidual(mid) = residual;
        if row == s.terminalMidambleRow
            terminalEstimate = current+residual;
        elseif ~pointOnly
            current = current+residual;
            midambleApplied(mid) = true;
        end
    end
    ncoPhase = mod(ncoPhase+2*pi*cfoForAdvance*numel(samples)/m,2*pi);
end
result = struct('methodName',ternary(pointOnly, ...
    'Paper-Point-native-SF12-noLDRO','Paper-Midamble-Point-native-SF12-noLDRO'), ...
    'detectedPhysicalBins',detected,'estimatedCfoBins',estimated, ...
    'initialPoint',initial,'midambleResidualBins',midambleResidual, ...
    'midambleApplied',midambleApplied,'terminalEstimateBins',terminalEstimate, ...
    'terminalAffectsPayload',false,'estimatorResolution','integer-fft-bin', ...
    'usesSubBinEstimator',false,'usesTruth',false);
end

function samples = localSamples(serial,schedule,row)
first = schedule.startSample(row)+1;
samples = serial(first:first+schedule.sampleCount(row)-1);
end
function value = localIntegerUpchirpResidual(samples,config)
down = conj(v4ModulateSymbol(0,config));
spectrum = fft(samples.*down);
[~,index] = max(abs(spectrum).^2);
value = index-1;
if value >= config.samplesPerSymbol/2, value = value-config.samplesPerSymbol; end
end
function value = ternary(condition,a,b)
if condition, value = a; else, value = b; end
end
