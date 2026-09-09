function b=v4TrackAEightUpRobustBootstrap(packet,c,step)
s=packet.schedule;m=c.samplesPerSymbol;n=0:m-1;down=conj(v4ModulateSymbol(0,c));time=s.centerTimeOffsetSec(1:8);cfo=zeros(8,1);ratio=zeros(8,1);
for k=1:8,first=s.startSample(k)+1;x=packet.rx(first:first+m-1).';z=fft(x.*down);[~,q]=max(abs(z).^2);q=q-1;if q>=m/2,q=q-m;end;e=v4PhaseRotationEstimate(x,0,c,(q-1:step:q+1).');cfo(k)=e.offsetBins;ratio(k)=e.peakRatio;end
slopes=zeros(28,1);row=0;for i=1:7,for j=i+1:8,row=row+1;slopes(row)=(cfo(j)-cfo(i))/(time(j)-time(i));end,end;finite=slopes(isfinite(slopes)&abs(slopes)<=100);if isempty(finite),rate=NaN;else,rate=median(finite);end;target=10*c.symbolDurationSec;cfoTarget=median(cfo-rate*(time-target));b=struct('cfoBins',cfo,'peakRatio',ratio,'measurementTimeSec',time,'rateBinsPerSec',rate,'cfoAtQuarterStartBins',cfoTarget,'availableAtSec',8*c.symbolDurationSec,'stepBins',step,'usesTruth',false,'fitMethod','median-pairwise-slope');
end
