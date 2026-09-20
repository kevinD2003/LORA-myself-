function frame=v4GenerateNativeFrame(c,startTimeSec,snrDb,seeds,initialPhaseRad,channelModel,includePaperMidambles)
arguments
 c (1,1) struct;startTimeSec (1,1) double;snrDb (1,1) double;seeds (1,1) struct
 initialPhaseRad (1,1) double;channelModel (1,:) char;includePaperMidambles (1,1) logical
end
layout=v4BuildNativeFrameLayout(c,includePaperMidambles);payload=v4GeneratePayload(c,seeds.payloadSeed);
bins=zeros(layout.physicalSymbolCount,1);bins(layout.dataRows)=payload.physicalBins;m=c.samplesPerSymbol;
tx=complex(zeros(layout.physicalSymbolCount,m));baseHz=zeros(layout.physicalSymbolCount,m);
for row=1:layout.physicalSymbolCount,tx(row,:)=v4ModulateSymbol(bins(row),c);baseHz(row,:)=v4SymbolFrequency(bins(row),c).';end
total=layout.physicalSymbolCount*m;time=startTimeSec+(0:total-1).'/c.sampleRateHz;orbit=v4Trajectory(time,c);
serial=reshape(baseHz.',[],1);doppler=-(c.carrierFrequencyHz+serial).*orbit.radialVelocityMps/c.speedOfLightMps;
phase=initialPhaseRad+[0;cumsum(pi/c.sampleRateHz*(doppler(1:end-1)+doppler(2:end)))];phaseMatrix=reshape(phase,m,layout.physicalSymbolCount).';
if strcmpi(channelModel,'AWGN'),h=1;elseif strcmpi(channelModel,'Rician'),h=v4RicianCoefficient(c,seeds.channelSeed,1);else,error('V4:ChannelModel','AWGN or Rician required.');end
clean=h*tx.*exp(1i*phaseMatrix);if isinf(snrDb),variance=0;noise=complex(zeros(size(clean)));else,variance=10^(-snrDb/10);stream=RandStream('mt19937ar','Seed',seeds.noiseSeed);noise=sqrt(variance/2)*(randn(stream,size(clean))+1i*randn(stream,size(clean)));end
rx=clean+noise;nextTime=startTimeSec+total/c.sampleRateHz;nextOrbit=v4Trajectory(nextTime,c);nextBase=v4SymbolFrequency(0,c);nextDoppler=-(c.carrierFrequencyHz+nextBase(1))*nextOrbit.radialVelocityMps/c.speedOfLightMps;
nextPhase=phase(end)+pi/c.sampleRateHz*(doppler(end)+nextDoppler);center=floor(m/2)+1;dopplerMatrix=reshape(doppler,m,layout.physicalSymbolCount).';
observation=struct('rxPhysical',rx,'layout',layout,'noiseVariance',variance,'sampleFingerprint',[sum(abs(rx(:)).^2) sum(real(rx(:))) sum(imag(rx(:)))]);
truth=struct('payloadPhysicalBins',payload.physicalBins,'dataBits',logical(payload.dataBits), ...
 'dataCfoBins',dopplerMatrix(layout.dataRows,center)/c.fftBinSpacingHz,'channelCoefficient',h, ...
 'startTimeSec',startTimeSec,'firstSamplePhaseRad',phase(1),'lastSamplePhaseRad',phase(end),'channelModel',channelModel);
frame=struct('observation',observation,'truth',truth,'ledger',seeds,'nextFrameStartTimeSec',nextTime, ...
 'nextFrameStartPhaseRad',angle(exp(1i*nextPhase)),'nextFrameStartDopplerHz',nextDoppler);
end
