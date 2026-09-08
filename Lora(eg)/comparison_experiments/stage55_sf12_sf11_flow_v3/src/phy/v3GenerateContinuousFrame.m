function frame = v3GenerateContinuousFrame(config,startTimeSec,snrDb,seeds,initialPhaseRad)
%V3GENERATECONTINUOUSFRAME Paired SF12 frame with continuous Doppler phase.

layout = v3BuildFrameLayout(config);
payload = v3GeneratePayload(config,seeds.payloadSeed);
physicalBins = zeros(layout.physicalSymbolCount,1);
physicalBins(layout.dataRows) = payload.physicalBins;
m = config.samplesPerSymbol;
tx = complex(zeros(layout.physicalSymbolCount,m));
basebandHz = zeros(layout.physicalSymbolCount,m);
for row = 1:layout.physicalSymbolCount
    tx(row,:) = v3ModulateSymbol(physicalBins(row),config);
    basebandHz(row,:) = v3SymbolFrequency(physicalBins(row),config).';
end
totalSamples = layout.physicalSymbolCount*m;
sampleTime = startTimeSec+(0:totalSamples-1).'/config.sampleRateHz;
orbit = v3Trajectory(sampleTime,config);
basebandSerial = reshape(basebandHz.',[],1);
dopplerSerial = -(config.carrierFrequencyHz+basebandSerial).* ...
    orbit.radialVelocityMps/config.speedOfLightMps;
phaseSerial = initialPhaseRad+[0;cumsum(pi/config.sampleRateHz*( ...
    dopplerSerial(1:end-1)+dopplerSerial(2:end)))];
phase = reshape(phaseSerial,m,layout.physicalSymbolCount).';
channel = v3RicianCoefficient(config,seeds.channelSeed,1);
rxNoiseless = channel*tx.*exp(1i*phase);
if isinf(snrDb)
    noiseVariance = 0;
    noise = complex(zeros(size(rxNoiseless)));
else
    noiseVariance = 10^(-snrDb/10);
    stream = RandStream('mt19937ar','Seed',seeds.noiseSeed);
    noise = sqrt(noiseVariance/2)*(randn(stream,size(rxNoiseless))+ ...
        1i*randn(stream,size(rxNoiseless)));
end
rx = rxNoiseless+noise;
nextTime = startTimeSec+totalSamples/config.sampleRateHz;
nextOrbit = v3Trajectory(nextTime,config);
nextBasebandHz = v3SymbolFrequency(0,config);
nextDopplerHz = -(config.carrierFrequencyHz+nextBasebandHz(1))* ...
    nextOrbit.radialVelocityMps/config.speedOfLightMps;
nextPhase = phaseSerial(end)+pi/config.sampleRateHz*( ...
    dopplerSerial(end)+nextDopplerHz);
centerSample = floor(m/2)+1;
doppler = reshape(dopplerSerial,m,layout.physicalSymbolCount).';
dataCfoBins = doppler(layout.dataRows,centerSample)/config.fftBinSpacingHz;
observation = struct('rxPhysical',rx,'layout',layout, ...
    'noiseVariance',noiseVariance,'sampleFingerprint',[ ...
    sum(abs(rx(:)).^2),sum(real(rx(:))),sum(imag(rx(:)))]);
truth = struct('payloadPhysicalBins',payload.physicalBins, ...
    'dataBits',logical(payload.dataBits),'dataCfoBins',dataCfoBins, ...
    'channelCoefficient',channel,'startTimeSec',startTimeSec, ...
    'firstSamplePhaseRad',phaseSerial(1), ...
    'lastSamplePhaseRad',phaseSerial(end));
frame = struct('observation',observation,'truth',truth,'ledger',seeds, ...
    'nextFrameStartTimeSec',nextTime, ...
    'nextFrameStartPhaseRad',angle(exp(1i*nextPhase)), ...
    'nextFrameStartDopplerHz',nextDopplerHz);
end

