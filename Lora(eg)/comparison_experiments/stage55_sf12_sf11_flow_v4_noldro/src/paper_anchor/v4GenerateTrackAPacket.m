function packet = v4GenerateTrackAPacket(config,caseStartTimeSec,snrDb,packetId,rootSeed)
%V4GENERATETRACKAPACKET One paired packet and no-Doppler diagnostic realization.
schedule = v4BuildTrackASchedule(config);
streamPayload = RandStream('mt19937ar','Seed',rootSeed+3*packetId-2);
streamChannel = RandStream('mt19937ar','Seed',rootSeed+3*packetId-1);
streamNoise = RandStream('mt19937ar','Seed',rootSeed+3*packetId);
labels = randi(streamPayload,[0 4095],23,1);
k = 10;
h = sqrt(k/(k+1))+sqrt(1/(2*(k+1)))*(randn(streamChannel)+1i*randn(streamChannel));
tx = complex(zeros(schedule.totalSamples,1));
up = v4ModulateSymbol(0,config).';
down = conj(up);
for row = 1:numel(schedule.kind)
    first = schedule.startSample(row)+1;
    last = first+schedule.sampleCount(row)-1;
    if schedule.kind(row) == "data"
        waveform = v4ModulateSymbol(labels(schedule.dataIndex(row)),config).';
    elseif schedule.kind(row) == "down" || schedule.kind(row) == "quarter-down"
        waveform = down(1:schedule.sampleCount(row));
    else
        waveform = up;
    end
    tx(first:last) = waveform;
end
time = caseStartTimeSec+(0:schedule.totalSamples-1).'/config.sampleRateHz;
orbit = v4TrackAOrbit(time,config);
phase = [0;cumsum(pi/config.sampleRateHz*(orbit.dopplerHz(1:end-1)+orbit.dopplerHz(2:end)))];
variance = 10^(-snrDb/10);
noise = sqrt(variance/2)*(randn(streamNoise,schedule.totalSamples,1)+ ...
    1i*randn(streamNoise,schedule.totalSamples,1));
rx = h*tx.*exp(1i*phase)+noise;
rxNoDoppler = h*tx+noise;
dataCenterSample = schedule.startSample(schedule.dataRows)+config.samplesPerSymbol/2+1;
truth = struct('labels',labels,'dataCfoHz',orbit.dopplerHz(dataCenterSample), ...
    'dataCenterTimeSec',time(dataCenterSample),'channelCoefficient',h, ...
    'caseStartTimeSec',caseStartTimeSec,'snrDb',snrDb,'packetId',packetId);
packet = struct('rx',rx,'rxNoDoppler',rxNoDoppler,'tx',tx,'schedule',schedule, ...
    'truth',truth,'noiseVariance',variance,'seedRoot',rootSeed);
end
