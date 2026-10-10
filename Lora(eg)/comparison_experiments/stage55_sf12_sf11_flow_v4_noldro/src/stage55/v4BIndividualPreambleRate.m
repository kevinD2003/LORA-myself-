function estimate=v4BIndividualPreambleRate(rxPilots,c,step)
m=c.samplesPerSymbol;n=0:m-1;down=conj(v4ModulateSymbol(0,c));time=((0:7).'+0.5)*c.symbolDurationSec;cfo=zeros(8,1);ratio=zeros(8,1);
for k=1:8,z=fft(rxPilots(k,:).*down);[~,q]=max(abs(z).^2);q=q-1;if q>=m/2,q=q-m;end;e=v4PhaseRotationEstimate(rxPilots(k,:),0,c,(q-1:step:q+1).');cfo(k)=e.offsetBins;ratio(k)=e.peakRatio;end
slopes=zeros(28,1);row=0;for i=1:7,for j=i+1:8,row=row+1;slopes(row)=(cfo(j)-cfo(i))/(time(j)-time(i));end,end;valid=slopes(isfinite(slopes)&abs(slopes)<=100);if isempty(valid),rate=NaN;else,rate=median(valid);end;estimate=struct('cfoBins',cfo,'peakRatio',ratio,'rateBinsPerSec',rate,'usesTruth',false,'fit','median-pairwise-known-preamble');
end
