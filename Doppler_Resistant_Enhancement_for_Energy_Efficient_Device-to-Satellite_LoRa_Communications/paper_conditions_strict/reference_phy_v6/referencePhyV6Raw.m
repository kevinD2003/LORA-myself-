function [raw,observedIQ] = referencePhyV6Raw(symbols,layout,startTime,snrDb,seeds,c)
%REFERENCEPHYV6RAW Direct IQ, full-frame AWGN, physical SFD time, frozen MEX.
% Observation selection assumes perfect synchronization; no SFD detector is added.
[observations,replicates]=size(symbols);m=c.samplesPerSymbol;
if observations~=numel(layout.observationIndices) || numel(seeds)~=replicates || ...
        any(~isfinite(symbols(:)) | symbols(:)<0 | symbols(:)>=m | symbols(:)~=fix(symbols(:))) || ...
        ~isfinite(startTime) || isnan(snrDb) || snrDb==-Inf
    error('ReferencePhyV6:Raw','Invalid waveform inputs.');
end
starts=round(layout.observationIndices*m);sampleIndices=starts+(0:m-1);
times=startTime+sampleIndices/c.sampleRateHz;
orbit=drePaperOrbit(times,c);
switch c.phaseModel
    case 'paper-equation-15-product'
        phase=2*pi*orbit.dopplerHz.*times;
    case 'integrated-instantaneous-doppler'
        center=drePaperOrbit(0,c);
        phase=2*pi*c.carrierFrequencyHz/c.speedOfLightMps*(orbit.rangeM-center.rangeM);
    otherwise,error('ReferencePhyV6:Phase','Unknown phase definition.');
end
up=dreModulateSymbols(0,c);template=(exp(1i*phase).*up).';
frameSamples=round(layout.onAirSymbols*m);
noise=complex(zeros(observations,m,replicates));
if snrDb~=Inf
    scale=sqrt(10^(-snrDb/10)/2);
    for packet=1:replicates
        stream=RandStream('mt19937ar','Seed',seeds(packet));
        re=randn(stream,frameSamples,1);im=randn(stream,frameSamples,1);
        noise(:,:,packet)=scale*complex(re(sampleIndices+1),im(sampleIndices+1));
    end
end
strictFolder=fileparts(fileparts(mfilename('fullpath')));
dll=fullfile(strictFolder,'vendor','pyfftw','libfftw3-3.dll');
if nargout>1
    [bins,~,iq]=strictPaperNativeCentroids(double(symbols),template,noise,c.nativeThreads,dll);
    observedIQ=iq.';
else
    bins=strictPaperNativeCentroids(double(symbols),template,noise,c.nativeThreads,dll);
end
raw=reshape(bins,observations,replicates);
end
