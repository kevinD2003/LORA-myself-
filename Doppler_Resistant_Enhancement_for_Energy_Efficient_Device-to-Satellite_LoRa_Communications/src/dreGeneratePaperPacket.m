function packet = dreGeneratePaperPacket(startTimeSec,snrDb,seed,config)
%DREGENERATEPAPERPACKET Common IQ packet for both paper receivers.

arguments
    startTimeSec (1,1) double {mustBeFinite}
    snrDb (1,1) double
    seed (1,1) double {mustBeInteger,mustBeNonnegative}
    config (1,1) struct
end
stream = RandStream('mt19937ar','Seed',seed);
payload = randi(stream,[0 config.samplesPerSymbol-1], ...
    config.payloadSymbolCount,1);
symbols = [zeros(config.preambleSymbolCount,1);payload];
tx = dreModulateSymbols(symbols,config);
sampleCount = numel(tx);
timeSec = startTimeSec+(0:sampleCount-1).'/config.sampleRateHz;
orbit = drePaperOrbit(timeSec,config);
doppler = orbit.dopplerHz(:);
switch config.phaseModel
    case 'paper-equation-15-product'
        phase = 2*pi*doppler.*timeSec;
    case 'integrated-instantaneous-doppler'
        phase = zeros(sampleCount,1);
        if sampleCount > 1
            phase(2:end) = cumsum(pi/config.sampleRateHz* ...
                (doppler(1:end-1)+doppler(2:end)));
        end
    otherwise
        error('DRE:PhaseModel','Unknown paper phase model.');
end
phase = reshape(phase,config.samplesPerSymbol,config.packetSymbolCount).';
rxNoiseless = tx.*exp(1i*phase);
if isinf(snrDb)
    noise = complex(zeros(size(tx)));
else
    variance = 10^(-snrDb/10);
    noise = sqrt(variance/2)*(randn(stream,size(tx))+1i*randn(stream,size(tx)));
end
packet = struct('rx',rxNoiseless+noise,'symbols',symbols, ...
    'payloadSymbols',payload,'startTimeSec',startTimeSec,'snrDb',snrDb, ...
    'seed',seed,'usesPayloadTruthInReceiver',false);
end
