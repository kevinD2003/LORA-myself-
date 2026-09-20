function [summary,audit] = simulate_ideal_compensation(config,stageConfig,theorySer)
%SIMULATE_IDEAL_COMPENSATION Fresh full-frame Case A/B Monte Carlo audit.
% The physical frame is generated with the Stage55 coding/layout/waveform
% functions.  Exact continuous Doppler is applied, complex AWGN is added,
% and the same Doppler phase is then removed sample by sample.

layout = v4BuildFrameLayout(stageConfig);
m = stageConfig.samplesPerSymbol;
baseUpchirp = v4ModulateSymbol(0,stageConfig);
sampleIndex = 0:m-1;
caseCount = numel(config.caseStartTimeSec);
snrCount = numel(config.snrAnchorDb);
carriers = cell(caseCount,1);
caseAudit = repmat(struct(),caseCount,1);

for caseIndex = 1:caseCount
    totalSamples = layout.physicalSymbolCount*m;
    timeSec = config.caseStartTimeSec(caseIndex)+ ...
        (0:totalSamples-1).'/stageConfig.sampleRateHz;
    orbit = v4TrackAOrbit(timeSec,stageConfig);
    dopplerPhase = [0;cumsum(pi/stageConfig.sampleRateHz.* ...
        (orbit.dopplerHz(1:end-1)+orbit.dopplerHz(2:end)))];
    carriers{caseIndex} = exp(1i*reshape( ...
        dopplerPhase,m,layout.physicalSymbolCount).');

    payload = v4GeneratePayload(stageConfig,localSeed(config,1,caseIndex,1,1));
    tx = localBuildFrame(payload,layout,baseUpchirp,sampleIndex,m);
    clean = tx.*carriers{caseIndex};
    compensated = clean.*conj(carriers{caseIndex});
    detected = localDetect(compensated(layout.dataRows,:),baseUpchirp);
    waveformError = max(abs(compensated(:)-tx(:)));
    caseAudit(caseIndex).caseName = char(config.caseNames(caseIndex));
    caseAudit(caseIndex).caseStartTimeSec = config.caseStartTimeSec(caseIndex);
    caseAudit(caseIndex).initialDopplerHz = orbit.dopplerHz(1);
    caseAudit(caseIndex).finalDopplerHz = orbit.dopplerHz(end);
    caseAudit(caseIndex).maximumCompensatedWaveformError = waveformError;
    caseAudit(caseIndex).noiselessSymbolErrors = ...
        sum(detected~=payload.physicalBins);
    clear tx clean compensated orbit dopplerPhase timeSec
end

rowCount = caseCount*snrCount;
caseName = strings(rowCount,1);
caseStartTimeSec = zeros(rowCount,1);
snrDb = zeros(rowCount,1);
packets = repmat(config.validationPacketsPerCaseSnr,rowCount,1);
symbolErrors = zeros(rowCount,1);
symbolCount = zeros(rowCount,1);
serMonteCarlo = zeros(rowCount,1);
serTheory = zeros(rowCount,1);
ciLower = zeros(rowCount,1);
ciUpper = zeros(rowCount,1);
noisePowerMeasured = zeros(rowCount,1);
noisePowerExpected = zeros(rowCount,1);
theoryInsideConfidenceInterval = false(rowCount,1);
row = 0;

for caseIndex = 1:caseCount
    carrier = carriers{caseIndex};
    for snrIndex = 1:snrCount
        row = row+1;
        variance = 10^(-config.snrAnchorDb(snrIndex)/10);
        errors = 0;
        total = 0;
        noiseEnergy = 0;
        noiseSamples = 0;
        for packetIndex = 1:config.validationPacketsPerCaseSnr
            payloadSeed = localSeed(config,2,caseIndex,snrIndex,packetIndex);
            noiseSeed = localSeed(config,3,caseIndex,snrIndex,packetIndex);
            payload = v4GeneratePayload(stageConfig,payloadSeed);
            tx = localBuildFrame(payload,layout,baseUpchirp,sampleIndex,m);
            stream = RandStream(config.randomGenerator,'Seed',noiseSeed);
            noise = sqrt(variance/2).*(randn(stream,size(tx))+ ...
                1i*randn(stream,size(tx)));
            received = tx.*carrier+noise;
            compensated = received.*conj(carrier);
            detected = localDetect(compensated(layout.dataRows,:),baseUpchirp);
            errors = errors+sum(detected~=payload.physicalBins);
            total = total+stageConfig.payloadSymbolCount;
            noiseEnergy = noiseEnergy+sum(abs(noise(:)).^2);
            noiseSamples = noiseSamples+numel(noise);
        end
        estimate = errors/total;
        [lower,upper] = localWilson(errors,total,config.confidenceZ);
        caseName(row) = config.caseNames(caseIndex);
        caseStartTimeSec(row) = config.caseStartTimeSec(caseIndex);
        snrDb(row) = config.snrAnchorDb(snrIndex);
        symbolErrors(row) = errors;
        symbolCount(row) = total;
        serMonteCarlo(row) = estimate;
        serTheory(row) = theorySer(snrIndex);
        ciLower(row) = lower;
        ciUpper(row) = upper;
        noisePowerMeasured(row) = noiseEnergy/noiseSamples;
        noisePowerExpected(row) = variance;
        theoryInsideConfidenceInterval(row) = ...
            theorySer(snrIndex)>=lower && theorySer(snrIndex)<=upper;
        fprintf('%s, SNR %g dB: %d/%d symbol errors\n', ...
            config.caseNames(caseIndex),config.snrAnchorDb(snrIndex), ...
            errors,total);
    end
end

summary = table(caseName,caseStartTimeSec,snrDb,packets,symbolErrors, ...
    symbolCount,serMonteCarlo,serTheory,ciLower,ciUpper, ...
    theoryInsideConfidenceInterval,noisePowerMeasured,noisePowerExpected);
audit = struct('caseAudit',caseAudit, ...
    'physicalSymbolCount',layout.physicalSymbolCount, ...
    'payloadSymbolCount',stageConfig.payloadSymbolCount, ...
    'fullFrameTimelineUsed',true,'continuousDopplerPhaseUsed',true, ...
    'complexAwgnUsed',true,'perfectSamplewiseCompensationUsed',true);
end

function tx = localBuildFrame(payload,layout,baseUpchirp,sampleIndex,m)
bins = zeros(layout.physicalSymbolCount,1);
bins(layout.dataRows) = payload.physicalBins;
tones = exp(1i*(2*pi/m).*(bins*sampleIndex));
tx = tones.*baseUpchirp;
end

function detected = localDetect(rxData,baseUpchirp)
spectrum = fft(rxData.*conj(baseUpchirp),[],2);
[~,peak] = max(abs(spectrum).^2,[],2);
detected = peak-1;
end

function seed = localSeed(config,domain,caseIndex,snrIndex,packetIndex)
seed = config.baseSeed+domain*100000000+caseIndex*1000000+ ...
    snrIndex*10000+packetIndex;
end

function [lower,upper] = localWilson(errors,total,z)
estimate = errors/total;
denominator = 1+z^2/total;
center = (estimate+z^2/(2*total))/denominator;
halfWidth = z/denominator*sqrt(estimate*(1-estimate)/total+ ...
    z^2/(4*total^2));
lower = max(0,center-halfWidth);
upper = min(1,center+halfWidth);
end
