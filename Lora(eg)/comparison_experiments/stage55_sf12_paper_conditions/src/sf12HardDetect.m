function detection = sf12HardDetect(rxSymbol,estimateHz,cfg)
%SF12HARDDETECT Compensate CFO and quantize to a legal LDRO symbol.

n = cfg.radio.samplesPerSymbol;
t = (0:n-1)/cfg.radio.sampleRateHz;
compensated = rxSymbol(:).'.*exp(-1j*2*pi*estimateHz*t);
power = abs(fft(compensated)).^2;
[sorted,indices] = sort(power,'descend');
rawBin = indices(1)-1;
signedBin = rawBin;
if signedBin >= n/2
    signedBin = signedBin-n;
end
quantized = cfg.radio.dataBinSpacing*round( ...
    signedBin/cfg.radio.dataBinSpacing);
waveformBin = mod(quantized,n);
detection.symbol = mod(round(waveformBin/cfg.radio.dataBinSpacing), ...
    cfg.radio.dataAlphabetSize);
detection.waveformBin = waveformBin;
detection.rawSignedBin = signedBin;
detection.peakRatio = sorted(1)/max(sorted(2),eps);
detection.compensated = compensated;
end
