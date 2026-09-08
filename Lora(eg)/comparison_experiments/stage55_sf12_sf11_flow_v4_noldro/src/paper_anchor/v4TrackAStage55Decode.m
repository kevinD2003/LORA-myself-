function result = v4TrackAStage55Decode(packet,config,parameters)
%V4TRACKASTAGE55DECODE Causal symbol-quality VP adapter without Hamming.
s = packet.schedule; m = config.samplesPerSymbol;
point = localSamples(packet.rx,s,s.pointDownRow);
initial = v4PaperNativePointEstimate(point,config);
cfoAtStart = initial.offsetBins; rate = 0; ncoPhase = 0;
detected = nan(23,1); estimated = nan(23,1); accepted = false(23,1);
candidate = false(23,1); usedLabel = nan(23,1); appliedRow = nan(23,1);
decisionTime = nan(23,1); availableTime = nan(23,1); appliedTime = nan(23,1);
peakRatio = nan(23,1); entropy = nan(23,1); innovation = nan(23,1);
historyTime = zeros(0,1); historyCfo = zeros(0,1); historyWeight = zeros(0,1);
for row = s.quarterDownRow:numel(s.kind)
    samples = localSamples(packet.rx,s,row).';
    duration = numel(samples)/config.sampleRateHz;
    centerCfo = cfoAtStart+rate*duration/2;
    compensated = v4CompensateSymbolVariable(samples,ncoPhase,centerCfo,rate,config);
    cfoForAdvance = cfoAtStart;
    rateForAdvance = rate;
    if s.kind(row) == "data"
        data = s.dataIndex(row);
        likelihood = v4SymbolLikelihood(compensated,config,packet.noiseVariance);
        residual = v4PhaseRotationEstimate(compensated,likelihood.physicalBin,config, ...
            (-1:parameters.residualStepBins:1).');
        q = v4TrackASymbolQuality(likelihood,residual,parameters);
        detected(data) = likelihood.physicalBin;
        estimated(data) = centerCfo;
        candidate(data) = q.accept;
        peakRatio(data) = q.peakRatio;
        entropy(data) = q.entropyNormalized;
        innovation(data) = q.innovationBins;
        decisionTime(data) = s.centerTimeOffsetSec(row);
        availableTime(data) = (s.startSample(row)+s.sampleCount(row))/config.sampleRateHz;
        if q.accept
            raw = centerCfo+residual.offsetBins;
            historyTime(end+1,1) = s.centerTimeOffsetSec(row); %#ok<AGROW>
            historyCfo(end+1,1) = raw; %#ok<AGROW>
            historyWeight(end+1,1) = min(4,max(1,q.peakRatio)); %#ok<AGROW>
            if numel(historyTime) > 8
                historyTime = historyTime(end-7:end);
                historyCfo = historyCfo(end-7:end);
                historyWeight = historyWeight(end-7:end);
            end
            target = (s.startSample(row)+s.sampleCount(row))/config.sampleRateHz;
            [newCfo,newRate] = localFit(historyTime,historyCfo,historyWeight,target,parameters);
            accepted(data) = true;
            usedLabel(data) = likelihood.physicalBin;
            appliedRow(data) = row+1;
            if row < numel(s.kind)
                appliedTime(data) = s.startSample(row+1)/config.sampleRateHz;
            end
            cfoAtStart = newCfo;
            rate = newRate;
        else
            cfoAtStart = cfoAtStart+rate*duration;
        end
    else
        cfoAtStart = cfoAtStart+rate*duration;
    end
    phaseAdvanceCycles = cfoForAdvance*duration/config.symbolDurationSec+ ...
        0.5*rateForAdvance*duration^2/config.symbolDurationSec;
    ncoPhase = mod(ncoPhase+2*pi*phaseAdvanceCycles,2*pi);
end
result = struct('methodName','Stage55-VP-symbol-quality-SER-SF12-noLDRO-adapted', ...
    'detectedPhysicalBins',detected,'estimatedCfoBins',estimated, ...
    'vpCandidate',candidate,'virtualPilotAccepted',accepted,'vpUsedLabel',usedLabel, ...
    'decisionTimeSec',decisionTime,'availableTimeSec',availableTime, ...
    'appliedTimeSec',appliedTime,'pilotAppliedAtPhysicalRow',appliedRow, ...
    'peakRatio',peakRatio,'entropyNormalized',entropy,'innovationBins',innovation, ...
    'finalHistoryTimeSec',historyTime,'finalHistoryCfoBins',historyCfo, ...
    'initialPoint',initial,'usesHamming',false,'usesPhasePair',false, ...
    'usesTruth',false,'terminalMidambleObserved',false);
end

function compensated = v4CompensateSymbolVariable(rx,phase,cfoCenter,rate,config)
n = 0:numel(rx)-1;
time = n/config.sampleRateHz;
startCfo = cfoCenter-rate*(numel(rx)/config.sampleRateHz)/2;
cycles = startCfo*time/config.symbolDurationSec+ ...
    0.5*rate*time.^2/config.symbolDurationSec;
compensated = rx.*exp(-1i*(phase+2*pi*cycles));
end
function [center,rate] = localFit(time,cfo,weight,target,parameters)
x = time-target;
if numel(time) < 2 || range(time) <= 0
    rate = 0; center = cfo(end); return
end
design = [ones(size(x)),x];
age = (numel(time)-1:-1:0).';
weight = weight.*parameters.historyDecay.^age;
beta = localWeighted(design,cfo,weight);
for iteration = 1:2
    residual = cfo-design*beta;
    robust = min(1,parameters.huberThresholdBins./max(abs(residual),eps));
    beta = localWeighted(design,cfo,weight.*robust);
end
rate = min(parameters.maximumRateBinsPerSec,max(-parameters.maximumRateBinsPerSec,beta(2)));
center = sum(weight.*(cfo-rate*x))/sum(weight);
end
function beta = localWeighted(design,response,weight)
w = sqrt(max(weight,eps)); beta = (design.*w)\(response.*w);
end
function samples = localSamples(serial,schedule,row)
first = schedule.startSample(row)+1;
samples = serial(first:first+schedule.sampleCount(row)-1);
end
