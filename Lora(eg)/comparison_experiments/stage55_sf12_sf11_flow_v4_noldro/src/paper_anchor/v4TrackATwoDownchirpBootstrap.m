function bootstrap=v4TrackATwoDownchirpBootstrap(packet,config,step)
% Receiver-only sub-bin CFO/rate from the two existing complete downchirps.
s=packet.schedule;rows=[9 10];cfo=zeros(2,1);phase=zeros(2,1);
for k=1:2,first=s.startSample(rows(k))+1;x=packet.rx(first:first+config.samplesPerSymbol-1).';[cfo(k),phase(k)]=localDownEstimate(x,config,step);end
time=s.centerTimeOffsetSec(rows);rate=(cfo(2)-cfo(1))/(time(2)-time(1));
bootstrap=struct('cfoBins',cfo,'phaseRad',phase,'measurementTimeSec',time, ...
    'rateBinsPerSec',rate,'cfoAtQuarterStartBins',cfo(2)+rate*(10*config.symbolDurationSec-time(2)), ...
    'availableAtSec',10*config.symbolDurationSec,'stepBins',step,'usesTruth',false);
end
function [offset,phase]=localDownEstimate(x,c,step)
m=c.samplesPerSymbol;n=0:m-1;tone=x.*v4ModulateSymbol(0,c);z=fft(tone);[~,q]=max(abs(z).^2);q=q-1;if q>=m/2,q=q-m;end;candidates=(q-1:step:q+1).';bank=exp(-1i*2*pi*candidates*n/m);coherent=bank*tone.'/m;[~,best]=max(abs(coherent));offset=candidates(best);phase=angle(coherent(best));
end
