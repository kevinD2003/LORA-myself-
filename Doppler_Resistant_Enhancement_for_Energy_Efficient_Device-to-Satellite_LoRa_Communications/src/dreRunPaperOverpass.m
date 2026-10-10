function row = dreRunPaperOverpass(snrDb,config)
%DRERUNPAPEROVERPASS One complete horizon-to-horizon Table-IV trial.

reference = drePaperOrbit(0,config);
visibleHalfTime = reference.horizonTimeSec;
packetDuration = config.packetSymbolCount*config.symbolDurationSec+ ...
    config.packetGapSec;
starts = (-visibleHalfTime:packetDuration:(visibleHalfTime-packetDuration)).';
if isfinite(config.maximumPackets) && numel(starts) > config.maximumPackets
    selection = round(linspace(1,numel(starts),config.maximumPackets));
    starts = starts(selection);
end
methods = {'adaptive','fixed'};
symbolErrors = zeros(1,2);
errorMagnitudeSum = zeros(1,2);
payloadCount = 0;
for packetIndex = 1:numel(starts)
    seed = config.randomSeed+round((snrDb+100)*100000)+packetIndex;
    packet = dreGeneratePaperPacket(starts(packetIndex),snrDb,seed,config);
    centroid = dreEstimateCentroids(packet.rx,config);
    for methodIndex = 1:2
        decoded = dreDecodeLinearRegression(centroid.rawBins, ...
            packet.symbols(1:config.preambleSymbolCount),config,methods{methodIndex});
        mismatch = decoded.detectedSymbols ~= packet.payloadSymbols;
        symbolErrors(methodIndex) = symbolErrors(methodIndex)+sum(mismatch);
        if any(mismatch)
            distances = dreCircularSymbolDistance(decoded.detectedSymbols(mismatch), ...
                packet.payloadSymbols(mismatch),config.samplesPerSymbol);
            errorMagnitudeSum(methodIndex) = errorMagnitudeSum(methodIndex)+sum(distances);
        end
    end
    payloadCount = payloadCount+config.payloadSymbolCount;
    if mod(packetIndex,25)==0 || packetIndex==numel(starts)
        fprintf('Paper anchor SNR %+g dB: %d/%d packets\n', ...
            snrDb,packetIndex,numel(starts));
    end
end
ser = symbolErrors/payloadCount;
meanMagnitude = errorMagnitudeSum./max(symbolErrors,1);
meanMagnitude(symbolErrors==0) = 0;
row = struct('snrDb',snrDb,'packetCount',numel(starts), ...
    'payloadSymbolCount',payloadCount, ...
    'adaptiveSymbolErrors',symbolErrors(1),'fixedSymbolErrors',symbolErrors(2), ...
    'adaptiveSer',ser(1),'fixedSer',ser(2), ...
    'adaptiveMeanErrorMagnitude',meanMagnitude(1), ...
    'fixedMeanErrorMagnitude',meanMagnitude(2));
end

