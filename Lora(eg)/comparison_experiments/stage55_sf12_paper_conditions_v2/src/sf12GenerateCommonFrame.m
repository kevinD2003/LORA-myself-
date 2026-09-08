function frame = sf12GenerateCommonFrame(cfg,caseName,snrDb,seeds)
%SF12GENERATECOMMONFRAME Generate one shared enhanced physical frame.
% Truth is returned only for the outer evaluator; receiver functions take
% FRAME.OBSERVATION and therefore cannot access payload or orbit truth.

layout = sf12BuildFrameLayout(cfg);
n = cfg.radio.samplesPerSymbol;
fs = cfg.radio.sampleRateHz;
ts = cfg.radio.symbolDurationSec;
caseName = string(caseName);
if caseName == "case1"
    orbitStart = cfg.orbit.case1StartTimeSec;
elseif caseName == "case2"
    orbitStart = cfg.orbit.case2StartTimeSec;
else
    error('Sf12:Case','Unknown case: %s',caseName);
end

oldRng = rng;
cleanup = onCleanup(@()rng(oldRng));
rng(seeds.payloadSeed,'twister');
payloadSymbols = randi([0,cfg.radio.dataAlphabetSize-1], ...
    cfg.frame.payloadSymbolCount,1);

lastSample = round((layout.physicalStartTimeSec(end)+ts)*fs)-1;
sampleIndex = (0:lastSample).';
frequencyHz = sf12CircularOrbitDoppler( ...
    orbitStart+sampleIndex/fs,cfg);
phase = 2*pi*cumsum(frequencyHz)/fs;

syncStart = round(layout.initialDownchirpStartTimeSec*fs)+1;
syncPhase = phase(syncStart:syncStart+n-1);
rxSyncSignal = exp(1j*syncPhase);
rxPhysicalSignal = complex(zeros(layout.physicalSymbolCount,n));
trueCfoHz = nan(cfg.frame.payloadSymbolCount,1);
sample = (0:n-1);
for row = 1:layout.physicalSymbolCount
    first = round(layout.physicalStartTimeSec(row)*fs)+1;
    phaseRow = phase(first:first+n-1).';
    if layout.kind(row) == "data"
        k = layout.dataIndex(row);
        waveformBin = cfg.radio.dataBinSpacing*payloadSymbols(k);
        tone = exp(1j*2*pi*waveformBin*sample/n);
        trueCfoHz(k) = mean(frequencyHz(first:first+n-1));
    else
        tone = ones(1,n);
    end
    rxPhysicalSignal(row,:) = tone.*exp(1j*phaseRow);
end

rng(seeds.noiseSeed,'twister');
kLinear = 10^(cfg.channel.ricianKDb/10);
channel = sqrt(kLinear/(kLinear+1))+sqrt(1/(2*(kLinear+1)))* ...
    (randn+1j*randn);
if cfg.channel.disableNoise
    noiseSync = complex(zeros(n,1));
    noisePhysical = complex(zeros(size(rxPhysicalSignal)));
else
    noisePower = cfg.channel.signalPower*10^(-snrDb/10);
    noiseSync = sqrt(noisePower/2)*(randn(n,1)+1j*randn(n,1));
    noisePhysical = sqrt(noisePower/2)*(randn(size(rxPhysicalSignal))+ ...
        1j*randn(size(rxPhysicalSignal)));
end
observation.rxInitialDownchirp = channel*rxSyncSignal+noiseSync;
observation.rxPhysical = channel*rxPhysicalSignal+noisePhysical;
observation.layout = layout;
frame.observation = observation;
frame.truth.payloadSymbols = payloadSymbols;
frame.truth.payloadWaveformBins = cfg.radio.dataBinSpacing*payloadSymbols;
frame.truth.dataCfoHz = trueCfoHz;
frame.truth.channelCoefficient = channel;
frame.truth.caseName = caseName;
frame.truth.snrDb = snrDb;
frame.ledger = seeds;
frame.commonSampleFingerprint = [sum(abs(observation.rxPhysical(:)).^2), ...
    sum(real(observation.rxPhysical(:))),sum(imag(observation.rxPhysical(:)))];
end
