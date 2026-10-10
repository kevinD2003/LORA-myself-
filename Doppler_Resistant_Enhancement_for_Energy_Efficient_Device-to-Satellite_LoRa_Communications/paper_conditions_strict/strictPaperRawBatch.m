function [raw,iq] = strictPaperRawBatch(symbols,startTimeSec,snrDb,seeds,c)
%STRICTPAPERRAWBATCH Direct sample noise and native IQ/FFT processing.
% This produces the same waveform/noise as strictPaperGenerateIQ, followed
% by the reference Hann/4x FFT/ten-point centroid. No error pool is used.
[symbolCount,replicates]=size(symbols);m=c.samplesPerSymbol;
if numel(seeds)~=replicates || isnan(snrDb) || snrDb==-Inf
    error('StrictPaper:RawShape','Invalid packet seeds or SNR.');
end
template=strictPaperGenerateIQ(zeros(symbolCount,1),startTimeSec,Inf,0,c).';
noise=complex(zeros(symbolCount,m,replicates));
if snrDb~=Inf
    scale=sqrt(10^(-snrDb/10)/2);
    for replicate=1:replicates
        stream=RandStream('mt19937ar','Seed',seeds(replicate));
        re=randn(stream,symbolCount,m);im=randn(stream,symbolCount,m);
        noise(:,:,replicate)=scale*complex(re,im);
    end
end
if nargout>1
    [bins,~,nativeIQ]=strictPaperNativeCentroids( ...
        double(symbols),template,noise,c.nativeThreads, ...
        fullfile(fileparts(mfilename('fullpath')),'vendor','pyfftw','libfftw3-3.dll'));
    iq=nativeIQ.';
else
    bins=strictPaperNativeCentroids( ...
        double(symbols),template,noise,c.nativeThreads, ...
        fullfile(fileparts(mfilename('fullpath')),'vendor','pyfftw','libfftw3-3.dll'));
end
raw=reshape(bins,symbolCount,replicates);
end
