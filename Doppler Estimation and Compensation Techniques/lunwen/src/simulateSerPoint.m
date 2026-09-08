function result = simulateSerPoint( ...
    cfg, caseName, strategy, snrDb, limits)
%SIMULATESERPOINT Run one paper-aligned Monte Carlo SER point.
% The function performs sampled FFT detection using the payload and
% Midamble-Point spacing in cfg.

arguments
    cfg (1,1) struct
    caseName (1,1) string
    strategy (1,1) string
    snrDb (1,1) double {mustBeFinite}
    limits (1,1) struct
end

caseName = string(caseName);
strategy = string(strategy);
if caseName == "case1"
    orbitStartS = cfg.orbit.case1StartTimeS;
elseif caseName == "case2"
    orbitStartS = cfg.orbit.case2StartTimeS;
else
    error('simulateSerPoint:UnknownCase', 'Unknown case: %s', caseName);
end
validStrategies = ["no_doppler", "point", "midamble_point"];
if ~any(strategy == validStrategies)
    error('simulateSerPoint:UnknownStrategy', ...
        'Unknown strategy: %s', strategy);
end
validateLimits(limits);

layout = buildFrameLayout(cfg);
numSamples = cfg.radio.samplesPerSymbol;
estimatorFftLength = numSamples* ...
    cfg.receiver.estimatorFftPaddingFactor;
noDopplerTemplate = complex(ones(numSamples, 1));
initialTemplate = integratedDopplerTemplate( ...
    orbitStartS, layout.initialDownchirpStartS, cfg);
pointTemplates = complex(zeros(numSamples, numel(layout.pointDataStartS)));
for index = 1:numel(layout.pointDataStartS)
    pointTemplates(:, index) = integratedDopplerTemplate( ...
        orbitStartS, layout.pointDataStartS(index), cfg);
end
midambleTemplates = complex(zeros(numSamples, numel(layout.slotStartS)));
for index = 1:numel(layout.slotStartS)
    midambleTemplates(:, index) = integratedDopplerTemplate( ...
        orbitStartS, layout.slotStartS(index), cfg);
end

seed = seedForRun(cfg, caseName, strategy, snrDb);
previousRandomState = rng;
restoreRandomState = onCleanup(@() rng(previousRandomState));
rng(seed, 'twister');

packetCount = 0;
symbolErrors = 0;
totalSymbols = 0;
usePairedRandomNumbers = isfield(cfg.monteCarlo, ...
    'commonRandomNumbersAcrossStrategies') && ...
    cfg.monteCarlo.commonRandomNumbersAcrossStrategies;
while (packetCount < limits.minimumPackets || ...
        symbolErrors < limits.minimumSymbolErrors) && ...
        packetCount < limits.maximumPackets
    batchCount = min(limits.batchPackets, ...
        limits.maximumPackets - packetCount);
    if usePairedRandomNumbers
        rng(eventSeed(seed, packetCount, 1), 'twister');
    end
    if string(cfg.channel.model) == "rician_sample"
        % The diagnostic sample-fading model draws its time series inside
        % receivedDechirpedBatch. Avoid consuming an unused block draw here.
        channel = ones(1, batchCount);
    else
        channel = drawChannelCoefficient(cfg, batchCount);
    end
    zeroEstimate = zeros(1, batchCount);
    batchErrors = 0;

    if strategy == "no_doppler"
        for dataIndex = 1:layout.payloadSymbols
            if usePairedRandomNumbers
                rng(eventSeed(seed, packetCount, ...
                    1000 + dataIndex), 'twister');
            end
            batchErrors = batchErrors + detectZeroSymbolBatch( ...
                noDopplerTemplate, channel, zeroEstimate, snrDb, cfg);
        end
    else
        if usePairedRandomNumbers
            rng(eventSeed(seed, packetCount, 2), 'twister');
        end
        initialReceived = receivedDechirpedBatch( ...
            initialTemplate, channel, zeroEstimate, snrDb, cfg);
        currentEstimateHz = estimateFftFrequency( ...
            initialReceived, cfg.radio.sampleRateHz, ...
            estimatorFftLength);
        if strategy == "point"
            for dataIndex = 1:layout.payloadSymbols
                if usePairedRandomNumbers
                    rng(eventSeed(seed, packetCount, ...
                        1000 + dataIndex), 'twister');
                end
                batchErrors = batchErrors + detectZeroSymbolBatch( ...
                    pointTemplates(:, dataIndex), channel, ...
                    currentEstimateHz, snrDb, cfg);
            end
        else
            midambleIndex = 0;
            pendingEstimateHz = [];
            remainingUpdateDelay = 0;
            for slotIndex = 1:numel(layout.slotKind)
                if layout.slotKind(slotIndex) == "data"
                    dataIndex = layout.slotDataIndex(slotIndex);
                    if usePairedRandomNumbers
                        rng(eventSeed(seed, packetCount, ...
                            1000 + dataIndex), 'twister');
                    end
                    batchErrors = batchErrors + detectZeroSymbolBatch( ...
                        midambleTemplates(:, slotIndex), channel, ...
                        currentEstimateHz, snrDb, cfg);
                    if remainingUpdateDelay > 0
                        remainingUpdateDelay = remainingUpdateDelay - 1;
                        if remainingUpdateDelay == 0
                            currentEstimateHz = pendingEstimateHz;
                            pendingEstimateHz = [];
                        end
                    end
                else
                    midambleIndex = midambleIndex + 1;
                    if usePairedRandomNumbers
                        rng(eventSeed(seed, packetCount, ...
                            2000 + midambleIndex), 'twister');
                    end
                    residualHz = estimateResidualBatch( ...
                        midambleTemplates(:, slotIndex), channel, ...
                        currentEstimateHz, snrDb, cfg);
                    updatedEstimateHz = updateMidamblePointEstimate( ...
                        currentEstimateHz, residualHz, ...
                        cfg.receiver.midambleInnovationGain);
                    updateDelay = ...
                        cfg.receiver.midambleUpdateDelayDataSymbols;
                    if updateDelay == 0
                        currentEstimateHz = updatedEstimateHz;
                    else
                        pendingEstimateHz = updatedEstimateHz;
                        remainingUpdateDelay = updateDelay;
                    end
                end
            end
        end
    end

    packetCount = packetCount + batchCount;
    symbolErrors = symbolErrors + batchErrors;
    totalSymbols = totalSymbols + batchCount*layout.payloadSymbols;
end

ser = symbolErrors/totalSymbols;
confidenceInterval = wilsonInterval(symbolErrors, totalSymbols);
result.caseName = caseName;
result.strategy = strategy;
result.snrDb = snrDb;
result.ser = ser;
result.ci95Low = confidenceInterval(1);
result.ci95High = confidenceInterval(2);
result.symbolErrors = symbolErrors;
result.totalSymbols = totalSymbols;
result.packets = packetCount;
result.randomSeed = seed;
result.fittedOrTuned = logical(cfg.provenance.fittedOrTuned);
end

function seedValue = eventSeed(baseSeed, packetOffset, eventCode)
seedValue = mod(baseSeed + packetOffset*10000019 + ...
    eventCode*1009, 2^32 - 1);
seedValue = double(floor(seedValue));
end

function validateLimits(limits)
required = ["batchPackets", "minimumPackets", ...
    "maximumPackets", "minimumSymbolErrors"];
for name = required
    if ~isfield(limits, name)
        error('simulateSerPoint:MissingLimit', ...
            'Missing limit field: %s', name);
    end
end
if limits.batchPackets < 1 || limits.minimumPackets < 1 || ...
        limits.maximumPackets < limits.minimumPackets || ...
        limits.minimumSymbolErrors < 0
    error('simulateSerPoint:InvalidLimits', ...
        'Invalid Monte Carlo stopping limits.');
end
end
