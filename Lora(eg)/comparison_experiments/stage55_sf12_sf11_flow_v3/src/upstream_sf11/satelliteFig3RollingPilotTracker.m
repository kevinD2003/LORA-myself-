function result = satelliteFig3RollingPilotTracker(rxSymbols, config, knownWaveformBins, options)
%SATELLITEFIG3ROLLINGPILOTTRACKER Causal 8-slot virtual-pilot Doppler tracker.
%   The first eight known preamble symbols initialise a ring buffer.  Each
%   payload update is optional; a reliable virtual pilot replaces only the
%   oldest slot, so the active fitting history always has at most eight
%   observations.  No payload truth is accepted by this interface.

arguments
    rxSymbols (:,:) double
    config (1,1) struct
    knownWaveformBins (:,1) double
    options.AcceptedMask (:,1) logical = false(0,1)
    options.PilotConfidence (:,1) double = nan(0,1)
    options.PilotThreshold (1,1) double = NaN
    options.DecisionWaveformBins (:,1) double = nan(0,1)
    options.PilotAvailabilityRows (:,1) double = nan(0,1)
    options.InnovationLimitBins (1,1) double {mustBeNonnegative} = Inf
    options.FreezeBootstrapRate (1,1) logical = false
    options.ReleaseBootstrapRateAfterVirtualPilotCount (1,1) double ...
        {mustBeInteger,mustBeNonnegative} = 1e9
    options.RateDeviationLimitBinsPerSec (1,1) double ...
        {mustBeNonnegative} = Inf
    options.BootstrapRateOverrideBinsPerSec (1,1) double = NaN
    options.BootstrapOverride (1,1) struct = struct()
    options.ForceAccept (1,1) logical = false
    options.ApplyVirtualPilotPhaseCorrection (1,1) logical = true
    options.VirtualPilotInnovationGain (1,1) double ...
        {mustBeNonnegative} = 1
    options.EnableVirtualPilotPhasePairCfo (1,1) logical = false
    options.VirtualPilotPhasePairInnovationGain (1,1) double ...
        {mustBeNonnegative} = 1
    options.PhasePairInnovationLimitBins (1,1) double ...
        {mustBeNonnegative} = Inf
    options.PhasePairAgreementLimitBins (1,1) double ...
        {mustBeNonnegative} = Inf
    options.UseObservableVirtualPilotRate (1,1) logical = false
    options.VirtualPilotCfoStdBins (1,1) double ...
        {mustBePositive} = 0.075
    options.VirtualPilotRateStdLimitBinsPerSec (1,1) double ...
        {mustBePositive} = 0.1
end

if options.VirtualPilotInnovationGain > 1 || ...
        options.VirtualPilotPhasePairInnovationGain > 1
    error('SatelliteFig3:VirtualPilotInnovationGain', ...
        'Virtual-pilot innovation gains must be in [0,1].');
end

nSymbols = size(rxSymbols,1);
m = config.samplesPerSymbol;
bootstrapCount = numel(knownWaveformBins);
if size(rxSymbols,2) ~= m || bootstrapCount < 2 || bootstrapCount >= nSymbols
    error('SatelliteFig3:TrackerShape','Invalid waveform or bootstrap dimensions.');
end
if isempty(options.AcceptedMask)
    requested = false(nSymbols,1);
else
    requested = options.AcceptedMask;
    if numel(requested) ~= nSymbols
        error('SatelliteFig3:TrackerMask','AcceptedMask must match the frame.');
    end
end
requested(1:bootstrapCount) = true;
confidenceInput = nan(nSymbols,1);
if ~isempty(options.PilotConfidence)
    if numel(options.PilotConfidence) ~= nSymbols
        error('SatelliteFig3:TrackerConfidence','PilotConfidence must match the frame.');
    end
    confidenceInput = options.PilotConfidence;
end
decisionInput = nan(nSymbols,1);
if ~isempty(options.DecisionWaveformBins)
    if numel(options.DecisionWaveformBins) ~= nSymbols
        error('SatelliteFig3:TrackerDecision','DecisionWaveformBins must match the frame.');
    end
    decisionInput = options.DecisionWaveformBins;
end
pilotAvailabilityRows = (1:nSymbols).';
if ~isempty(options.PilotAvailabilityRows)
    if numel(options.PilotAvailabilityRows) ~= nSymbols
        error('SatelliteFig3:TrackerAvailability', ...
            'PilotAvailabilityRows must match the frame.');
    end
    pilotAvailabilityRows = options.PilotAvailabilityRows;
    rowIndex = (1:nSymbols).';
    if any(~isfinite(pilotAvailabilityRows)) || ...
            any(pilotAvailabilityRows ~= round(pilotAvailabilityRows)) || ...
            any(pilotAvailabilityRows < rowIndex) || ...
            any(pilotAvailabilityRows > nSymbols+1)
        error('SatelliteFig3:TrackerAvailability', ...
            'Pilot availability must be an integer from its row through N+1.');
    end
end
pilotAvailabilityRows(1:bootstrapCount) = (1:bootstrapCount).';

historyLength = config.virtualPilotHistoryLength;
if bootstrapCount < historyLength
    error('SatelliteFig3:InsufficientBootstrap', ...
        'The rolling history must be initialised by at least eight preamble symbols.');
end
historyIndex = nan(historyLength,1);
historyCfo = nan(historyLength,1);
historyConfidence = nan(historyLength,1);
historyPeakRatio = nan(historyLength,1);
historyCount = 0;
nextSlot = 1;

detectedBins = nan(nSymbols,1);
hardWaveformBins = nan(nSymbols,1);
peakRatio = nan(nSymbols,1);
predictedCfoBins = nan(nSymbols,1);
predictedRateBinsPerSec = nan(nSymbols,1);
predictedPhaseStartRad = nan(nSymbols,1);
measuredCfoBins = nan(nSymbols,1);
measuredResidualBins = nan(nSymbols,1);
measuredResidualPhaseRad = nan(nSymbols,1);
residualPeakRatio = nan(nSymbols,1);
residualPeakAtBoundary = false(nSymbols,1);
residualFrequencyStdBins = nan(nSymbols,1);
rawSingleVirtualPilotCfoBins = nan(nSymbols,1);
virtualPilotMeasurementCfoBins = nan(nSymbols,1);
phasePairCandidateCfoBins = nan(nSymbols,1);
phasePairInnovationBins = nan(nSymbols,1);
phasePairAgreementBins = nan(nSymbols,1);
phasePairGapSymbols = nan(nSymbols,1);
phasePairUsed = false(nSymbols,1);
pilotAccepted = false(nSymbols,1);
pilotAppliedAtRows = nan(nSymbols,1);
activeHistoryCount = zeros(nSymbols,1);
compensationVirtualPilotCount = zeros(nSymbols,1);
compensatedSymbols = complex(zeros(size(rxSymbols)));
virtualPilotRateEvidenceRows = nan(nSymbols-bootstrapCount,1);
virtualPilotRateEvidenceCfoBins = nan(nSymbols-bootstrapCount,1);
virtualPilotRateEvidenceCount = 0;
virtualPilotRateStdBinsPerSec = inf(nSymbols,1);
virtualPilotRateObservable = false(nSymbols,1);
virtualPilotRateEstimateBinsPerSec = nan(nSymbols,1);
lastVirtualPilotPhase = struct('row',NaN,'measuredPhaseRad',NaN, ...
    'predictedPhaseRad',NaN);

if isempty(fieldnames(options.BootstrapOverride))
    bootstrap = satelliteFig3BootstrapEstimate( ...
        rxSymbols(1:bootstrapCount,:),knownWaveformBins,config);
    bootstrapWasOverridden = false;
else
    bootstrap = options.BootstrapOverride;
    localValidateBootstrapOverride(bootstrap,bootstrapCount);
    bootstrapWasOverridden = true;
end
for k = 1:bootstrapCount
    cfo = bootstrap.cfoBins(k);
    phase = bootstrap.phaseRad(k);
    predictedCfoBins(k) = cfo;
    measuredCfoBins(k) = cfo;
    measuredResidualBins(k) = cfo;
    measuredResidualPhaseRad(k) = phase;
    predictedPhaseStartRad(k) = phase;
    peakRatio(k) = bootstrap.peakRatio(k);
    residualPeakRatio(k) = bootstrap.peakRatio(k);
    detectedBins(k) = knownWaveformBins(k);
    hardWaveformBins(k) = knownWaveformBins(k);
    pilotAccepted(k) = true;
    pilotAppliedAtRows(k) = k;
    compensatedSymbols(k,:) = rxSymbols(k,:).*exp(-1i*(phase + ...
        2*pi*cfo*(0:m-1)/m));
    [historyIndex,historyCfo,historyConfidence,historyPeakRatio,nextSlot,historyCount] = ...
        localInsert(historyIndex,historyCfo,historyConfidence,historyPeakRatio, ...
        nextSlot,historyCount,k,cfo,1,max(bootstrap.peakRatio(k),1));
    activeHistoryCount(k) = historyCount;
end
% BOOTSTRAP.PHASERAD describes each known symbol at its own start.  Advance
% the final preamble estimate through that complete symbol before using it
% as the first payload start phase; otherwise the receiver silently drops
% one symbol of accumulated Doppler phase at the preamble boundary.
phaseState = bootstrap.phaseRad(end)+2*pi*bootstrap.cfoBins(end);
acceptedVirtualPilotCount = 0;
bootstrapRatePrior = min(config.maxRateBinsPerSec,max( ...
    -config.maxRateBinsPerSec,bootstrap.jointRateBinsPerSec));
if isfinite(options.BootstrapRateOverrideBinsPerSec)
    bootstrapRatePrior = min(config.maxRateBinsPerSec,max( ...
        -config.maxRateBinsPerSec, ...
        options.BootstrapRateOverrideBinsPerSec));
end

sampleTime = (0:m-1)/config.sampleRateHz;
duration = config.symbolDurationSec;
for symbolIdx = bootstrapCount+1:nSymbols
    % A SenLoRa decision for a seven-symbol Hamming block is unavailable
    % until the complete block has arrived.  Apply those stored residual
    % measurements only at the first subsequent symbol, never retroactively
    % inside the block that supplied their confidence evidence.
    delayedRows = find(requested & ...
        pilotAvailabilityRows == symbolIdx & ...
        (1:nSymbols).' < symbolIdx);
    latestCorrectionRow = -Inf;
    latestPhaseCorrection = 0;
    for delayedRow = delayedRows(:).'
        candidateBin = hardWaveformBins(delayedRow);
        if isfinite(decisionInput(delayedRow))
            candidateBin = decisionInput(delayedRow);
        end
        residual = satelliteFig3PhaseRotationEstimate( ...
            compensatedSymbols(delayedRow,:),candidateBin,config, ...
            CandidateOffsets=config.residualSearchBins,LocalOnly=true);
        measuredResidualBins(delayedRow) = residual.offsetBins;
        measuredResidualPhaseRad(delayedRow) = residual.phaseRad;
        residualPeakRatio(delayedRow) = residual.peakRatio;
        residualPeakAtBoundary(delayedRow) = residual.peakAtBoundary;
        residualFrequencyStdBins(delayedRow) = residual.frequencyStdBins;
        accepted = options.ForceAccept || ( ...
            residual.peakRatio >= config.residualPeakRatioThreshold && ...
            ~residual.peakAtBoundary && ...
            abs(residual.offsetBins) <= options.InnovationLimitBins && ...
            peakRatio(delayedRow) >= config.decisionPeakRatioThreshold);
        if accepted
            rawSingle = predictedCfoBins(delayedRow)+residual.offsetBins;
            [measured,pairDiagnostic,lastVirtualPilotPhase] = ...
                localVirtualPilotMeasurement(delayedRow, ...
                predictedCfoBins(delayedRow), ...
                predictedRateBinsPerSec(delayedRow), ...
                predictedPhaseStartRad(delayedRow),residual, ...
                lastVirtualPilotPhase,config,options);
            rawSingleVirtualPilotCfoBins(delayedRow) = rawSingle;
            virtualPilotMeasurementCfoBins(delayedRow) = measured;
            phasePairCandidateCfoBins(delayedRow) = ...
                pairDiagnostic.candidateCfoBins;
            phasePairInnovationBins(delayedRow) = ...
                pairDiagnostic.innovationBins;
            phasePairAgreementBins(delayedRow) = ...
                pairDiagnostic.agreementBins;
            phasePairGapSymbols(delayedRow) = pairDiagnostic.gapSymbols;
            phasePairUsed(delayedRow) = pairDiagnostic.used;
            measuredCfoBins(delayedRow) = measured;
            confidence = confidenceInput(delayedRow);
            if ~isfinite(confidence)
                confidence = 1;
            end
            [historyIndex,historyCfo,historyConfidence,historyPeakRatio,nextSlot,historyCount] = ...
                localInsert(historyIndex,historyCfo,historyConfidence,historyPeakRatio, ...
                nextSlot,historyCount,delayedRow,measured,confidence,residual.peakRatio);
            virtualPilotRateEvidenceCount = ...
                virtualPilotRateEvidenceCount+1;
            virtualPilotRateEvidenceRows(virtualPilotRateEvidenceCount) = ...
                delayedRow;
            virtualPilotRateEvidenceCfoBins(virtualPilotRateEvidenceCount) = ...
                rawSingle;
            acceptedVirtualPilotCount = acceptedVirtualPilotCount+1;
            pilotAccepted(delayedRow) = true;
            pilotAppliedAtRows(delayedRow) = symbolIdx;
            if delayedRow > latestCorrectionRow
                latestCorrectionRow = delayedRow;
                ageSymbols = symbolIdx-delayedRow;
                latestPhaseCorrection = residual.phaseRad + ...
                    2*pi*residual.offsetBins*ageSymbols;
            end
        end
    end
    if options.ApplyVirtualPilotPhaseCorrection && ...
            isfinite(latestCorrectionRow)
        phaseState = phaseState+latestPhaseCorrection;
    end

    % Only observations already present before the current compensation
    % count here.  A virtual pilot accepted from this symbol can affect
    % later symbols, never itself.
    compensationVirtualPilotCount(symbolIdx) = sum( ...
        isfinite(historyIndex) & historyIndex > bootstrapCount);

    fitRatePrior = bootstrapRatePrior;
    if options.UseObservableVirtualPilotRate
        [vpRate,vpRateStd] = localVirtualPilotRate( ...
            virtualPilotRateEvidenceRows(1:virtualPilotRateEvidenceCount), ...
            virtualPilotRateEvidenceCfoBins(1:virtualPilotRateEvidenceCount), ...
            config,options.VirtualPilotCfoStdBins);
        vpRateIsObservable = isfinite(vpRate) && ...
            vpRateStd <= options.VirtualPilotRateStdLimitBinsPerSec;
        if vpRateIsObservable
            fitRatePrior = min(bootstrapRatePrior+ ...
                options.RateDeviationLimitBinsPerSec,max( ...
                bootstrapRatePrior-options.RateDeviationLimitBinsPerSec, ...
                vpRate));
        end
        freezeCurrentRate = true;
        virtualPilotRateStdBinsPerSec(symbolIdx) = vpRateStd;
        virtualPilotRateObservable(symbolIdx) = vpRateIsObservable;
        virtualPilotRateEstimateBinsPerSec(symbolIdx) = vpRate;
    else
        freezeCurrentRate = options.FreezeBootstrapRate && ...
            acceptedVirtualPilotCount < ...
            options.ReleaseBootstrapRateAfterVirtualPilotCount;
    end
    [predictedCenter,predictedRate] = localFit(historyIndex,historyCfo, ...
        historyConfidence,historyPeakRatio,symbolIdx,config, ...
        options.PilotThreshold,fitRatePrior, ...
        freezeCurrentRate,options.RateDeviationLimitBinsPerSec);
    predictedCfoBins(symbolIdx) = predictedCenter;
    predictedRateBinsPerSec(symbolIdx) = predictedRate;
    predictedPhaseStartRad(symbolIdx) = phaseState;
    startCfo = predictedCenter-predictedRate*duration/2;
    phaseCycles = startCfo*(sampleTime/duration) + ...
        0.5*predictedRate*(sampleTime.^2/duration);
    compensated = rxSymbols(symbolIdx,:).*exp(-1i*(phaseState+2*pi*phaseCycles));
    compensatedSymbols(symbolIdx,:) = compensated;
    hard = satelliteFig3HardDecision(compensated,config);
    hardWaveformBins(symbolIdx) = hard.waveformBin;
    peakRatio(symbolIdx) = hard.peakRatio;
    candidateBin = hard.waveformBin;
    if isfinite(decisionInput(symbolIdx))
        candidateBin = decisionInput(symbolIdx);
    end
    detectedBins(symbolIdx) = candidateBin;

    accepted = false;
    if requested(symbolIdx) && pilotAvailabilityRows(symbolIdx) <= symbolIdx
        residual = satelliteFig3PhaseRotationEstimate(compensated,candidateBin,config, ...
            CandidateOffsets=config.residualSearchBins,LocalOnly=true);
        measuredResidualBins(symbolIdx) = residual.offsetBins;
        measuredResidualPhaseRad(symbolIdx) = residual.phaseRad;
        residualPeakRatio(symbolIdx) = residual.peakRatio;
        residualPeakAtBoundary(symbolIdx) = residual.peakAtBoundary;
        residualFrequencyStdBins(symbolIdx) = residual.frequencyStdBins;
        accepted = options.ForceAccept || ( ...
            residual.peakRatio >= config.residualPeakRatioThreshold && ...
            ~residual.peakAtBoundary && ...
            abs(residual.offsetBins) <= options.InnovationLimitBins && ...
            hard.peakRatio >= config.decisionPeakRatioThreshold);
        if accepted
            rawSingle = predictedCenter+residual.offsetBins;
            [measured,pairDiagnostic,lastVirtualPilotPhase] = ...
                localVirtualPilotMeasurement(symbolIdx,predictedCenter, ...
                predictedRate,predictedPhaseStartRad(symbolIdx), ...
                residual,lastVirtualPilotPhase,config,options);
            rawSingleVirtualPilotCfoBins(symbolIdx) = rawSingle;
            virtualPilotMeasurementCfoBins(symbolIdx) = measured;
            phasePairCandidateCfoBins(symbolIdx) = ...
                pairDiagnostic.candidateCfoBins;
            phasePairInnovationBins(symbolIdx) = ...
                pairDiagnostic.innovationBins;
            phasePairAgreementBins(symbolIdx) = ...
                pairDiagnostic.agreementBins;
            phasePairGapSymbols(symbolIdx) = pairDiagnostic.gapSymbols;
            phasePairUsed(symbolIdx) = pairDiagnostic.used;
            measuredCfoBins(symbolIdx) = measured;
            confidence = confidenceInput(symbolIdx);
            if ~isfinite(confidence)
                confidence = 1;
            end
            [historyIndex,historyCfo,historyConfidence,historyPeakRatio,nextSlot,historyCount] = ...
                localInsert(historyIndex,historyCfo,historyConfidence,historyPeakRatio, ...
                nextSlot,historyCount,symbolIdx,measured,confidence,residual.peakRatio);
            virtualPilotRateEvidenceCount = ...
                virtualPilotRateEvidenceCount+1;
            virtualPilotRateEvidenceRows(virtualPilotRateEvidenceCount) = ...
                symbolIdx;
            virtualPilotRateEvidenceCfoBins(virtualPilotRateEvidenceCount) = ...
                rawSingle;
            acceptedVirtualPilotCount = acceptedVirtualPilotCount+1;
            pilotAppliedAtRows(symbolIdx) = symbolIdx;
            if options.ApplyVirtualPilotPhaseCorrection
                % The residual phase is relative to the predicted symbol
                % start.  This diagnostic switch changes only whether the
                % accepted VP directly resets phase; the CFO observation
                % still enters the virtual-pilot history.
                phaseState = phaseState + residual.phaseRad + 2*pi*measured;
            end
        end
    end
    if ~accepted || ~options.ApplyVirtualPilotPhaseCorrection
        phaseState = phaseState + 2*pi*predictedCenter;
    end
    pilotAccepted(symbolIdx) = accepted;
    activeHistoryCount(symbolIdx) = historyCount;
end

valid = isfinite(historyIndex);
[finalHistoryIndex,order] = sort(historyIndex(valid));
finalHistoryCfo = historyCfo(valid); finalHistoryCfo = finalHistoryCfo(order);
finalHistoryConfidence = historyConfidence(valid); finalHistoryConfidence = finalHistoryConfidence(order);
finalHistoryPeakRatio = historyPeakRatio(valid); finalHistoryPeakRatio = finalHistoryPeakRatio(order);
result = struct( ...
    'detectedWaveformBins',detectedBins, ...
    'hardWaveformBins',hardWaveformBins, ...
    'peakRatio',peakRatio, ...
    'predictedCfoBins',predictedCfoBins, ...
    'predictedRateBinsPerSec',predictedRateBinsPerSec, ...
    'predictedPhaseStartRad',predictedPhaseStartRad, ...
    'measuredCfoBins',measuredCfoBins, ...
    'measuredResidualBins',measuredResidualBins, ...
    'measuredResidualPhaseRad',measuredResidualPhaseRad, ...
    'residualPeakRatio',residualPeakRatio, ...
    'residualPeakAtBoundary',residualPeakAtBoundary, ...
    'residualFrequencyStdBins',residualFrequencyStdBins, ...
    'rawSingleVirtualPilotCfoBins',rawSingleVirtualPilotCfoBins, ...
    'virtualPilotMeasurementCfoBins',virtualPilotMeasurementCfoBins, ...
    'phasePairCandidateCfoBins',phasePairCandidateCfoBins, ...
    'phasePairInnovationBins',phasePairInnovationBins, ...
    'phasePairAgreementBins',phasePairAgreementBins, ...
    'phasePairGapSymbols',phasePairGapSymbols, ...
    'phasePairUsed',phasePairUsed, ...
    'virtualPilotRateStdBinsPerSec',virtualPilotRateStdBinsPerSec, ...
    'virtualPilotRateObservable',virtualPilotRateObservable, ...
    'virtualPilotRateEstimateBinsPerSec', ...
        virtualPilotRateEstimateBinsPerSec, ...
    'virtualPilotRateEvidenceCount',virtualPilotRateEvidenceCount, ...
    'requestedMask',requested, 'pilotAccepted',pilotAccepted, ...
    'pilotAvailabilityRows',pilotAvailabilityRows, ...
    'pilotAppliedAtRows',pilotAppliedAtRows, ...
    'activeHistoryCount',activeHistoryCount, ...
    'compensationVirtualPilotCount',compensationVirtualPilotCount, ...
    'compensatedSymbols',compensatedSymbols, ...
    'bootstrap',bootstrap, ...
    'bootstrapWasOverridden',bootstrapWasOverridden, ...
    'bootstrapRatePriorBinsPerSec',bootstrapRatePrior, ...
    'bootstrapRateWasOverridden', ...
        isfinite(options.BootstrapRateOverrideBinsPerSec), ...
    'freezeBootstrapRate',options.FreezeBootstrapRate, ...
    'releaseBootstrapRateAfterVirtualPilotCount', ...
        options.ReleaseBootstrapRateAfterVirtualPilotCount, ...
    'rateDeviationLimitBinsPerSec', ...
        options.RateDeviationLimitBinsPerSec, ...
    'applyVirtualPilotPhaseCorrection', ...
        options.ApplyVirtualPilotPhaseCorrection, ...
    'virtualPilotInnovationGain',options.VirtualPilotInnovationGain, ...
    'virtualPilotPhasePairInnovationGain', ...
        options.VirtualPilotPhasePairInnovationGain, ...
    'virtualPilotPhasePairCfoEnabled', ...
        options.EnableVirtualPilotPhasePairCfo, ...
    'useObservableVirtualPilotRate', ...
        options.UseObservableVirtualPilotRate, ...
    'acceptedVirtualPilotCount',acceptedVirtualPilotCount, ...
    'finalHistoryIndex',finalHistoryIndex, ...
    'finalHistoryCfoBins',finalHistoryCfo, ...
    'finalHistoryConfidence',finalHistoryConfidence, ...
    'finalHistoryPeakRatio',finalHistoryPeakRatio);
end

function [measurement,diagnostic,state] = localVirtualPilotMeasurement( ...
        row,predictedCfo,predictedRate,predictedPhase,residual,state, ...
        config,options)
rawSingle = predictedCfo+residual.offsetBins;
measuredPhase = predictedPhase+residual.phaseRad;
candidate = rawSingle;
pairInnovation = NaN;
pairAgreement = NaN;
pairGap = NaN;
pairUsed = false;
if options.EnableVirtualPilotPhasePairCfo && isfinite(state.row)
    pairGap = row-state.row;
    if pairGap > 0
        measuredAverage = (measuredPhase-state.measuredPhaseRad)/ ...
            (2*pi*pairGap);
        predictedAverage = (predictedPhase-state.predictedPhaseRad)/ ...
            (2*pi*pairGap);
        phaseEndpoint = measuredAverage+0.5*predictedRate* ...
            pairGap*config.symbolDurationSec;
        pairInnovation = measuredAverage-predictedAverage;
        pairAgreement = phaseEndpoint-rawSingle;
        if abs(pairInnovation) <= ...
                options.PhasePairInnovationLimitBins && ...
                abs(pairAgreement) <= ...
                options.PhasePairAgreementLimitBins
            candidate = phaseEndpoint;
            pairUsed = true;
        end
    end
end
gain = options.VirtualPilotInnovationGain;
if pairUsed
    gain = options.VirtualPilotPhasePairInnovationGain;
end
measurement = predictedCfo+gain*(candidate-predictedCfo);
diagnostic = struct('rawSingleCfoBins',rawSingle, ...
    'candidateCfoBins',candidate, ...
    'innovationBins',pairInnovation, ...
    'agreementBins',pairAgreement, ...
    'gapSymbols',pairGap,'used',pairUsed,'gain',gain);
state = struct('row',row,'measuredPhaseRad',measuredPhase, ...
    'predictedPhaseRad',predictedPhase);
end

function [rate,rateStd] = localVirtualPilotRate(rows,cfo,config,cfoStd)
if numel(rows) < 2
    rate = NaN;
    rateStd = Inf;
    return
end
time = (rows(:)-mean(rows))*config.symbolDurationSec;
information = sum(time.^2);
if information <= eps
    rate = NaN;
    rateStd = Inf;
    return
end
design = [ones(numel(time),1),time];
weight = ones(numel(time),1);
beta = localWeightedFit(design,cfo(:),weight);
for iteration = 1:2
    residual = cfo(:)-design*beta;
    weight = min(1,config.huberThresholdBins./max(abs(residual),eps));
    beta = localWeightedFit(design,cfo(:),weight);
end
rate = beta(2);
weightedCenter = sum(weight.*time)/sum(weight);
weightedInformation = sum(weight.*(time-weightedCenter).^2);
rateStd = cfoStd/sqrt(max(weightedInformation,eps));
end

function [idx,cfo,conf,ratio,nextSlot,count] = localInsert(idx,cfo,conf,ratio, ...
        nextSlot,count,newIndex,newCfo,newConfidence,newRatio)
idx(nextSlot) = newIndex;
cfo(nextSlot) = newCfo;
conf(nextSlot) = newConfidence;
ratio(nextSlot) = newRatio;
nextSlot = mod(nextSlot,numel(idx))+1;
count = min(count+1,numel(idx));
end

function [center,rate] = localFit(idx,cfo,conf,ratio,targetIndex,config,tau, ...
        ratePrior,freezeRate,rateDeviationLimit)
valid = isfinite(idx) & isfinite(cfo);
idx = idx(valid); cfo = cfo(valid); conf = conf(valid); ratio = ratio(valid);
targetTime = (targetIndex-0.5)*config.symbolDurationSec;
x = (idx-0.5)*config.symbolDurationSec-targetTime;
weight = config.historyDecay.^max(0,targetIndex-idx);
if isfinite(tau) && tau > 0
    weight = weight.*min(4,max(1,conf/tau));
end
weight = weight.*min(3,max(1,ratio));
if freezeRate
    rate = ratePrior;
    center = sum(weight.*(cfo-rate*x))/sum(weight);
    residual = cfo-(center+rate*x);
    weight = weight.*min(1, ...
        config.huberThresholdBins./max(abs(residual),eps));
    center = sum(weight.*(cfo-rate*x))/sum(weight);
    return
end
if numel(idx) < 2
    center = cfo(end); rate = 0; return
end
beta = localWeightedFit([ones(size(x)),x],cfo,weight);
residual = cfo-[ones(size(x)),x]*beta;
weight = weight.*min(1,config.huberThresholdBins./max(abs(residual),eps));
beta = localWeightedFit([ones(size(x)),x],cfo,weight);
rateLower = max(-config.maxRateBinsPerSec,ratePrior-rateDeviationLimit);
rateUpper = min(config.maxRateBinsPerSec,ratePrior+rateDeviationLimit);
rate = min(rateUpper,max(rateLower,beta(2)));
center = sum(weight.*(cfo-rate*x))/sum(weight);
end

function beta = localWeightedFit(design,response,weight)
sqrtWeight = sqrt(max(weight,eps));
beta = (design.*sqrtWeight)\(response.*sqrtWeight);
end

function localValidateBootstrapOverride(bootstrap,bootstrapCount)
required = {'cfoBins','phaseRad','peakRatio','jointRateBinsPerSec'};
for fieldIndex = 1:numel(required)
    if ~isfield(bootstrap,required{fieldIndex})
        error('SatelliteFig3:BootstrapOverrideField', ...
            'BootstrapOverride is missing field %s.',required{fieldIndex});
    end
end
if numel(bootstrap.cfoBins) ~= bootstrapCount || ...
        numel(bootstrap.phaseRad) ~= bootstrapCount || ...
        numel(bootstrap.peakRatio) ~= bootstrapCount || ...
        any(~isfinite(bootstrap.cfoBins),'all') || ...
        any(~isfinite(bootstrap.phaseRad),'all') || ...
        any(~isfinite(bootstrap.peakRatio),'all') || ...
        ~isfinite(bootstrap.jointRateBinsPerSec)
    error('SatelliteFig3:BootstrapOverrideShape', ...
        'BootstrapOverride does not describe every known preamble.');
end
end
