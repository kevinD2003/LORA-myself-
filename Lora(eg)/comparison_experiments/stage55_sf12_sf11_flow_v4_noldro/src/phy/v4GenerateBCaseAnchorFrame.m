function frame=v4GenerateBCaseAnchorFrame(c,caseStartTimeSec,snrDb,seeds)
%V4GENERATEBCASEANCHORFRAME CR3 frame under the independent Track A orbit.
layout=v4BuildFrameLayout(c);payload=v4GeneratePayload(c,seeds.payloadSeed);
bins=zeros(layout.physicalSymbolCount,1);bins(layout.dataRows)=payload.physicalBins;
m=c.samplesPerSymbol;tx=complex(zeros(layout.physicalSymbolCount,m));
for row=1:layout.physicalSymbolCount,tx(row,:)=v4ModulateSymbol(bins(row),c);end
total=layout.physicalSymbolCount*m;time=caseStartTimeSec+(0:total-1).'/c.sampleRateHz;
orbit=v4TrackAOrbit(time,c);phase=[0;cumsum(pi/c.sampleRateHz*(orbit.dopplerHz(1:end-1)+orbit.dopplerHz(2:end)))];
clean=tx.*exp(1i*reshape(phase,m,layout.physicalSymbolCount).');
if isinf(snrDb),variance=0;noise=complex(zeros(size(clean)));else
 variance=10^(-snrDb/10);stream=RandStream('mt19937ar','Seed',seeds.noiseSeed);
 noise=sqrt(variance/2)*(randn(stream,size(clean))+1i*randn(stream,size(clean)));
end
rx=clean+noise;center=floor(m/2)+1;doppler=reshape(orbit.dopplerHz,m,layout.physicalSymbolCount).';
observation=struct('rxPhysical',rx,'layout',layout,'noiseVariance',variance, ...
 'sampleFingerprint',[sum(abs(rx(:)).^2) sum(real(rx(:))) sum(imag(rx(:)))]);
truth=struct('payloadPhysicalBins',payload.physicalBins,'dataBits',logical(payload.dataBits), ...
 'dataCfoBins',doppler(layout.dataRows,center)/c.fftBinSpacingHz, ...
 'startTimeSec',caseStartTimeSec,'channelModel','AWGN');
frame=struct('observation',observation,'truth',truth,'ledger',seeds, ...
 'caseStartTimeSec',caseStartTimeSec,'snrDb',snrDb);
end
