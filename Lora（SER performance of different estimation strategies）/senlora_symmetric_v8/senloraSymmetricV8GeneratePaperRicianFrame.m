function frame = senloraSymmetricV8GeneratePaperRicianFrame( ...
        config,orbitStartSec,snrDb,seeds)
%SENLORASYMMETRICV8GENERATEPAPERRICIANFRAME Reused Paper PHY with paired noise.
% Only Paper gets midambles. Native preamble/data noise is replayed by
% logical symbol index, not by the longer physical matrix dimensions.

c = config.parent;
if c.ricianKDb~=10 || ~strcmp(c.ricianModel,'packet-flat')
    error('EXP5V8:PaperRicianConfig','Requires packet-flat Rician K=10 dB.');
end
layout = v4BuildNativeFrameLayout(c,true);
payload = v4GeneratePayload(c,seeds.payloadSeed);
m = c.samplesPerSymbol;
physicalBins = zeros(layout.physicalSymbolCount,1);
physicalBins(layout.dataRows) = payload.physicalBins;
tx = complex(zeros(layout.physicalSymbolCount,m));
for row = 1:layout.physicalSymbolCount
    tx(row,:) = v4ModulateSymbol(physicalBins(row),c);
end
sampleTime = orbitStartSec+ ...
    (0:layout.physicalSymbolCount*m-1).'/c.sampleRateHz;
orbit = exp1TrackAOrbit(sampleTime,c);
phase = config.initialChannelPhaseRad+[0;cumsum(pi/c.sampleRateHz* ...
    (orbit.dopplerHz(1:end-1)+orbit.dopplerHz(2:end)))];
phasePhysical = reshape(phase,m,layout.physicalSymbolCount).';
channel = v4RicianCoefficient(c,seeds.channelSeed,1);
clean = channel*tx.*exp(1i*phasePhysical);
noise = complex(zeros(size(clean)));
noiseVariance = 0;
if ~isinf(snrDb)
    noiseVariance = 10^(-snrDb/10);
    nativeShape = [c.noMidambleFrameSymbolCount,m];
    stream = RandStream('mt19937ar','Seed',seeds.noiseSeed);
    nativeNoise = sqrt(noiseVariance/2)*(randn(stream,nativeShape)+ ...
        1i*randn(stream,nativeShape));
    noise(layout.bootstrapRows,:) = ...
        nativeNoise(1:c.bootstrapPilotCount,:);
    noise(layout.dataRows,:) = nativeNoise(c.bootstrapPilotCount+1:end,:);
    midambleStream = RandStream('mt19937ar','Seed',seeds.midambleNoiseSeed);
    midambleShape = [c.paperMidambleCount,m];
    noise(layout.midambleRows,:) = sqrt(noiseVariance/2)*( ...
        randn(midambleStream,midambleShape)+ ...
        1i*randn(midambleStream,midambleShape));
end
rx = clean+noise;
center = floor(m/2)+1;
frequency = reshape(orbit.dopplerHz,m,layout.physicalSymbolCount).';
rate = reshape(orbit.dopplerRateHzPerSec,m,layout.physicalSymbolCount).';
observation = struct('rxPhysical',rx,'layout',layout, ...
    'noiseVariance',noiseVariance,'sampleFingerprint', ...
    [sum(abs(rx(:)).^2),sum(real(rx(:))),sum(imag(rx(:)))]);
truth = struct('payloadPhysicalBins',payload.physicalBins, ...
    'dataBits',logical(payload.dataBits),'phasePhysicalRad',phasePhysical, ...
    'dataCfoBins',frequency(layout.dataRows,center)/c.fftBinSpacingHz, ...
    'dataRateBinsPerSec',rate(layout.dataRows,center)/c.fftBinSpacingHz, ...
    'channelCoefficient',channel,'channelPower',abs(channel)^2, ...
    'startTimeSec',orbitStartSec,'timelineMode',layout.timelineMode);
frame = struct('observation',observation,'truth',truth,'ledger',seeds);
end
