function result=prefecNativeHardDetect(samples,c)
%PREFECNATIVEHARDDETECT User no-LDRO native FFT chirps, strictly before FEC.
assert(c.dataBinSpacing==1 && c.effectiveDataSf==c.physicalSf && ...
    c.dataAlphabetSize==c.samplesPerSymbol && size(samples,1)==112 && ...
    size(samples,2)==c.samplesPerSymbol);
up=v4ModulateSymbol(0,c);
[~,index]=max(abs(fft(samples.*conj(up),[],2)).^2,[],2);
result=struct('detectedPhysicalBins',index-1,'usesFecDecoding',false, ...
    'symbolSource','native-FFT-hard-chirp-before-FEC','dataFftPadding',1);
end
