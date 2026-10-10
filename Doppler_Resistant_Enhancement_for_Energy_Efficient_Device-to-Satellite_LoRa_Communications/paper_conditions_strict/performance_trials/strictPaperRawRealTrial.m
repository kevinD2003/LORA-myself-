function raw=strictPaperRawRealTrial(symbols,startTimeSec,snrDb,seeds,c)
[count,replicates]=size(symbols);m=c.samplesPerSymbol;
template=strictPaperGenerateIQ(zeros(count,1),startTimeSec,Inf,0,c).';
noise=zeros(count,m,2*replicates);
for replicate=1:replicates
    stream=RandStream('mt19937ar','Seed',seeds(replicate));
    noise(:,:,2*replicate-1)=randn(stream,count,m);
    noise(:,:,2*replicate)=randn(stream,count,m);
end
path=fullfile(fileparts(fileparts(mfilename('fullpath'))),'vendor','pyfftw','libfftw3-3.dll');
raw=strictPaperRealNoiseTrial(double(symbols),template,noise,c.nativeThreads,path, ...
    sqrt(10^(-snrDb/10)/2));
raw=reshape(raw,count,replicates);
end
