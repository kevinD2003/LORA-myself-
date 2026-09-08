function artifact = runV4MechanismCalibration()
%RUNV4MECHANISMCALIBRATION Calibrate SF12 units without formal SER curves.

root = v4SetupPaths();
config = sf12NoLdroSf11FlowConfig();
preregistered = struct('calibrationRevision',4, ...
    'calibrationSnrDb',[-27 -25 -23 -21], ...
    'maximumValidationFalseAcceptanceRate',0.02, ...
    'minimumValidationCoverage',0.01, ...
    'cfoTrials',64,'calibrationConfidenceFramesPerSnr',12, ...
    'validationConfidenceFramesPerSnr',8, ...
    'confidenceSelectionWilsonUpper',0.02);
preregistered.dynamicCalibrationSnrDb = -24;
preregistered.maximumDynamicValidationFalseAcceptanceRate = 0.02;
preregistered.minimumDynamicValidationCoverage = 0.01;

searchStepBins = 0.025;
cfoError = localCfoErrors(config,config.seeds.mechanismNoiseBase, ...
    preregistered.cfoTrials,-25,searchStepBins);
singleSymbolCfoStdBins = std(cfoError,0);
absoluteCfo = sort(abs(cfoError));
q99 = absoluteCfo(max(1,ceil(0.99*numel(absoluteCfo))));

parameters = struct('searchStepBins',searchStepBins, ...
    'residualSearchBins',(-0.5:searchStepBins:0.5).', ...
    'historyDecay',0.85, ...
    'huberThresholdBins',max(2.5*median(abs(cfoError)),searchStepBins), ...
    'residualPeakRatioThreshold',1.05, ...
    'decisionPeakRatioThreshold',1.05, ...
    'innovationLimitBins',min(0.49,max(0.05,1.5*q99)), ...
    'singleSymbolInnovationGain',NaN, ...
    'phasePairInnovationGain',0.60, ...
    'phasePairInnovationLimitBins',min(0.49,max(0.05,2*q99)), ...
    'phasePairAgreementLimitBins',min(0.49,max(0.075,3*q99)), ...
    'virtualPilotCfoStdBins',max(singleSymbolCfoStdBins,searchStepBins/2), ...
    'virtualPilotRateStdLimitBinsPerSec',NaN, ...
    'rateDeviationLimitBinsPerSec',NaN, ...
    'maximumRateBinsPerSec',8.0, ...
    'confidenceAlpha',0.8, ...
    'confidenceThresholdScale',NaN, ...
    'softHammingMarginRatio',NaN, ...
    'requireSoftHardAgreement',true, ...
    'minimumCrossFrameHistoryForVirtualPilots',2, ...
    'confidenceSnrWindowDb',[-30 -21]);

bootstrapError = localBootstrapErrors(config,config.seeds.mechanismNoiseBase+1000,-25);
predictionVariance = max(var(bootstrapError,0),eps);
measurementVariance = max(singleSymbolCfoStdBins^2,eps);
parameters.singleSymbolInnovationGain = min(1,max(0.05, ...
    predictionVariance/(predictionVariance+measurementVariance)));
baselineTime = ((0:7)-mean(0:7))*7*config.symbolDurationSec;
rateStd = parameters.virtualPilotCfoStdBins/sqrt(sum(baselineTime.^2));
parameters.virtualPilotRateStdLimitBinsPerSec = 2.5*rateStd;
parameters.rateDeviationLimitBinsPerSec = max(0.05,3*rateStd);

calibrationSamples = localConfidenceSamples(config,'mechanism', ...
    preregistered.calibrationSnrDb, ...
    preregistered.calibrationConfidenceFramesPerSnr,5);
[parameters.confidenceThresholdScale,parameters.softHammingMarginRatio, ...
    calibrationGate] = localSelectConfidenceGate(calibrationSamples, ...
    preregistered.confidenceSelectionWilsonUpper);
v4ValidateReceiverParameters(parameters);

[parameters.residualPeakRatioThreshold,trackerCalibrationGate] = ...
    localSelectTrackerQualityGate(config,parameters,'mechanism',5, ...
    preregistered.dynamicCalibrationSnrDb);
parameters.decisionPeakRatioThreshold = parameters.residualPeakRatioThreshold;
v4ValidateReceiverParameters(parameters);

validationSamples = localConfidenceSamples(config,'validation', ...
    preregistered.calibrationSnrDb, ...
    preregistered.validationConfidenceFramesPerSnr,5);
validationGate = localScoreGate(validationSamples, ...
    parameters.confidenceThresholdScale,parameters.softHammingMarginRatio);
trackerValidationGate = localDynamicPilotAudit(config,parameters, ...
    'validation',5,preregistered.dynamicCalibrationSnrDb,4);
validationPassed = validationGate.falseAcceptanceRate <= ...
    preregistered.maximumValidationFalseAcceptanceRate && ...
    validationGate.coverage >= preregistered.minimumValidationCoverage && ...
    trackerValidationGate.falseAcceptanceRate <= ...
        preregistered.maximumDynamicValidationFalseAcceptanceRate && ...
    trackerValidationGate.coverage >= ...
        preregistered.minimumDynamicValidationCoverage;
if ~validationPassed
    error('V4:CalibrationValidation', ...
        ['Independent confidence validation failed; do not freeze parameters. ' ...
        'falseAcceptance=%.6f coverage=%.6f (limits %.6f / %.6f).'], ...
        validationGate.falseAcceptanceRate,validationGate.coverage, ...
        preregistered.maximumValidationFalseAcceptanceRate, ...
        preregistered.minimumValidationCoverage);
end

rician = v4RicianCoefficient(config,config.seeds.mechanismChannelBase+1,50000);
ricianMeanPower = mean(abs(rician).^2);
stream = RandStream('mt19937ar','Seed',config.seeds.mechanismNoiseBase+2000);
awgn = (randn(stream,100000,1)+1i*randn(stream,100000,1))/sqrt(2);
awgnMeanPower = mean(abs(awgn).^2);
if abs(ricianMeanPower-1) > 0.02 || abs(awgnMeanPower-1) > 0.02
    error('V4:ChannelCalibration','Rician or AWGN unit-power mechanism failed.');
end

signature = v4AlgorithmSignature(root,parameters);
identity = struct('physicalSf',12,'effectiveDataSf',10, ...
    'dataAlphabetSize',1024,'dataBinSpacing',4,'bandwidthHz',125000, ...
    'sampleRateHz',125000,'samplesPerSymbol',4096, ...
    'symbolDurationSec',0.032768,'codingRate',3,'hammingBlocks',16, ...
    'payloadSymbols',112,'informationBits',640,'bootstrapUpchirps',8, ...
    'stage55MaxIterations',5,'rollingHistoryLength',8, ...
    'paperInterval',3,'ricianKDb',10,'usesOrbitPrior',false);
manifest = struct('schemaVersion',1,'status','frozen', ...
    'frozenAt','2026-09-04T00:00:00+08:00', ...
    'selectionEvidence','mechanism CFO/confidence/rate only; no formal SER or paper marker', ...
    'identity',identity,'calibratedParameters',parameters, ...
    'algorithmSignature',signature);
artifact = struct('preregistered',preregistered,'parameters',parameters, ...
    'cfoErrorBins',cfoError,'bootstrapErrorBins',bootstrapError, ...
    'calibrationGate',calibrationGate,'validationGate',validationGate, ...
    'trackerCalibrationGate',trackerCalibrationGate, ...
    'trackerValidationGate',trackerValidationGate, ...
    'validationPassed',validationPassed,'ricianMeanPower',ricianMeanPower, ...
    'awgnMeanPower',awgnMeanPower,'algorithmSignature',signature);

calibrationDir = fullfile(root,'results','calibration');
validationDir = fullfile(root,'results','validation');
if ~isfolder(calibrationDir), mkdir(calibrationDir); end
if ~isfolder(validationDir), mkdir(validationDir); end
save(fullfile(calibrationDir,'v4_mechanism_calibration.mat'),'artifact','-v7.3');
save(fullfile(validationDir,'v4_parameter_validation.mat'),'artifact','-v7.3');
localWriteText(fullfile(root,'config','receiverParameterManifest.json'),jsonencode(manifest));
localWriteText(fullfile(calibrationDir,'v4_mechanism_calibration.json'),jsonencode(artifact));
fprintf('V4 calibration frozen: falseAcceptance=%.6f coverage=%.6f\n', ...
    validationGate.falseAcceptanceRate,validationGate.coverage);
fprintf('V4 dynamic VP validation: falseAcceptance=%.6f coverage=%.6f\n', ...
    trackerValidationGate.falseAcceptanceRate,trackerValidationGate.coverage);
end

function errorBins = localCfoErrors(config,seedBase,count,snrDb,step)
errorBins = zeros(count,1);
waveform = v4ModulateSymbol(0,config);
n = 0:config.samplesPerSymbol-1;
for trial = 1:count
    stream = RandStream('mt19937ar','Seed',seedBase+trial);
    trueCfo = -0.4+0.8*rand(stream);
    phase = 2*pi*rand(stream);
    noiseVariance = 10^(-snrDb/10);
    noise = sqrt(noiseVariance/2)*(randn(stream,size(waveform))+ ...
        1i*randn(stream,size(waveform)));
    rx = waveform.*exp(1i*(phase+2*pi*trueCfo*n/config.samplesPerSymbol))+noise;
    estimate = v4PhaseRotationEstimate(rx,0,config,(-0.5:step:0.5).');
    errorBins(trial) = estimate.offsetBins-trueCfo;
end
end

function errorBins = localBootstrapErrors(config,seedBase,snrDb)
count = 16;
errorBins = zeros(count,1);
waveform = v4ModulateSymbol(0,config);
n = 0:config.bootstrapPilotCount*config.samplesPerSymbol-1;
for trial = 1:count
    stream = RandStream('mt19937ar','Seed',seedBase+trial);
    trueCfo = -0.4+0.8*rand(stream);
    phase = 2*pi*rand(stream);
    serial = repmat(waveform,1,config.bootstrapPilotCount).* ...
        exp(1i*(phase+2*pi*trueCfo*n/config.samplesPerSymbol));
    noiseVariance = 10^(-snrDb/10);
    serial = serial+sqrt(noiseVariance/2)*(randn(stream,size(serial))+ ...
        1i*randn(stream,size(serial)));
    rx = reshape(serial,config.samplesPerSymbol,config.bootstrapPilotCount).';
    estimate = v4CommonBootstrap(rx,config,SearchStepBins=0.025);
    errorBins(trial) = mean(estimate.cfoBins)-trueCfo;
end
end

function samples = localConfidenceSamples(config,scope,snrValues,framesPerSnr,passIndex)
scoreRatio = zeros(0,1);
marginRatio = zeros(0,1);
wrong = false(0,1);
agreement = false(0,1);
for snrIndex = 1:numel(snrValues)
    for frameIndex = 1:framesPerSnr
        ledger = v4RandomLedger(config,scope,snrIndex,passIndex,frameIndex);
        payload = v4GeneratePayload(config,ledger.payloadSeed);
        stream = RandStream('mt19937ar','Seed',ledger.noiseSeed);
        rx = complex(zeros(config.payloadSymbolCount,config.samplesPerSymbol));
        variance = 10^(-snrValues(snrIndex)/10);
        for row = 1:config.payloadSymbolCount
            waveform = v4ModulateSymbol(payload.physicalBins(row),config);
            noise = sqrt(variance/2)*(randn(stream,size(waveform))+ ...
                1i*randn(stream,size(waveform)));
            rx(row,:) = waveform+noise;
        end
        decoded = v4DecodePayload(rx,config,variance*config.dataBinSpacing);
        score = sum(abs(decoded.bitLlr).^2,2);
        tau = localGlobalTau(score,config,0.8);
        scoreRatio = [scoreRatio;score./max(tau,eps)]; %#ok<AGROW>
        marginRatio = [marginRatio;decoded.symbolCodewordMargin./max(tau,eps)]; %#ok<AGROW>
        wrong = [wrong;decoded.hardPhysicalBins ~= payload.physicalBins]; %#ok<AGROW>
        agreement = [agreement;decoded.softReencodedPhysicalBins == ...
            decoded.hardPhysicalBins]; %#ok<AGROW>
    end
end
samples = struct('scoreRatio',scoreRatio,'marginRatio',marginRatio, ...
    'wrong',wrong,'agreement',agreement);
end

function tau = localGlobalTau(score,config,alpha)
tau = zeros(size(score));
globalTau = NaN;
for block = 1:config.hammingBlockCount
    rows = (block-1)*7+(1:7);
    local = mean(score(rows))+std(score(rows),0);
    if ~isfinite(globalTau), globalTau = local; ...
    else, globalTau = alpha*globalTau+(1-alpha)*local; end
    tau(rows) = globalTau;
end
end

function [scale,margin,selected] = localSelectConfidenceGate(samples,maximumWilsonUpper)
scales = [0.8 1.0 1.2 1.5 2.0 2.5 3.0 4.0];
margins = [0 0.01 0.025 0.05 0.10 0.20 0.35 0.50];
bestCoverage = -Inf;
scale = scales(end);
margin = margins(end);
selected = struct();
for s = scales
    for m = margins
        scored = localScoreGate(samples,s,m);
        if scored.falseAcceptanceWilsonUpper <= maximumWilsonUpper && ...
                scored.coverage > bestCoverage
            bestCoverage = scored.coverage;
            scale = s;
            margin = m;
            selected = scored;
        end
    end
end
if isempty(fieldnames(selected))
    error('V4:ConfidenceCalibration','No confidence gate met the calibration false-acceptance gate.');
end
end

function scored = localScoreGate(samples,scale,margin)
accepted = samples.scoreRatio >= scale & samples.marginRatio >= margin & ...
    samples.agreement;
acceptedCount = sum(accepted);
falseCount = sum(accepted & samples.wrong);
scored = struct('thresholdScale',scale,'marginRatio',margin, ...
    'acceptedCount',acceptedCount,'candidateCount',numel(accepted), ...
    'falseAcceptedCount',falseCount, ...
    'coverage',acceptedCount/numel(accepted), ...
    'falseAcceptanceRate',falseCount/max(acceptedCount,1), ...
    'falseAcceptanceWilsonUpper',localWilsonUpper(falseCount,acceptedCount));
end

function [threshold,selected] = localSelectTrackerQualityGate(config,parameters,scope,passIndex,snrDb)
thresholds = [1.05 1.10 1.20];
bestCoverage = -Inf;
threshold = thresholds(end);
selected = struct();
for candidate = thresholds
    trial = parameters;
    trial.residualPeakRatioThreshold = candidate;
    trial.decisionPeakRatioThreshold = candidate;
    scored = localDynamicPilotAudit(config,trial,scope,passIndex,snrDb,8);
    fprintf(['dynamic calibration peak=%.2f accepted=%d false=%d ' ...
        'coverage=%.6f wilsonUpper=%.6f\n'],candidate,scored.acceptedCount, ...
        scored.falseAcceptedCount,scored.coverage, ...
        scored.falseAcceptanceWilsonUpper);
    if scored.falseAcceptanceWilsonUpper <= 0.05 && scored.coverage > bestCoverage
        threshold = candidate;
        selected = scored;
        bestCoverage = scored.coverage;
    end
end
if isempty(fieldnames(selected))
    error('V4:TrackerCalibration', ...
        'No dynamic VP quality threshold met the calibration gate.');
end
end

function scored = localDynamicPilotAudit(config,parameters,scope,passIndex,snrDb,framesPerRegion)
schedule = v4ContinuousPassSchedule(config);
trajectory = v4Trajectory(schedule.frameCenterTimeSec,config);
rate = abs(trajectory.dopplerRateHzPerSec/config.fftBinSpacingHz);
eligible = find(schedule.metricEligible & schedule.frameCenterTimeSec < 0);
[~,order] = sort(rate(eligible),'ascend');
lowFrames = eligible(order(1:framesPerRegion));
highFrames = eligible(order(end-framesPerRegion+1:end));
chosenByRegion = {sort(lowFrames(:)),sort(highFrames(:))};
acceptedCount = 0;
falseCount = 0;
candidateCount = 2*framesPerRegion*config.payloadSymbolCount;
ledgerIndex = 0;
for regionIndex = 1:2
    crossFrameState = struct();
    chosen = chosenByRegion{regionIndex};
    for index = 1:numel(chosen)
        ledgerIndex = ledgerIndex+1;
        scheduleFrame = chosen(index);
        ledger = v4RandomLedger(config,scope,1,passIndex,ledgerIndex);
        frame = v4GenerateContinuousFrame(config, ...
            schedule.frameStartTimeSec(scheduleFrame),snrDb,ledger,0.7);
        bootstrap = v4CommonBootstrap(frame.observation.rxPhysical(1:8,:),config, ...
            SearchStepBins=parameters.searchStepBins);
        measurementTime = schedule.frameStartTimeSec(scheduleFrame)+ ...
            4*config.symbolDurationSec;
        [crossRate,crossFrameState] = v4CrossFrameRateUpdate(crossFrameState, ...
            measurementTime,mean(bootstrap.cfoBins),bootstrap.rateBinsPerSec, ...
            config,parameters);
        receiver = v4Stage55Decode(frame.observation,bootstrap,config,parameters, ...
            CrossFrameRateBinsPerSec=crossRate, ...
            CrossFrameHistoryCount=crossFrameState.historyCount);
        accepted = receiver.virtualPilotAccepted;
        acceptedCount = acceptedCount+sum(accepted);
        falseCount = falseCount+sum(accepted & ...
            receiver.detectedPhysicalBins ~= frame.truth.payloadPhysicalBins);
    end
end
scored = struct('acceptedCount',acceptedCount,'candidateCount',candidateCount, ...
    'falseAcceptedCount',falseCount,'coverage',acceptedCount/candidateCount, ...
    'falseAcceptanceRate',falseCount/max(acceptedCount,1), ...
    'falseAcceptanceWilsonUpper',localWilsonUpper(falseCount,acceptedCount), ...
    'framesPerRegion',framesPerRegion,'snrDb',snrDb);
end

function upper = localWilsonUpper(errors,count)
if count == 0
    upper = 1;
    return
end
z = 1.95996398454005;
p = errors/count;
denominator = 1+z^2/count;
center = p+z^2/(2*count);
radius = z*sqrt(p*(1-p)/count+z^2/(4*count^2));
upper = (center+radius)/denominator;
end

function localWriteText(path,text)
file = fopen(path,'w');
if file < 0, error('V4:WriteArtifact','Cannot write %s.',path); end
cleanup = onCleanup(@()fclose(file));
fprintf(file,'%s\n',text);
clear cleanup
end
