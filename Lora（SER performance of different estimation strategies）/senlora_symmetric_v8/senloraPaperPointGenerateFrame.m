function frame = senloraPaperPointGenerateFrame(config,startSec,snrDb,seeds,channelModel)
%SENLORAPAPERPOINTGENERATEFRAME Own Paper frame with paired native data noise.
c = config.parent;
if ~ismember(string(channelModel),["AWGN","Rician"]) || c.ricianKDb~=10
    error('EXP5Paper:Channel','Use AWGN or packet-flat Rician K=10 dB.');
end
layout = senloraPaperPointFrameLayout(c);
m = c.samplesPerSymbol;
payload = v4GeneratePayload(c,seeds.payloadSeed);
bins = zeros(layout.physicalSymbolCount,1);
bins(layout.dataRows) = payload.physicalBins;
tx = complex(zeros(layout.physicalSymbolCount,m));
for row = 1:layout.physicalSymbolCount
    tx(row,:) = v4ModulateSymbol(bins(row),c);
end
tx(layout.downchirpRows,:) = conj(tx(layout.downchirpRows,:));
time = startSec+(0:layout.totalSamples-1).'/c.sampleRateHz;
orbit = exp1TrackAOrbit(time,c);
phase = config.initialChannelPhaseRad+[0;cumsum(pi/c.sampleRateHz* ...
    (orbit.dopplerHz(1:end-1)+orbit.dopplerHz(2:end)))];
indices = layout.physicalStartSample+(1:m);
phasePhysical = phase(indices);
channel = 1;
if strcmp(channelModel,'Rician'), channel = v4RicianCoefficient(c,seeds.channelSeed,1); end
clean = channel*tx.*exp(1i*phasePhysical);
syncIndices = layout.quarterSyncStartSample+(1:layout.quarterSyncSamples);
down = conj(v4ModulateSymbol(0,c));
cleanSync = channel*down(1:layout.quarterSyncSamples).*exp(1i*phase(syncIndices).');
noise = complex(zeros(size(clean)));
syncNoise = complex(zeros(size(cleanSync)));
variance = 0;
if ~isinf(snrDb)
    variance = 10^(-snrDb/10);
    stream = RandStream('mt19937ar','Seed',seeds.noiseSeed);
    shape = [c.noMidambleFrameSymbolCount,m];
    native = sqrt(variance/2)*(randn(stream,shape)+1i*randn(stream,shape));
    noise(layout.bootstrapRows,:) = native(1:8,:);
    noise(layout.dataRows,:) = native(9:end,:);
    extra = RandStream('mt19937ar','Seed',seeds.paperExtraNoiseSeed);
    knownRows = [layout.downchirpRows;layout.midambleRows];
    shape = [numel(knownRows),m];
    noise(knownRows,:) = sqrt(variance/2)*(randn(extra,shape)+1i*randn(extra,shape));
    syncNoise = sqrt(variance/2)*(randn(extra,size(cleanSync))+1i*randn(extra,size(cleanSync)));
end
rx = clean+noise;
centerIndices = indices(layout.dataRows,floor(m/2)+1);
observation = struct('rxPhysical',rx,'rxQuarterSync',cleanSync+syncNoise, ...
    'layout',layout,'noiseVariance',variance);
truth = struct('payloadPhysicalBins',payload.physicalBins, ...
    'dataBits',logical(payload.dataBits),'phasePhysicalRad',phasePhysical, ...
    'dataCfoBins',orbit.dopplerHz(centerIndices)/c.fftBinSpacingHz, ...
    'dataRateBinsPerSec',orbit.dopplerRateHzPerSec(centerIndices)/c.fftBinSpacingHz, ...
    'channelCoefficient',channel,'channelPower',abs(channel)^2,'channelModel',channelModel);
frame = struct('observation',observation,'truth',truth,'ledger',seeds);
end
