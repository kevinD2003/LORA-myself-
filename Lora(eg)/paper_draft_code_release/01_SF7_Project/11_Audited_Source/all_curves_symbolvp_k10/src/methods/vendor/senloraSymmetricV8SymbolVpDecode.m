function result = senloraSymmetricV8SymbolVpDecode( ...
        observation,common,config,plan,options)
%SENLORASYMMETRICV8SYMBOLVPDECODE Joint-block ML with delayed symbol VP.
% Independent experiment: the frozen decoder and blend remain unchanged.
arguments
    observation (1,1) struct
    common (1,1) struct
    config (1,1) struct
    plan (1,1) struct
    options.SymbolVpHistoryLength (1,1) double ...
        {mustBeMember(options.SymbolVpHistoryLength,[0 1 2 3 8])} = 8
end
c = config.parent;
layout = observation.layout;
N = options.SymbolVpHistoryLength;
if ~isempty(layout.midambleRows) || ...
        layout.physicalSymbolCount~=plan.nativePhysicalSymbolCount || ...
        c.virtualPilotHistoryLength~=8 || c.bootstrapPilotCount~=8
    error('SymbolVp:NativeFrame','Requires native V8 and unchanged rolling-8 bootstrap.');
end
if any(~isfinite(observation.rxPhysical),'all')
    error('SymbolVp:NonfiniteInput','Received samples must be finite.');
end
parameters = v4BCalibrationCandidates();
parameters = parameters(2);

% This bootstrap and first pass are intentionally identical to frozen V8.
pilots = observation.rxPhysical(layout.bootstrapRows,:);
joint = v4Stage55JointPreambleMlBootstrap(pilots,c, ...
    MaximumRateBinsPerSec=parameters.maximumRateBinsPerSec);
predictedDrift = abs(joint.rateBinsPerSec)*plan.frameDurationSec;
u = min(1,max(0,(predictedDrift-plan.driftBlendStartBins)/ ...
    (plan.driftBlendEndBins-plan.driftBlendStartBins)));
rateGain = u*u*(3-2*u);
bootstrap = senloraSymmetricV8BlendBootstrap(common,joint,rateGain,c);
firstTracker = v4RollingTrackerPass( ...
    observation,bootstrap,c,parameters,false(c.payloadSymbolCount,1), ...
    InitialRateBinsPerSec=bootstrap.rateBinsPerSec);
firstDecoded = v4DecodePayload(firstTracker.compensatedData,c,common.noisePower);

searchBins = parameters.residualSearchBins( ...
    abs(parameters.residualSearchBins)<=parameters.innovationLimitBins);
nData = c.payloadSymbolCount;
nBlocks = c.hammingBlockCount;
compensatedData = complex(zeros(nData,c.samplesPerSymbol));
estimatedCfoBins = zeros(nData,1);
estimatedRate = zeros(nData,1);
selectedResidualBins = zeros(nBlocks,1);
searchPeakRatio = ones(nBlocks,1);
blockSelectedAtBoundary = false(nBlocks,1);
history = localEmptyHistory();
correctionPhaseState = 0;
record = localEmptyRecord(nData,layout);
fits = repmat(struct('historyCount',0,'timeSpanSec',0,'sourceBlockCount',0, ...
    'rateUpdated',false,'rateRejected',false,'rateStdBinsPerSec',0, ...
    'usedSymbolIndices',zeros(0,1),'weight',zeros(0,1)),nBlocks,1);
historyAfterInsert = zeros(nBlocks,1);
priorCfoLog = zeros(nBlocks,1);
priorRateLog = zeros(nBlocks,1);

for block = 1:nBlocks
    rows = (block-1)*c.hammingCodewordLength+(1:c.hammingCodewordLength);
    blockCenter = mean(layout.physicalCenterTimeSec(layout.dataRows(rows)));
    targetRow = layout.dataRows(rows(1));
    [priorCfo,priorRate,fits(block)] = senloraSymbolVpPredict( ...
        history,blockCenter,targetRow,c,parameters);
    priorCfoLog(block) = priorCfo;
    priorRateLog(block) = priorRate;
    used = fits(block).usedSymbolIndices;
    notUsed = used(isnan(record.firstUsedAtPhysicalRow(used)));
    record.firstUsedAtPhysicalRow(notUsed) = targetRow;

    % Preserve the frozen CFO x legal-codeword search for the current block.
    candidateSamples = cell(numel(searchBins),1);
    candidateDecoded = cell(numel(searchBins),1);
    candidateEndPhase = zeros(numel(searchBins),1);
    objective = zeros(numel(searchBins),1);
    for candidate = 1:numel(searchBins)
        delta = searchBins(candidate);
        phaseState = correctionPhaseState;
        samples = complex(zeros(c.hammingCodewordLength,c.samplesPerSymbol));
        for local = 1:c.hammingCodewordLength
            data = rows(local);
            time = layout.physicalCenterTimeSec(layout.dataRows(data));
            correctionCenter = priorCfo+priorRate*(time-blockCenter)+delta;
            phaseStart = angle(exp(1i*(firstTracker.predictedPhaseRad(data)+phaseState)));
            samples(local,:) = v4CompensateSymbol( ...
                observation.rxPhysical(layout.dataRows(data),:),phaseStart, ...
                firstTracker.predictedCfoBins(data)+correctionCenter, ...
                bootstrap.rateBinsPerSec+priorRate,c);
            phaseState = angle(exp(1i*(phaseState+2*pi*correctionCenter)));
        end
        decoded = senloraSymmetricV8BlockLikelihood(samples,c,common.noisePower);
        candidateSamples{candidate} = samples;
        candidateDecoded{candidate} = decoded;
        candidateEndPhase(candidate) = phaseState;
        objective(candidate) = decoded.objective;
    end
    [orderedObjective,order] = sort(objective,'descend');
    selected = order(1);
    selectedDelta = searchBins(selected);
    chosen = candidateDecoded{selected};
    compensatedData(rows,:) = candidateSamples{selected};
    correctionPhaseState = candidateEndPhase(selected);
    selectedResidualBins(block) = selectedDelta;
    normalizedMargin = (orderedObjective(1)-orderedObjective(2))/ ...
        (c.hammingCodewordLength*c.effectiveDataSf);
    searchPeakRatio(block) = exp(min(50,max(0,normalizedMargin)));
    blockSelectedAtBoundary(block) = selected==1 || selected==numel(searchBins);
    time = layout.physicalCenterTimeSec(layout.dataRows(rows));
    estimatedCfoBins(rows) = firstTracker.predictedCfoBins(rows)+ ...
        priorCfo+priorRate*(time-blockCenter)+selectedDelta;
    estimatedRate(rows) = bootstrap.rateBinsPerSec+priorRate;

    % Labels are obtained ONLY from this received complete Hamming block.
    measured = senloraSymbolVpMeasure(candidateSamples{selected},chosen, ...
        firstTracker.predictedCfoBins(rows),estimatedCfoBins(rows), ...
        c,parameters,searchPeakRatio(block));
    fields = fieldnames(measured);
    for k = 1:numel(fields)
        name = fields{k};
        if isfield(record,name)
            value = measured.(name);
            if isscalar(value)
                record.(name)(rows,:) = repmat(value,numel(rows),1);
            else
                record.(name)(rows,:) = value;
            end
        end
    end
    record.sourceBlock(rows) = block;
    record.firstCfoBins(rows) = firstTracker.predictedCfoBins(rows);
    record.jointCfoBins(rows) = estimatedCfoBins(rows);
    record.blockSearchPeakRatio(rows) = searchPeakRatio(block);
    endRow = layout.dataRows(rows(end));
    availableTime = layout.physicalStartTimeSec(endRow)+c.symbolDurationSec;
    record.labelAvailableTimeSec(rows) = availableTime;
    record.availableTimeSec(rows) = availableTime;
    record.availablePhysicalRow(rows) = endRow+1;
    record.feedbackEnabled(rows) = N>0;
    % Acceptances in the final block are still recorded, with no in-frame use.
    % Sequential insertion preserves the newest N *symbol* observations.
    if N>0
        for data = rows(measured.accepted(:).')
            record.insertedAtTimeSec(data) = availableTime;
            names = fieldnames(history);
            for k = 1:numel(names)
                name = names{k};
                history.(name)(end+1,1) = record.(name)(data);
                if numel(history.(name))>N
                    history.(name)(1) = [];
                end
            end
        end
    end
    historyAfterInsert(block) = numel(history.symbolIndex);
end
finalDecoded = v4DecodePayload(compensatedData,c,common.noisePower);
observations = struct2table(record);
fitLog = table((1:nBlocks).',[fits.historyCount].',[fits.timeSpanSec].', ...
    [fits.sourceBlockCount].',[fits.rateUpdated].',[fits.rateRejected].', ...
    [fits.rateStdBinsPerSec].',priorCfoLog,priorRateLog,historyAfterInsert, ...
    {fits.usedSymbolIndices}.', ...
    'VariableNames',{'blockIndex','historyCount','timeSpanSec','sourceBlockCount', ...
    'rateUpdated','rateRejected','rateStdBinsPerSec','priorCfoBins', ...
    'priorRateBinsPerSec','historyAfterInsert','usedSymbolIndices'});
result = struct('methodName',sprintf('V8-Symbol-VP-Rolling-%d',N), ...
    'methodId',sprintf('senlora-v8-symbol-vp-n%d',N), ...
    'algorithmVersion','SenLoRa-V8-symbol-vp-experiment-v1', ...
    'SymbolVpHistoryLength',N, ...
    'detectedPhysicalBins',finalDecoded.hardPhysicalBins, ...
    'hardDecodedDataBits',finalDecoded.hardDataBits, ...
    'softDecodedDataBits',finalDecoded.softDataBits, ...
    'jointReencodedPhysicalBins',record.knownPhysicalBins, ...
    'estimatedCfoBins',estimatedCfoBins,'estimatedRateBinsPerSec',estimatedRate, ...
    'firstPassDetectedPhysicalBins',firstDecoded.hardPhysicalBins, ...
    'firstPassEstimatedCfoBins',firstTracker.predictedCfoBins, ...
    'selectedResidualBins',selectedResidualBins,'searchPeakRatio',searchPeakRatio, ...
    'blockSelectedAtBoundary',blockSelectedAtBoundary, ...
    'virtualPilotAccepted',record.accepted & N>0, ...
    'acceptedVirtualPilots',sum(record.accepted & N>0), ...
    'usedVirtualPilots',sum(isfinite(record.firstUsedAtPhysicalRow)), ...
    'symbolObservations',observations,'fitLog',fitLog,'fits',fits, ...
    'finalHistory',history,'rateGain',rateGain, ...
    'jointPreambleEstimate',joint,'bootstrap',bootstrap,'firstPassTracker',firstTracker, ...
    'residualSearchCandidates',parameters.residualSearchBins, ...
    'correlationPolicy','shared-block labels; block-normalized fit; cross-block rate evidence', ...
    'complexity',struct('jointCandidateBlocks',nBlocks*numel(searchBins), ...
    'jointSymbolLikelihoods',nData*numel(searchBins), ...
    'residualSymbolSearches',nData, ...
    'residualCorrelationProducts',nData*numel(parameters.residualSearchBins)*c.samplesPerSymbol), ...
    'usesPayloadTruth',false,'usesOrbitTruth',false,'usesCaseIdentity',false, ...
    'usesSnrInput',false,'usesTargetSer',false,'usesExplicitMidambles',false);
end

function history = localEmptyHistory()
names = {'symbolIndex','symbolTimeSec','correctionCfoBins','confidence', ...
    'residualPeakRatio','sourceBlock','availablePhysicalRow','availableTimeSec'};
history = struct();
for k = 1:numel(names)
    history.(names{k}) = zeros(0,1);
end
end

function record = localEmptyRecord(n,layout)
record = struct('symbolIndex',(1:n).','symbolTimeSec', ...
    layout.physicalCenterTimeSec(layout.dataRows));
names = {'knownPhysicalBins','hardPhysicalBins','decisionPeakRatio', ...
    'residualCfoBins','correctionCfoBins','residualPhaseRad','residualPeakRatio', ...
    'residualPeakMetric','confidence','sharedCodingMarginRatio','sourceBlock', ...
    'firstCfoBins','jointCfoBins','blockSearchPeakRatio','labelAvailableTimeSec', ...
    'availableTimeSec','availablePhysicalRow'};
for k = 1:numel(names)
    record.(names{k}) = zeros(n,1);
end
names = {'accepted','labelAgreement','residualAtBoundary','residualInRange', ...
    'sharedBlockGuard','feedbackEnabled'};
for k = 1:numel(names)
    record.(names{k}) = false(n,1);
end
record.sampleFingerprint = zeros(n,3);
record.insertedAtTimeSec = nan(n,1);
record.firstUsedAtPhysicalRow = nan(n,1);
end
