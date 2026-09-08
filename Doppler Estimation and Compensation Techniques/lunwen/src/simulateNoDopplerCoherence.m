function result = simulateNoDopplerCoherence( ...
    cfg, snrDb, packetCount, coherenceMode)
%SIMULATENODOPPLERCOHERENCE Test an unspecified Rician coherence choice.
% This diagnostic never alters the primary paper configuration.

arguments
    cfg (1,1) struct
    snrDb (1,1) double {mustBeFinite}
    packetCount (1,1) double {mustBeInteger, mustBePositive}
    coherenceMode (1,1) string
end

coherenceMode = string(coherenceMode);
if ~any(coherenceMode == ["packet", "symbol"])
    error('simulateNoDopplerCoherence:UnknownMode', ...
        'Unknown coherence mode: %s', coherenceMode);
end
previousRandomState = rng;
restoreRandomState = onCleanup(@() rng(previousRandomState));
modeCode = double(coherenceMode == "symbol");
rng(cfg.monteCarlo.randomSeed + 700000 + modeCode, 'twister');

numSamples = cfg.radio.samplesPerSymbol;
template = ones(numSamples, 1);
errors = 0;
processedPackets = 0;
while processedPackets < packetCount
    batchCount = min(cfg.monteCarlo.batchPackets, ...
        packetCount-processedPackets);
    estimateHz = zeros(1, batchCount);
    if coherenceMode == "packet"
        packetChannel = drawChannelCoefficient(cfg, batchCount);
    end
    for dataIndex = 1:cfg.frame.payloadSymbols
        if coherenceMode == "symbol"
            channel = drawChannelCoefficient(cfg, batchCount);
        else
            channel = packetChannel;
        end
        errors = errors + detectZeroSymbolBatch( ...
            template, channel, estimateHz, snrDb, cfg);
    end
    processedPackets = processedPackets + batchCount;
end
totalSymbols = packetCount*cfg.frame.payloadSymbols;
interval = wilsonInterval(errors, totalSymbols);
result.coherenceMode = coherenceMode;
result.snrDb = snrDb;
result.ser = errors/totalSymbols;
result.ci95Low = interval(1);
result.ci95High = interval(2);
result.symbolErrors = errors;
result.totalSymbols = totalSymbols;
result.packets = packetCount;
result.fittedOrTuned = false;
end
